// bcode chat screen — our own UI, widgets only. No Material anywhere:
// no Scaffold, no AppBar, no TextField, no InkWell. Verbatim message text.
import 'package:flutter/widgets.dart';

import 'serve_client.dart';
import 'store.dart';
import 'theme.dart';

class BcodeScreen extends StatefulWidget {
  const BcodeScreen({super.key, required this.store});
  final BcodeStore store;

  @override
  State<BcodeScreen> createState() => _BcodeScreenState();
}

class _BcodeScreenState extends State<BcodeScreen> {
  int tab = 0; // 0 chat, 1 sessions, 2 settings
  final _composer = TextEditingController();
  final _composerFocus = FocusNode();
  final _scroll = ScrollController();

  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _fieldNodes = <String, FocusNode>{};
  bool _settingsLoaded = false;

  @override
  void dispose() {
    _composer.dispose();
    _composerFocus.dispose();
    _scroll.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    for (final n in _fieldNodes.values) {
      n.dispose();
    }
    super.dispose();
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _ensureSettings() async {
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    _url.text = widget.store.serverUrl;
    _user.text = widget.store.username;
    _pass.text = await widget.store.password();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (_, __) {
        final s = widget.store;
        if (tab == 2) _ensureSettings();
        return Column(
          children: [
            _header(s),
            _tabs(),
            Expanded(
              child: tab == 0
                  ? _chat(s)
                  : tab == 1
                      ? _sessions(s)
                      : _settings(s),
            ),
            if (tab == 0) _composerBar(s),
          ],
        );
      },
    );
  }

