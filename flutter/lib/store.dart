// bcode store — session/message/permission state + secure server config.
// Secrets live in flutter_secure_storage (Keychain / Keystore), never in prefs.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'serve_client.dart';

const _kUrl = 'bcode.serverUrl';
const _kUser = 'bcode.username';
const _kPass = 'bcode.password';

class BcodeStore extends ChangeNotifier {
  ServeClient? api;
  String serverUrl = '';
  String username = '';
  String status = 'offline'; // online | connecting | offline
  String? error;

  List<SessionInfo> sessions = [];
  String? activeSessionId;
  List<ChatMessage> messages = [];
  List<PermissionReq> permissions = [];
  bool sending = false;
  String liveTail = '';

  StreamSubscription<String>? _tailSub;

  static const _storage = FlutterSecureStorage();

  Future<void> load() async {
    serverUrl = await _storage.read(key: _kUrl) ?? '';
    username = await _storage.read(key: _kUser) ?? '';
    final pass = await _storage.read(key: _kPass) ?? '';
    if (serverUrl.isNotEmpty && pass.isNotEmpty) {
      api = ServeClient(serverUrl, username: username, password: pass);
      await refreshSessions();
    }
    notifyListeners();
  }

  Future<String> password() async =>
      (await _storage.read(key: _kPass)) ?? '';

  Future<void> saveServer(String url, String user, String pass) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await _storage.write(key: _kUrl, value: clean);
    await _storage.write(key: _kUser, value: user.trim());
    await _storage.write(key: _kPass, value: pass);
    serverUrl = clean;
    username = user.trim();
    api = ServeClient(clean, username: username, password: pass);
    notifyListeners();
    await refreshSessions();
  }

  Future<void> refreshSessions() async {
    final c = api;
    if (c == null) return;
    status = 'connecting';
    error = null;
    notifyListeners();
    try {
      sessions = await c.listSessions();
      status = 'online';
      if (activeSessionId != null &&
          !sessions.any((s) => s.id == activeSessionId)) {
        activeSessionId = null;
        messages = [];
      }
    } catch (e) {
      status = 'offline';
      error = '$e';
    }
    notifyListeners();
  }

  Future<void> openSession(String id) async {
    activeSessionId = id;
    messages = [];
    liveTail = '';
    permissions = [];
    notifyListeners();
    await refreshMessages();
  }

  Future<void> refreshMessages() async {
    final c = api;
    final id = activeSessionId;
    if (c == null || id == null) return;
    try {
      messages = await c.listMessages(id);
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  Future<void> newSession() async {
    final c = api;
    if (c == null) return;
    try {
      final s = await c.createSession();
      await refreshSessions();
      if (s.id.isNotEmpty) await openSession(s.id);
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> deleteSession(String id) async {
    final c = api;
    if (c == null) return;
    try {
      await c.deleteSession(id);
      await refreshSessions();
    } catch (e) {
      error = '$e';
      notifyListeners();
    }
  }

  Future<void> send(String text) async {
    final c = api;
    final id = activeSessionId;
    final clean = text.trim();
    if (c == null || id == null || clean.isEmpty || sending) return;
    sending = true;
    liveTail = '';
    error = null;
    messages = [
      ...messages,
      ChatMessage(id: 'local-${DateTime.now().millisecondsSinceEpoch}', role: 'user', text: clean),
    ];
    notifyListeners();
    await _tailSub?.cancel();
    _tailSub = c.streamSessionText(id).listen((chunk) {
      liveTail += chunk;
      notifyListeners();
    });
    try {
      try {
        await c.sendMessage(id, clean);
      } catch (_) {
        await c.promptAsync(id, clean);
      }
    } catch (e) {
      error = '$e';
    } finally {
      sending = false;
      await refreshMessages();
      liveTail = '';
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
    }
    sending = false;
    notifyListeners();
  }

  Future<void> decidePermission(PermissionReq p, bool allow) async {
    final c = api;
    final id = activeSessionId;
    if (c == null || id == null) return;
    try {
      await c.decidePermission(p.id, allow ? 'once' : 'reject');
      permissions = permissions.where((x) => x.id != p.id).toList();
    } catch (e) {
      error = '$e';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tailSub?.cancel();
    super.dispose();
  }
}
