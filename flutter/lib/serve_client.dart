// bcode serve client — shapes pinned to docs/PROTOCOL.md, verified against
// live `opencode serve` v1.18.29. http + SSE only, no sockets.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

String _str(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return '';
}

List<dynamic> _list(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    final v = m[k];
    if (v is List) return v;
  }
  return const [];
}

dynamic _asMap(dynamic v) => v is Map<String, dynamic> ? v : null;

class ServeClient {
  ServeClient(this.baseUrl, {this.username = '', this.password = ''});

  final String baseUrl;
  final String username;
  final String password;

  /// Hung serve must never freeze the UI — every unary call gets a timeout.
  /// (The SSE stream is long-lived by design and is exempt.)
  static const _kTimeout = Duration(seconds: 15);

  Map<String, String> get _headers {
    final h = {'Content-Type': 'application/json'};
    if (password.isNotEmpty) {
      h['Authorization'] =
          'Basic ${base64Encode(utf8.encode('$username:$password'))}';
    }
    return h;
  }

  Uri _u(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path');

  Future<dynamic> _get(String path) async {
    final r =
        await http.get(_u(path), headers: _headers).timeout(_kTimeout);
    if (r.statusCode >= 400) throw StateError('GET $path → ${r.statusCode}');
    return jsonDecode(r.body);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final r = await http
        .post(_u(path), headers: _headers, body: jsonEncode(body ?? {}))
        .timeout(_kTimeout);
    if (r.statusCode >= 400) throw StateError('POST $path → ${r.statusCode}');
    if (r.body.isEmpty) return null;
    return jsonDecode(r.body);
  }

  Future<List<SessionInfo>> listSessions() async {
    final raw = await _get('/session');
    final items = raw is List ? raw : _list(_asMap(raw) ?? {}, ['sessions', 'items', 'data']);
    return items
        .whereType<Map<String, dynamic>>()
        .map(SessionInfo.fromJson)
        .toList();
  }

  Future<SessionInfo> createSession() async =>
      SessionInfo.fromJson(_asMap(await _post('/session')) ?? {});

  Future<void> deleteSession(String id) async {
    final c = http.Client();
    try {
      final req = http.Request('DELETE', _u('/session/$id'));
      req.headers.addAll(_headers);
      final r = await c.send(req).timeout(_kTimeout);
      await r.stream.drain();
      if (r.statusCode >= 400) throw StateError('DELETE → ${r.statusCode}');
    } finally {
      c.close();
    }
  }

  Future<List<ChatMessage>> listMessages(String sessionId) async {
    final raw = await _get('/session/$sessionId/message?limit=100');
    final items =
        raw is List ? raw : _list(_asMap(raw) ?? {}, ['messages', 'items', 'data']);
    return items
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  /// Parts model — verified against live serve, see docs/PROTOCOL.md.
  Map<String, dynamic> _textBody(String text) => {
        'parts': [
          {'type': 'text', 'text': text}
        ]
      };

  Future<void> sendMessage(String sessionId, String text) =>
      _post('/session/$sessionId/message', _textBody(text));

  /// Primary send path on mobile (PROTOCOL rule 5): returns immediately,
  /// the turn streams back over SSE instead of holding one HTTP call open.
  Future<void> promptAsync(String sessionId, String text) =>
      _post('/session/$sessionId/prompt_async', _textBody(text));

  Future<void> abort(String sessionId) => _post('/session/$sessionId/abort');

  /// Global permission queue — poll this; `[]` when empty.
  Future<List<PermissionReq>> listPermissions() async {
    final raw = await _get('/permission');
    final items =
        raw is List ? raw : _list(_asMap(raw) ?? {}, ['permissions', 'items', 'data']);
    return items
        .whereType<Map<String, dynamic>>()
        .map(PermissionReq.fromJson)
        .toList();
  }

  /// Global permission reply — `once` | `always` | `reject`.
  Future<void> decidePermission(String requestId, String reply) =>
      _post('/permission/$requestId/reply', {'reply': reply});

  /// Live text tail for a session. Emits appended text chunks.
  /// Calls [onIdle] when the server signals the turn ended (session.idle)
  /// so the store can flip `sending` off and refresh — the stream itself
  /// stays open until cancelled.
  Stream<String> streamSessionText(String sessionId, {void Function()? onIdle}) {
    final ctl = StreamController<String>();
    final client = http.Client();
    () async {
      try {
        final req = http.Request('GET', _u('/event'));
        req.headers.addAll(_headers);
        final resp = await client.send(req);
        String? event;
        final data = <String>[];
        await for (final line
            in resp.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (ctl.isClosed) break;
          if (line.startsWith(':')) continue;
          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
            continue;
          }
          if (line.startsWith('data:')) {
            data.add(line.substring(5).trim());
            continue;
          }
          if (line.trim().isEmpty) {
            final payload = data.join('\n');
            data.clear();
            if (payload.isEmpty) {
              event = null;
              continue;
            }
            dynamic json;
            try {
              json = jsonDecode(payload);
            } catch (_) {
              event = null;
              continue;
            }
            final m = _asMap(json);
            if (m == null) {
              event = null;
              continue;
            }
            final sid = _str(m, ['sessionId', 'sessionID', 'session_id']);
            if (sid.isNotEmpty && sid != sessionId) {
              event = null;
              continue;
            }
            final kind = '${event ?? ''} ${_str(m, ['type', 'event', 'kind'])}';
            if (kind.contains('idle') || kind.contains('done')) {
              try {
                onIdle?.call();
              } catch (_) {}
              event = null;
              continue;
            }
            if (kind.contains('message') || kind.contains('text') || kind.contains('part')) {
              final chunk = _str(m, ['text', 'delta', 'content', 'chunk']);
              if (chunk.isNotEmpty) ctl.add(chunk);
            } else if (event == null) {
              final chunk = _str(m, ['text', 'delta', 'content']);
              if (chunk.isNotEmpty) ctl.add(chunk);
            }
            event = null;
          }
        }
      } catch (_) {
        // stream ends quietly; UI falls back to refresh
      } finally {
        client.close();
        if (!ctl.isClosed) await ctl.close();
      }
    }();
    return ctl.stream;
  }
}

class SessionInfo {
  SessionInfo({required this.id, required this.title, required this.updatedAt});
  final String id;
  final String title;
  final String updatedAt;

