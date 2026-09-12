// bcode serve client — mirrors android/src/api.ts. http + SSE only.
// Shapes pinned against live /doc, see docs/PROTOCOL.md. Defensive reads:
// several key spellings, null-safe, never throws on unknown JSON.
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
    final r = await http.get(_u(path), headers: _headers);
    if (r.statusCode >= 400) throw StateError('GET $path → ${r.statusCode}');
    return jsonDecode(r.body);
  }

  Future<dynamic> _post(String path, [Map<String, dynamic>? body]) async {
    final r = await http.post(_u(path),
        headers: _headers, body: jsonEncode(body ?? {}));
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
      final r = await c.send(req);
      await r.stream.drain();
      if (r.statusCode >= 400) throw StateError('DELETE → ${r.statusCode}');
    } finally {
      c.close();
    }
  }

  Future<List<ChatMessage>> listMessages(String sessionId) async {
    final raw = await _get('/session/$sessionId/message');
    final items =
        raw is List ? raw : _list(_asMap(raw) ?? {}, ['messages', 'items', 'data']);
    return items
        .whereType<Map<String, dynamic>>()
        .map(ChatMessage.fromJson)
        .toList();
  }

  Future<void> sendMessage(String sessionId, String text) =>
      _post('/session/$sessionId/message', {'text': text, 'content': text});

  Future<void> promptAsync(String sessionId, String text) =>
      _post('/session/$sessionId/prompt_async', {'text': text, 'content': text});

  Future<void> abort(String sessionId) => _post('/session/$sessionId/abort');

  Future<void> decidePermission(
          String sessionId, String permissionId, bool allow) =>
      _post('/session/$sessionId/permissions/$permissionId',
          {'allow': allow, 'approved': allow, 'decision': allow ? 'allow' : 'deny'});

  /// Live text tail for a session. Emits appended text chunks.
  Stream<String> streamSessionText(String sessionId) {
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
    final info = _asMap(m['info']);
    final text = _str(m, ['text', 'content', 'body', 'message']) +
        (info != null ? _str(info, ['text', 'content']) : '');
    final parts = _list(m, ['parts', 'content']);
    final buf = StringBuffer(text);
    for (final p in parts) {
      final pm = _asMap(p);
      if (pm == null) continue;
      final t = _str(pm, ['text', 'content', 'data']);
      if (t.isNotEmpty) {
        if (buf.isNotEmpty) buf.write('\n');
        buf.write(t);
      }
    }
    return ChatMessage(
      id: _str(m, ['id', 'ID', 'messageId']),
      role: norm,
      text: buf.toString(),
    );
  }
}

class PermissionReq {
  PermissionReq({required this.id, required this.title, required this.detail});
  final String id;
  final String title;
  final String detail;
}
