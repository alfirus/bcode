// bcode store — session/message/permission state + secure server config.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'serve_client.dart';

const _kUrl = 'bcode.server_url';
const _kUser = 'bcode.server_user';
const _kPass = 'bcode.server_pass';

class BcodeStore extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  ServeClient? api;

  String? activeSessionId;
  List<SessionInfo> sessions = [];
  List<ChatMessage> messages = [];
  List<PermissionReq> permissions = [];
  String liveTail = '';

  bool busy = false;
  bool sending = false;
  String status = 'offline';
  String? error;

  StreamSubscription<String>? _sub;
  Completer<void>? _turnDone;
  Timer? _permTimer;

  Future<void> load() async {
    final url = (await _storage.read(key: _kUrl)) ?? '';
    final user = (await _storage.read(key: _kUser)) ?? 'opencode';
    final pass = (await _storage.read(key: _kPass)) ?? '';
    if (url.isNotEmpty) {
      api = ServeClient(url, username: user, password: pass);
      await refreshAll();
    }
    _startPermPoll();
  }

  Future<void> saveServer(String url, String user, String pass) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _storage.write(key: _kUrl, value: clean);
    await _storage.write(key: _kUser, value: user.trim());
    await _storage.write(key: _kPass, value: pass);
    api = ServeClient(clean,
        username: user.trim().isEmpty ? 'opencode' : user.trim(),
        password: pass);
    await refreshAll();
    _startPermPoll();
  }

  Future<String> serverUrl() async => (await _storage.read(key: _kUrl)) ?? '';
  Future<String> serverUser() async =>
      (await _storage.read(key: _kUser)) ?? 'opencode';
  Future<String> serverPass() async =>
      (await _storage.read(key: _kPass)) ?? '';

  /// Global permission queue poll — the Approve/Deny UI is dead without
  /// this. Cheap (2s), silent on failure, only notifies on change.
  void _startPermPoll() {
    _permTimer?.cancel();
    _permTimer = Timer.periodic(
        const Duration(seconds: 2), (_) => _pollPermissions());
  }

  Future<void> _pollPermissions() async {
    final c = api;
    if (c == null) return;
    try {
      final fresh = await c.listPermissions();
      final sig = fresh.map((p) => p.id).join('|');
      if (sig != permissions.map((p) => p.id).join('|')) {
        permissions = fresh;
        notifyListeners();
      }
    } catch (_) {
      // stay quiet — transient network blips shouldn't flash errors
    }
  }

  @override
  void dispose() {
    _permTimer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> refreshAll() async {
    final c = api;
    if (c == null) {
      status = 'offline';
      notifyListeners();
      return;
    }
    busy = true;
    error = null;
    notifyListeners();
    try {
      sessions = await c.listSessions();
      status = 'online';
      if (activeSessionId == null && sessions.isNotEmpty) {
        await openSession(sessions.first.id);
      } else if (activeSessionId != null) {
        await refreshMessages();
      }
      await _pollPermissions();
    } catch (e) {
      status = 'error';
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> openSession(String id) async {
    final c = api;
    if (c == null) return;
    activeSessionId = id;
    liveTail = '';
    busy = true;
    error = null;
    notifyListeners();
    try {
      messages = await c.listMessages(id);
      await _pollPermissions();
    } catch (e) {
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> newSession() async {
    final c = api;
    if (c == null) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      final s = await c.createSession();
      sessions = [s, ...sessions];
      await openSession(s.id);
    } catch (e) {
      error = '$e';
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    final c = api;
    if (c == null) return;
    try {
      await c.deleteSession(id);
      sessions = sessions.where((s) => s.id != id).toList();
      if (activeSessionId == id) {
        activeSessionId = sessions.isEmpty ? null : sessions.first.id;
        messages = [];
        liveTail = '';
        if (activeSessionId != null) {
          messages = await c.listMessages(activeSessionId!);
        }
      }
      notifyListeners();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> refreshMessages() async {
    final c = api;
    final id = activeSessionId;
    if (c == null || id == null) return;
    try {
      messages = await c.listMessages(id);
      notifyListeners();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  /// PROTOCOL rule 5: prompt_async + SSE is the primary mobile path.
  /// Blocking sendMessage is the fallback; idle events end the turn.
  Future<void> send(String text) async {
    final c = api;
    final id = activeSessionId;
    final clean = text.trim();
    if (c == null || id == null || clean.isEmpty) return;
    // PROTOCOL rule 2: one running turn per session — abort, then resend.
    if (sending) {
      await abort();
    }
    sending = true;
    error = null;
    liveTail = '';
    notifyListeners();
    final done = Completer<void>();
    _turnDone = done;
    void finish() {
      if (!done.isCompleted) done.complete();
    }

    await _sub?.cancel();
    _sub = c
        .streamSessionText(id, onIdle: finish)
        .listen((chunk) {
          liveTail += chunk;
          notifyListeners();
        }, onDone: finish, onError: (_) => finish());
    try {
      try {
        await c.promptAsync(id, clean);
      } catch (_) {
        await c.sendMessage(id, clean);
        finish();
      }
      // Wait for the turn to end (idle event, stream close, or abort).
      // Generous ceiling — refresh happens either way.
      try {
        await done.future.timeout(const Duration(minutes: 10));
      } on TimeoutException {
        // fall through to refresh
      }
    } catch (e) {
      error = '$e';
    } finally {
      sending = false;
      _turnDone = null;
      await refreshMessages();
      await _pollPermissions();
      notifyListeners();
    }
  }

  Future<void> abort() async {
    final c = api;
    final id = activeSessionId;
    if (c == null || id == null) return;
    try {
      await c.abort(id);
    } catch (e) {
      error = '$e';
    } finally {
      sending = false;
      if (_turnDone != null && !_turnDone!.isCompleted) {
        _turnDone!.complete();
      }
      await _sub?.cancel();
      await refreshMessages();
      notifyListeners();
    }
  }

  /// The reply endpoint is global — no open session required.
  Future<void> decidePermission(PermissionReq p, bool allow) async {
    final c = api;
    if (c == null) return;
    try {
      await c.decidePermission(p.id, allow ? 'once' : 'reject');
      permissions = permissions.where((x) => x.id != p.id).toList();
      notifyListeners();
      await _pollPermissions();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }
}