  Widget _header(BcodeStore s) {
    final dot = s.status == 'online'
        ? BcodeColors.ok
        : s.status == 'connecting'
            ? BcodeColors.warn
            : BcodeColors.muted;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: const BoxDecoration(
        color: BcodeColors.surface,
        border: Border(bottom: BorderSide(color: BcodeColors.hairline)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              gradient: const LinearGradient(
                colors: [BcodeColors.cyan, BcodeColors.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            alignment: Alignment.center,
            child: const Text('ϟ',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF04121A))),
          ),
          const SizedBox(width: 10),
          const Text('bcode', style: BcodeText.title),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: dot, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 6),
          Text(s.status, style: BcodeText.meta),
        ],
      ),
    );
  }

  Widget _tabs() {
    const labels = ['Chat', 'Sessions', 'Settings'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = tab == i;
          return GestureDetector(
            onTap: () => setState(() => tab = i),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: active ? BcodeColors.cyanDim : const Color(0x00000000),
                borderRadius: BorderRadius.circular(BcodeRadii.pill),
                border: Border.all(
                    color: active
                        ? BcodeColors.cyan
                        : BcodeColors.hairline),
              ),
              child: Text(labels[i],
                  style: BcodeText.tab.copyWith(
                      color:
                          active ? BcodeColors.cyan : BcodeColors.muted)),
            ),
          );
        }),
      ),
    );
  }

  Widget _chat(BcodeStore s) {
    if (s.activeSessionId == null) {
      return const Center(
          child: Text('No session open — grab one in Sessions.',
              style: BcodeText.meta));
    }
    final items = <Widget>[];
    for (final m in s.messages) {
      items.add(_bubble(m));
    }
    for (final p in s.permissions) {
      items.add(_permissionCard(s, p));
    }
    if (s.sending) {
      items.add(Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 60, 4),
        child: const Text('working…', style: BcodeText.meta),
      ));
    }
    if (s.liveTail.isNotEmpty) {
      items.add(_bubble(ChatMessage(
          id: 'live', role: 'assistant', text: s.liveTail)));
    }
    if (s.error != null) {
      items.add(Container(
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        child: Text(s.error!,
            style: BcodeText.meta.copyWith(color: BcodeColors.danger)),
      ));
    }
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      children: items,
    );
  }

  Widget _bubble(ChatMessage m) {
    final user = m.isUser;
    return Row(
      mainAxisAlignment:
          user ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        Flexible(
          child: Container(
            margin: EdgeInsets.fromLTRB(user ? 60 : 0, 4, user ? 0 : 60, 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: user ? BcodeColors.cyan : BcodeColors.card,
              borderRadius: BorderRadius.circular(BcodeRadii.card),
              border: user
                  ? null
                  : Border.all(color: BcodeColors.hairline),
              boxShadow: user
                  ? null
                  : const [
                      BoxShadow(
                          color: Color(0x1F38E1FF),
                          blurRadius: 18,
                          offset: Offset(0, 2))
                    ],
            ),
            child: Text(m.text,
                style: BcodeText.message.copyWith(
                    color: user
                        ? const Color(0xFF04121A)
                        : BcodeColors.text)),
          ),
        ),
      ],
    );
  }

  Widget _permissionCard(BcodeStore s, PermissionReq p) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 4, 40, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BcodeColors.card,
        borderRadius: BorderRadius.circular(BcodeRadii.card),
        border: Border.all(color: BcodeColors.warn),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Permission needed', style: BcodeText.meta),
          const SizedBox(height: 4),
          Text(p.title, style: BcodeText.title),
          if (p.detail.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(p.detail, style: BcodeText.message),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _permBtn(s, p, true),
              const SizedBox(width: 8),
              _permBtn(s, p, false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _permBtn(BcodeStore s, PermissionReq p, bool allow) {
    return GestureDetector(
      onTap: () => s.decidePermission(p, allow),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: allow ? BcodeColors.ok : const Color(0x00000000),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: allow ? BcodeColors.ok : BcodeColors.danger),
        ),
        child: Text(allow ? 'Approve' : 'Deny',
            style: BcodeText.tab.copyWith(
                color: allow
                    ? const Color(0xFF04121A)
                    : BcodeColors.danger)),
      ),
    );
  }

  Widget _composerBar(BcodeStore s) {
    if (s.activeSessionId == null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
        alignment: Alignment.center,
        child: const Text('Open a session in the Sessions tab to start chatting.',
            style: BcodeText.meta),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: BcodeColors.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: BcodeColors.surface,
                borderRadius: BorderRadius.circular(BcodeRadii.input),
                border: Border.all(color: BcodeColors.hairline),
              ),
              child: EditableText(
                controller: _composer,
                focusNode: _composerFocus,
                style: BcodeText.input,
                cursorColor: BcodeColors.cyan,
                backgroundCursorColor: BcodeColors.surface,
                maxLines: 4,
                minLines: 1,
                onSubmitted: (_) => _submit(s),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              if (s.sending) {
                s.abort();
              } else {
                _submit(s);
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: s.sending ? BcodeColors.danger : BcodeColors.cyan,
                borderRadius: BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Text(s.sending ? '■' : '↑',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF04121A))),
            ),
          ),
        ],
      ),
    );
  }

  void _submit(BcodeStore s) {
    final text = _composer.text;
    _composer.clear();
    _scrollBottom();
    s.send(text);
  }

  Widget _sessions(BcodeStore s) {
    return Column(
      children: [
        GestureDetector(
          onTap: s.newSession,
          child: Container(
            margin: const EdgeInsets.fromLTRB(14, 6, 14, 4),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: BcodeColors.cyanDim,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: BcodeColors.cyan),
            ),
            alignment: Alignment.center,
            child: const Text('＋ New session',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: BcodeColors.cyan)),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
            children: [
              for (final sess in s.sessions)
                GestureDetector(
                  onTap: () {
                    s.openSession(sess.id);
                    setState(() => tab = 0);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
                    decoration: BoxDecoration(
                      color: sess.id == s.activeSessionId
                          ? BcodeColors.cyanDim
                          : BcodeColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sess.id == s.activeSessionId
                              ? BcodeColors.cyan
                              : BcodeColors.hairline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(sess.title,
                                  style: BcodeText.message),
                              if (sess.updatedAt.isNotEmpty)
                                Text(sess.updatedAt,
                                    style: BcodeText.meta),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => s.deleteSession(sess.id),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Text('⌦',
                                style: TextStyle(
                                    fontSize: 16,
                                    color: BcodeColors.danger)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settings(BcodeStore s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      children: [
        _field('Server URL', _url, 'http://100.121.188.113:4096', false),
        _field('Username (if basic auth)', _user, 'opencode', false),
        _field('Password', _pass, '••••••••', true),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () =>
              s.saveServer(_url.text, _user.text, _pass.text),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: BcodeColors.cyan,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Text('Save & connect',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF04121A))),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
            'Stored in Keychain / Keystore via flutter_secure_storage. Never leaves the phone except as the API password.',
            style: BcodeText.meta),
      ],
    );
  }

  Widget _field(
      String label, TextEditingController c, String hint, bool secret) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: BcodeText.meta),
          const SizedBox(height: 5),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: BcodeColors.surface,
              borderRadius:
                  BorderRadius.circular(BcodeRadii.input),
              border: Border.all(color: BcodeColors.hairline),
            ),
            child: EditableText(
              controller: c,
              focusNode:
                  _fieldNodes.putIfAbsent(label, () => FocusNode()),
              style: BcodeText.input,
              cursorColor: BcodeColors.cyan,
              backgroundCursorColor: BcodeColors.surface,
              obscureText: secret,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