  factory SessionInfo.fromJson(Map<String, dynamic> m) {
    final id = _str(m, ['id', 'ID', 'sessionId']);
    final title = _str(m, ['title', 'name', 'label']);
    return SessionInfo(
      id: id,
      title: title.isEmpty ? (id.length > 8 ? id.substring(0, 8) : id) : title,
      updatedAt: _str(m, ['updatedAt', 'updated_at', 'time', 'created']),
    );
  }
}

class ChatMessage {
  ChatMessage({required this.id, required this.role, required this.text});
  final String id;
  final String role; // user | assistant | system | permission
  final String text;

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> m) {
    final role = _str(m, ['role', 'sender', 'author']).toLowerCase();
    final norm = role.contains('user')
        ? 'user'
        : role.contains('perm')
            ? 'permission'
            : 'assistant';
    // Parts are authoritative when present — serve echoes the same text at
    // top level on some versions, so never concatenate both (double render).
    final parts = _list(m, ['parts', 'content']);
    final buf = StringBuffer();
    for (final p in parts) {
      final pm = _asMap(p);
      if (pm == null) continue;
      final t = _str(pm, ['text', 'content', 'data']);
      if (t.isNotEmpty) {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(t);
      }
    }
    var text = buf.toString();
    if (text.isEmpty) {
      final info = _asMap(m['info']);
      text = _str(m, ['text', 'content', 'body', 'message']) +
          (info != null ? _str(info, ['text', 'content']) : '');
    }
    return ChatMessage(
      id: _str(m, ['id', 'ID', 'messageId']),
      role: norm,
      text: text,
    );
  }
}

class PermissionReq {
  PermissionReq({required this.id, required this.title, required this.detail});
  final String id;
  final String title;
  final String detail;

  /// Serve item: `{id, sessionID, permission, patterns, metadata,
  /// tool:{messageID, callID}}` — see docs/PROTOCOL.md.
  factory PermissionReq.fromJson(Map<String, dynamic> m) {
    final id = _str(m, ['id', 'requestID', 'requestId']);
    final perm = _str(m, ['permission', 'action', 'title']);
    final pats =
        _list(m, ['patterns']).whereType<String>().where((s) => s.isNotEmpty).toList();
    final title = pats.isEmpty
        ? (perm.isEmpty ? 'Permission request' : perm)
        : '${perm.isEmpty ? 'allow' : perm}: ${pats.join(', ')}';
    final tool = _asMap(m['tool']);
    final detail = [
      _str(m, ['sessionID', 'sessionId', 'session_id']),
      tool != null ? _str(tool, ['messageID', 'messageId', 'callID', 'callId']) : '',
      _str(m, ['metadata']).isEmpty ? '' : _str(m, ['metadata']),
    ].where((s) => s.isNotEmpty).join(' · ');
    return PermissionReq(id: id, title: title, detail: detail);
  }
}
