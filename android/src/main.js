// bcode Acode client — v0.1 skeleton.
// Pattern learned from acode-ai-agent: WebView-safe only — fetch + SSE reader,
// no Node built-ins, no sockets, no localhost servers. Secrets via
// plugin-scoped secure storage (getSecret/setSecret), never localStorage.

const $statusbar = acode.require("statusbar");
const $settings = acode.require("settings");

const DEFAULTS = { serverUrl: "http://100.121.188.113:4096", username: "opencode" };

class BcodeClient {
  constructor() {
    this.pluginId = "bcode.remote.client";
  }

  async serverUrl() {
    return (await this.secret("bcode.server.url")) || DEFAULTS.serverUrl;
  }

  async authHeader() {
    const user = (await this.secret("bcode.server.username")) || DEFAULTS.username;
    const pass = (await this.secret("bcode.server.password")) || "";
    return "Basic " + btoa(`${user}:${pass}`);
  }

  async secret(key) {
    try {
      const ctx = acode.getPluginCtx?.(this.pluginId);
      if (ctx?.getSecret) return await ctx.getSecret(key);
    } catch {}
    return null;
  }

  async call(path, { method = "GET", body } = {}) {
    const res = await fetch(`${await this.serverUrl()}${path}`, {
      method,
      headers: {
        "content-type": "application/json",
        authorization: await this.authHeader(),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (!res.ok) throw new Error(`bcode: ${method} ${path} → ${res.status}`);
    return res.json();
  }

  health() { return this.call("/global/health"); }
  sessions() { return this.call("/session"); }
  newSession(title) { return this.call("/session", { method: "POST", body: { title } }); }
  sendAsync(sessionID, text) {
    return this.call(`/session/${sessionID}/prompt_async`, {
      method: "POST",
      body: { parts: [{ type: "text", text }] },
    });
  }
  abort(sessionID) { return this.call(`/session/${sessionID}/abort`, { method: "POST" }); }
  permission(sessionID, permissionID, allow) {
    return this.call(`/session/${sessionID}/permissions/${permissionID}`, {
      method: "POST",
      body: { response: allow ? "allow" : "reject" },
    });
  }

  // SSE via fetch reader — same transport acode-ai-agent pins (no WebSocket).
  async *events(path = "/global/event", onLine) {
    const res = await fetch(`${await this.serverUrl()}${path}`, {
      headers: { authorization: await this.authHeader(), accept: "text/event-stream" },
    });
    const reader = res.body.getReader();
    const dec = new TextDecoder();
    let buf = "";
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      buf += dec.decode(value, { stream: true });
      const lines = buf.split("\n");
      buf = lines.pop();
      for (const line of lines) {
        if (line.startsWith("data:")) {
          const payload = line.slice(5).trim();
          if (onLine) onLine(payload);
          yield payload;
        }
      }
    }
  }
}

const client = new BcodeClient();

class BcodePlugin {
  async init() {
    $statusbar.add("bcode", "bcode");
    acode.registerCommand("bcode: open", "bcode: Open remote session", () => this.open());
    acode.registerCommand("bcode: setup", "bcode: Server setup", () => this.setup());
  }

  async open() {
    const sessions = await client.sessions().catch((e) => {
      acode.alert("bcode", String(e.message || e));
      return [];
    });
    const names = (sessions || []).map((s) => s.title || s.id);
    acode.alert("bcode — sessions", names.length ? names.join("\n") : "No sessions. Create one from desktop first (v0.1).");
  }

  async setup() {
    const url = await acode.prompt("Server URL (Tailscale)", DEFAULTS.serverUrl);
    if (!url) return;
    const password = await acode.prompt("Password (OPENCODE_SERVER_PASSWORD)", "", "password");
    if (password === null) return;
    const ctx = acode.getPluginCtx?.("bcode.remote.client");
    if (ctx?.setSecret) {
      await ctx.setSecret("bcode.server.url", url);
      await ctx.setSecret("bcode.server.password", password);
      acode.alert("bcode", "Saved to secure storage.");
    } else {
      acode.alert("bcode", "Secure storage unavailable on this Acode build.");
    }
  }

  async destroy() {
    $statusbar.remove?.("bcode");
  }
}

if (typeof window !== "undefined") {
  window.bcode = {
    client,
    require: (name) => {
      if (name === "bcode.runtime") {
        return {
          open: () => new BcodePlugin().open(),
          registerContext: (id, fn) => console.log("[bcode] context registered:", id),
        };
      }
      throw new Error(`bcode: unknown module ${name}`);
    },
  };
}

export default BcodePlugin;
