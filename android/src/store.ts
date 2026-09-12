// bcode store — UI state + secure server config. No secrets in plain storage.

export type Role = "user" | "assistant" | "system";
export type View = "chat" | "sessions" | "settings";

export interface ChatMessage {
  id: string;
  role: Role;
  text: string;
  at: number;
  live?: boolean;
}

export interface Session {
  id: string;
  title: string;
  updatedAt: number;
}

export interface PendingPermission {
  id: string;
  sessionId: string;
  tool: string;
  detail: string;
}

export interface State {
  view: View;
  connected: boolean | null; // null = never probed
  serverUrl: string;
  username: string;
  hasPassword: boolean;
  sessions: Session[];
  activeSessionId: string | null;
  messages: ChatMessage[];
  sending: boolean;
  permissions: PendingPermission[];
  notice: string | null;
  noticeKind: "info" | "error";
}

type Ctx = Acode.PluginContext | null;
type Listener = () => void;

const K_URL = "bcode.server.url";
const K_USER = "bcode.server.username";
const K_PASS = "bcode.server.password";

export const DEFAULT_URL = "http://100.121.188.113:4096";

export class Store {
  #state: State = {
    view: "chat",
    connected: null,
    serverUrl: DEFAULT_URL,
    username: "opencode",
    hasPassword: false,
    sessions: [],
    activeSessionId: null,
    messages: [],
    sending: false,
    permissions: [],
    notice: null,
    noticeKind: "info",
  };
  #listeners = new Set<Listener>();
  #ctx: Ctx = null;
  #password = "";

  get state(): State {
    return this.#state;
  }

  subscribe(fn: Listener): () => void {
    this.#listeners.add(fn);
    return () => this.#listeners.delete(fn);
  }

  update(patch: Partial<State>): void {
    this.#state = { ...this.#state, ...patch };
    for (const fn of this.#listeners) fn();
  }

  notice(text: string, kind: "info" | "error" = "info"): void {
    this.update({ notice: text, noticeKind: kind });
  }

  clearNotice(): void {
    if (this.#state.notice) this.update({ notice: null });
  }

  /** Load server config from plugin-scoped secrets (never localStorage). */
  async load(ctx: Ctx): Promise<void> {
    this.#ctx = ctx;
    if (!ctx) return;
    try {
      const url = await ctx.getSecret(K_URL, "");
      const user = await ctx.getSecret(K_USER, "");
      const pass = await ctx.getSecret(K_PASS, "");
      this.#password = pass ?? "";
      this.update({
        serverUrl: url || DEFAULT_URL,
        username: user || "opencode",
        hasPassword: this.#password.length > 0,
      });
    } catch {
      // storage unavailable — run with defaults, password asked per session
    }
  }

  get password(): string {
    return this.#password;
  }

  async saveServer(url: string, username: string, password: string): Promise<void> {
    const cleanUrl = url.replace(/\/+$/, "");
    this.#password = password;
    this.update({
      serverUrl: cleanUrl,
      username: username || "opencode",
      hasPassword: password.length > 0,
      connected: null,
    });
    if (!this.#ctx) return;
    await this.#ctx.setSecret(K_URL, cleanUrl);
    await this.#ctx.setSecret(K_USER, username || "opencode");
    await this.#ctx.setSecret(K_PASS, password);
  }

  setMessages(messages: ChatMessage[]): void {
    this.update({ messages });
  }

  /** Append (or update, by id) one live-streamed assistant chunk. */
  upsertLiveMessage(id: string, text: string): void {
    const messages = [...this.#state.messages];
    const i = messages.findIndex((m) => m.id === id);
    if (i >= 0) messages[i] = { ...messages[i], text };
    else messages.push({ id, role: "assistant", text, at: Date.now(), live: true });
    this.update({ messages });
  }

  addPermission(p: PendingPermission): void {
    if (this.#state.permissions.some((x) => x.id === p.id)) return;
    this.update({ permissions: [...this.#state.permissions, p] });
    if (this.#state.view !== "chat") this.update({ view: "chat" });
  }

  removePermission(id: string): void {
    this.update({ permissions: this.#state.permissions.filter((p) => p.id !== id) });
  }
}
