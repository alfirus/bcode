// bcode chat UI — own minimalist futuristic interface, vanilla DOM.
// No markdown rendering in v0.1: message text is shown verbatim (textContent,
// never innerHTML) with preserved whitespace.

import type { ServeClient } from "./api";
import type { ChatMessage, PendingPermission, Session, Store, View } from "./store";

export interface UICtx {
  store: Store;
  getApi: () => ServeClient | null;
  toast: (msg: string) => void;
  openSettings: () => void;
}

function el(tag: string, cls: string, text?: string): HTMLElement {
  const e = document.createElement(tag);
  e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}

function timeOf(at: number): string {
  try {
    return new Date(at).toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  } catch {
    return "";
  }
}

export function mountChat(root: HTMLElement, ctx: UICtx): () => void {
  const { store } = ctx;
  root.classList.add("bc");
  root.textContent = "";

  const top = el("div", "bc-top");
  const dot = el("span", "bc-dot");
  const word = el("div", "bc-word");
  const wordInner = el("span", "", "bcode");
  word.appendChild(wordInner);
  const sub = el("div", "bc-sub", "remote opencode");
  top.append(dot, word, sub);

  const tabs = el("div", "bc-tabs");
  const tabBtns: Record<View, HTMLButtonElement> = {
    chat: document.createElement("button"),
    sessions: document.createElement("button"),
    settings: document.createElement("button"),
  };
  (Object.keys(tabBtns) as View[]).forEach((v) => {
    const b = tabBtns[v];
    b.className = "bc-tab";
    b.textContent = v[0].toUpperCase() + v.slice(1);
    b.onclick = () => {
      store.clearNotice();
      store.update({ view: v });
      if (v === "sessions") void refreshSessions();
    };
    tabs.appendChild(b);
  });

  const view = el("div", "bc-view");

  const bar = el("div", "bc-bar");
  const input = document.createElement("input");
  input.placeholder = "Ask opencode…";
  input.autocomplete = "off";
  const sendBtn = document.createElement("button");
  sendBtn.className = "bc-send";
  sendBtn.textContent = "↑";
  bar.append(input, sendBtn);

  root.append(top, tabs, view, bar);

  let stopStream: (() => void) | null = null;

  function api(): ServeClient | null {
    const a = ctx.getApi();
    if (!a) {
      store.notice("Server not configured — open Settings first.", "error");
      store.update({ view: "settings" });
    }
    return a;
  }

  async function refreshSessions(): Promise<void> {
    const a = api();
    if (!a) return;
    try {
      const sessions = await a.listSessions();
      const st = store.state;
      store.update({
        sessions,
        connected: true,
        activeSessionId: st.activeSessionId ?? sessions[0]?.id ?? null,
      });
    } catch (e) {
      store.update({ connected: false });
      store.notice(`Cannot reach server: ${e instanceof Error ? e.message : e}`, "error");
    }
  }

  async function openSession(id: string): Promise<void> {
    store.update({ activeSessionId: id, view: "chat", messages: [] });
    const a = api();
    if (!a) return;
    try {
      store.setMessages(await a.getMessages(id));
    } catch (e) {
      store.notice(`Cannot load messages: ${e instanceof Error ? e.message : e}`, "error");
    }
  }

  async function newSession(): Promise<void> {
    const a = api();
    if (!a) return;
    try {
      const s = await a.createSession();
      store.update({ sessions: [s, ...store.state.sessions], activeSessionId: s.id, messages: [], view: "chat" });
    } catch (e) {
      store.notice(`Cannot create session: ${e instanceof Error ? e.message : e}`, "error");
    }
  }

  async function sendMsg(): Promise<void> {
    const st = store.state;
    const text = input.value.trim();
    if (!text || st.sending) return;
    const a = api();
    if (!a) return;
    let sid = st.activeSessionId;
    if (!sid) {
      try {
        const s = await a.createSession();
        store.update({ sessions: [s, ...store.state.sessions], activeSessionId: s.id });
        sid = s.id;
      } catch (e) {
        store.notice(`Cannot create session: ${e instanceof Error ? e.message : e}`, "error");
        return;
      }
    }
    const sessionId: string = sid;
    input.value = "";
    store.update({ sending: true });
    store.setMessages([
      ...store.state.messages,
      { id: `local-${Date.now()}`, role: "user", text, at: Date.now() },
    ]);

    stopStream = a.openEvents(sessionId, (e) => {
      if (e.permission) {
        store.addPermission(e.permission);
        ctx.toast(`bcode: approval needed — ${e.permission.tool}`);
      } else if (e.text) {
        store.upsertLiveMessage(`live-${sessionId}`, e.text);
      }
    });

    try {
      await a.sendAsync(sessionId, text);
      store.setMessages(await a.getMessages(sessionId));
      await refreshSessionsQuiet(a);
    } catch (e) {
      store.notice(`Send failed: ${e instanceof Error ? e.message : e}`, "error");
    } finally {
      stopStream?.();
      stopStream = null;
      store.update({ sending: false });
    }
  }

  async function refreshSessionsQuiet(a: ServeClient): Promise<void> {
    try {
      store.update({ sessions: await a.listSessions(), connected: true });
    } catch {
      store.update({ connected: false });
    }
  }

  async function abort(): Promise<void> {
    const a = ctx.getApi();
    const sid = store.state.activeSessionId;
    if (!a || !sid) return;
    try {
      await a.abort(sid);
      store.notice("Turn aborted.", "info");
    } catch (e) {
      store.notice(`Abort failed: ${e instanceof Error ? e.message : e}`, "error");
    } finally {
      stopStream?.();
      stopStream = null;
      store.update({ sending: false });
    }
  }

  async function decide(p: PendingPermission, allow: boolean): Promise<void> {
    const a = api();
    if (!a) return;
    try {
      await a.decidePermission(p.sessionId, p.id, allow);
      store.removePermission(p.id);
    } catch (e) {
      store.notice(`Approval failed: ${e instanceof Error ? e.message : e}`, "error");
    }
  }

  sendBtn.onclick = () => {
    if (store.state.sending) void abort();
    else void sendMsg();
  };
  input.onkeydown = (e) => {
    if (e.key === "Enter") void sendMsg();
  };

  function renderMessage(m: ChatMessage): HTMLElement {
    const wrap = el("div", `bc-msg ${m.role}`);
    wrap.appendChild(el("div", "bc-who", m.role === "user" ? "you" : m.role === "system" ? "system" : "opencode"));
    const bubble = el("div", "bc-bubble", m.text || "…");
    if (m.live && store.state.sending) bubble.classList.add("bc-caret");
    wrap.appendChild(bubble);
    wrap.appendChild(el("div", "bc-at", timeOf(m.at)));
    return wrap;
  }

  function renderPermission(p: PendingPermission): HTMLElement {
    const card = el("div", "bc-perm");
    card.appendChild(el("div", "bc-ptool", `◆ ${p.tool}`));
    if (p.detail) card.appendChild(el("div", "bc-pdetail", p.detail));
    const row = el("div", "bc-prow");
    const deny = document.createElement("button");
    deny.className = "bc-btn danger small";
    deny.textContent = "Deny";
    deny.onclick = () => void decide(p, false);
    const allow = document.createElement("button");
    allow.className = "bc-btn primary small";
    allow.textContent = "Approve";
    allow.onclick = () => void decide(p, true);
    row.append(deny, allow);
    card.appendChild(row);
    return card;
  }

  function renderChat(): void {
    const st = store.state;
    view.textContent = "";
    for (const p of st.permissions) view.appendChild(renderPermission(p));
    if (!st.activeSessionId) {
      const empty = el("div", "bc-empty");
      const mark = el("div", "bc-mark");
      empty.appendChild(mark);
      empty.appendChild(el("h2", "", "No session yet"));
      empty.appendChild(el("p", "", "Send a message below and bcode opens a remote session for you."));
      view.appendChild(empty);
    } else if (!st.messages.length && !st.sending) {
      const empty = el("div", "bc-empty");
      const mark = el("div", "bc-mark");
      empty.appendChild(mark);
      empty.appendChild(el("h2", "", "Say hello"));
      empty.appendChild(el("p", "", "This session is empty. Ask anything to start."));
      view.appendChild(empty);
    } else {
      for (const m of st.messages) view.appendChild(renderMessage(m));
      if (st.sending && !st.messages.some((m) => m.live)) {
        const thinking = el("div", "bc-msg assistant");
        thinking.appendChild(el("div", "bc-who", "opencode"));
        const b = el("div", "bc-bubble bc-caret", "working");
        thinking.appendChild(b);
        view.appendChild(thinking);
      }
      view.scrollTop = view.scrollHeight;
    }
    bar.style.display = "";
    input.disabled = st.sending;
    sendBtn.textContent = st.sending ? "■" : "↑";
    sendBtn.classList.toggle("stop", st.sending);
  }

  function renderSessions(): void {
    const st = store.state;
    view.textContent = "";
    const add = document.createElement("button");
    add.className = "bc-btn primary";
    add.textContent = "+ New session";
    add.onclick = () => void newSession();
    view.appendChild(add);
    if (!st.sessions.length) {
      const empty = el("div", "bc-empty");
      empty.appendChild(el("p", "", "No sessions yet. Create one to start chatting remotely."));
      view.appendChild(empty);
    }
    for (const s of st.sessions) {
      const row = document.createElement("button");
      row.className = "bc-sess" + (s.id === st.activeSessionId ? " live" : "");
      const col = el("div", "");
      col.appendChild(el("div", "bc-st", s.title));
      col.appendChild(el("div", "bc-sid", s.id.slice(0, 12)));
      row.appendChild(col);
      row.appendChild(el("div", "bc-go", "→"));
      row.onclick = () => void openSession(s.id);
      view.appendChild(row);
    }
    bar.style.display = "none";
  }

  function renderSettings(): void {
    const st = store.state;
    view.textContent = "";
    const urlF = settingsField("Server URL", st.serverUrl, "http://<tailscale-ip>:4096", false);
    const userF = settingsField("Username", st.username, "opencode", false);
    const passF = settingsField("Password", "", "OPENCODE_SERVER_PASSWORD", true);
    view.append(urlF.wrap, userF.wrap, passF.wrap);

    const status = el("div", "bc-note", statusText());
    if (st.connected === true) status.classList.add("ok");
    if (st.connected === false) status.classList.add("err");
    view.appendChild(status);

    const save = document.createElement("button");
    save.className = "bc-btn primary";
    save.textContent = "Save & connect";
    save.onclick = () =>
      void (async () => {
        await store.saveServer(urlF.input.value.trim(), userF.input.value.trim(), passF.input.value);
        const a = ctx.getApi();
        if (!a) return;
        store.update({ connected: await a.health() });
        if (store.state.connected) {
          ctx.toast("bcode: connected");
          await refreshSessions();
          store.update({ view: "chat" });
        } else {
          store.notice("Saved, but the server did not answer. Check URL and password.", "error");
        }
      })();
    view.appendChild(save);

    const note = el(
      "div",
      "bc-note",
      "Credentials live in Acode's plugin-scoped secret storage. The engine stays on your machine — this phone is only a remote.",
    );
    view.appendChild(note);

    if (st.notice) {
      const n = el("div", `bc-note ${st.noticeKind === "error" ? "err" : "ok"}`, st.notice);
      view.appendChild(n);
    }
    bar.style.display = "none";
  }

  function settingsField(
    label: string,
    value: string,
    placeholder: string,
    secret: boolean,
  ): { wrap: HTMLElement; input: HTMLInputElement } {
    const wrap = el("div", "bc-field");
    const lab = document.createElement("label");
    lab.textContent = label;
    const inputEl = document.createElement("input");
    inputEl.value = value;
    inputEl.placeholder = placeholder;
    inputEl.setAttribute("autocapitalize", "off");
    inputEl.setAttribute("autocorrect", "off");
    if (secret) inputEl.type = "password";
    wrap.append(lab, inputEl);
    return { wrap, input: inputEl };
  }

  function statusText(): string {
    const st = store.state;
    if (st.connected === true) return `● connected — ${st.sessions.length} session(s)`;
    if (st.connected === false) return "○ server unreachable";
    return st.hasPassword ? "○ saved — tap Save & connect to verify" : "○ not configured yet";
  }

  function render(): void {
    const st = store.state;
    dot.className = "bc-dot" + (st.connected === true ? " on" : st.connected === false ? " off" : "");
    const active: Session | undefined = st.sessions.find((s) => s.id === st.activeSessionId);
    sub.textContent = active?.title ?? "remote opencode";
    (Object.keys(tabBtns) as View[]).forEach((v) => {
      tabBtns[v].classList.toggle("live", st.view === v);
      tabBtns[v].textContent = v[0].toUpperCase() + v.slice(1);
      if (v === "chat" && st.permissions.length) {
        const pip = document.createElement("span");
        pip.className = "bc-pip";
        pip.textContent = String(st.permissions.length);
        tabBtns[v].appendChild(pip);
      }
    });
    if (st.view === "chat") renderChat();
    else if (st.view === "sessions") renderSessions();
    else renderSettings();
  }

  const unsub = store.subscribe(render);
  render();
  void refreshSessions();

  return () => {
    stopStream?.();
    unsub();
  };
}
