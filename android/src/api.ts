// ServeClient — thin fetch + SSE client over `opencode serve`.
// Shapes follow docs/PROTOCOL.md. Server JSON is read defensively (several
// key spellings) so a minor server drift degrades instead of crashing.

import type { ChatMessage, PendingPermission, Role, Session } from "./store";

type Json = Record<string, unknown>;

function rec(x: unknown): Json {
  return typeof x === "object" && x !== null ? (x as Json) : {};
}

function str(o: Json, keys: string[], fb = ""): string {
  for (const k of keys) {
    const v = o[k];
    if (typeof v === "string" && v) return v;
  }
  return fb;
}

function num(o: Json, keys: string[], fb = 0): number {
  for (const k of keys) {
    const v = o[k];
    if (typeof v === "number" && Number.isFinite(v)) return v;
  }
  return fb;
}

function arr(x: unknown): unknown[] {
  return Array.isArray(x) ? x : [];
}

function roleOf(raw: string): Role {
  return raw === "user" || raw === "system" ? raw : "assistant";
}

/** Pull every plausible text fragment out of a message/part payload. */
function textOf(o: Json): string {
  const direct = str(o, ["text", "content", "value", "output"]);
  if (direct) return direct;
  const parts = arr(o["parts"] ?? o["content"]);
  const chunks: string[] = [];
  for (const p of parts) {
    const r = rec(p);
    const t = str(r, ["text", "content", "value"]);
    if (t) chunks.push(t);
  }
  return chunks.join("\n");
}

export interface LiveEvent {
  type: string;
  sessionId: string;
  text: string;
  permission: PendingPermission | null;
}

export class ServeClient {
  readonly baseUrl: string;
  readonly #auth: string;

  constructor(baseUrl: string, username: string, password: string) {
    this.baseUrl = baseUrl.replace(/\/+$/, "");
    this.#auth = "Basic " + btoa(`${username}:${password}`);
  }

  async #call(path: string, init?: { method?: string; body?: unknown; timeoutMs?: number }): Promise<unknown> {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), init?.timeoutMs ?? 120_000);
    try {
      const res = await fetch(`${this.baseUrl}${path}`, {
        method: init?.method ?? "GET",
        headers: { "content-type": "application/json", authorization: this.#auth },
        body: init?.body === undefined ? undefined : JSON.stringify(init.body),
        signal: ctrl.signal,
      });
      if (!res.ok) throw new Error(`${init?.method ?? "GET"} ${path} → ${res.status}`);
      const text = await res.text();
      return text ? (JSON.parse(text) as unknown) : null;
    } finally {
      clearTimeout(timer);
    }
  }

  /** Connection probe per PROTOCOL.md. */
  async health(): Promise<boolean> {
    try {
      const data = rec(await this.#call("/global/health", { timeoutMs: 10_000 }));
      const healthy = data["healthy"];
      return healthy === undefined ? true : healthy !== false;
    } catch {
      return false;
    }
  }

  async listSessions(): Promise<Session[]> {
    const data = await this.#call("/session", { timeoutMs: 15_000 });
    return arr(data).map((s, i) => {
      const o = rec(s);
      const id = str(o, ["id", "sessionID", "sessionId"], `s${i}`);
      return {
        id,
        title: str(o, ["title", "name"], id.slice(0, 8)),
        updatedAt: num(o, ["updatedAt", "updated_at", "timeUpdated"], 0),
      };
    });
  }

  async createSession(title?: string): Promise<Session> {
    const o = rec(await this.#call("/session", { method: "POST", body: title ? { title } : {} }));
    const id = str(o, ["id", "sessionID", "sessionId"]);
    if (!id) throw new Error("server returned no session id");
    return { id, title: str(o, ["title", "name"], id.slice(0, 8)), updatedAt: Date.now() };
  }

  async getMessages(sessionId: string): Promise<ChatMessage[]> {
    const data = await this.#call(`/session/${sessionId}/message?limit=100`, { timeoutMs: 15_000 });
    return arr(data).map((m, i) => {
      const o = rec(m);
      return {
        id: str(o, ["id", "messageID", "messageId"], `${sessionId}:${i}`),
        role: roleOf(str(o, ["role"])),
        text: textOf(o),
        at: num(o, ["timeCreated", "time_created", "created", "at"], Date.now()),
      };
    });
  }

  /** Primary send path: prompt_async, reply streams back over SSE. */
  async sendAsync(sessionId: string, text: string): Promise<void> {
    await this.#call(`/session/${sessionId}/prompt_async`, {
      method: "POST",
      body: { parts: [{ type: "text", text }] },
    });
  }

  async abort(sessionId: string): Promise<void> {
    await this.#call(`/session/${sessionId}/abort`, { method: "POST", timeoutMs: 10_000 });
  }

  async decidePermission(sessionId: string, permissionId: string, allow: boolean): Promise<void> {
    await this.#call(`/session/${sessionId}/permissions/${permissionId}`, {
      method: "POST",
      body: { response: allow ? "allow" : "reject" },
      timeoutMs: 10_000,
    });
  }

  /**
   * Open the server event stream. Every SSE data payload is normalised into a
   * LiveEvent; unknown shapes are ignored (the post-turn history reload is the
   * source of truth, streaming is progressive enhancement).
   */
  openEvents(sessionId: string, onEvent: (e: LiveEvent) => void): () => void {
    const ctrl = new AbortController();
    void (async () => {
      try {
        const res = await fetch(`${this.baseUrl}/event`, {
          headers: { authorization: this.#auth },
          signal: ctrl.signal,
        });
        if (!res.ok || !res.body) return;
        const reader = res.body.getReader();
        const decoder = new TextDecoder();
        let buf = "";
        for (;;) {
          const { done, value } = await reader.read();
          if (done) break;
          buf += decoder.decode(value, { stream: true });
          const frames = buf.split("\n\n");
          buf = frames.pop() ?? "";
          for (const frame of frames) {
            const ev = this.#parseFrame(sessionId, frame);
            if (ev) onEvent(ev);
          }
        }
      } catch {
        // stream closed / aborted — the turn-end reload covers us
      }
    })();
    return () => ctrl.abort();
  }

  #parseFrame(sessionId: string, frame: string): LiveEvent | null {
    let type = "";
    const payloads: string[] = [];
    for (const line of frame.split("\n")) {
      if (line.startsWith("event:")) type = line.slice(6).trim();
      else if (line.startsWith("data:")) payloads.push(line.slice(5).trim());
    }
    if (!payloads.length) return null;
    let data: Json = {};
    try {
      data = rec(JSON.parse(payloads.join("\n")) as unknown);
    } catch {
      return null;
    }
    const sid = str(data, ["sessionID", "sessionId", "session_id"]);
    if (sid && sid !== sessionId) return null;

    let permission: PendingPermission | null = null;
    if (/permission/i.test(type)) {
      const id = str(data, ["id", "permissionID", "permissionId"]);
      if (id) {
        permission = {
          id,
          sessionId,
          tool: str(data, ["tool", "command", "title", "type"], "permission"),
          detail: str(data, ["detail", "description", "pattern", "path"], textOf(data)),
        };
      }
    }
    const text = textOf(rec(data["part"] ?? data["message"]) ?? data);
    if (!text && !permission) return null;
    return { type, sessionId, text, permission };
  }
}
