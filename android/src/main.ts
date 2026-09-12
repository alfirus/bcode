// bcode Acode entry — mounts our own chat UI into an Acode tab page.
// Init contract follows the official acode-plugin-preact template:
// setPluginInit(id, (baseUrl, $page, options) => …), secrets via options.ctx.

import plugin from "../plugin.json";
import { ServeClient } from "./api";
import { Store } from "./store";
import { mountChat } from "./ui";
import css from "./bcode.css";

const STYLE_ID = "bcode-remote-style";
const OPEN_CMD = "bcode.remote:open";

class BcodePlugin {
  #page: Acode.WCPage | null = null;
  #unmountUI: (() => void) | null = null;
  #store = new Store();
  #api: ServeClient | null = null;
  #apiKey = "";

  async init(_baseUrl: string, $page: Acode.WCPage, options: Acode.PluginInitOptions): Promise<void> {
    this.#page = $page;
    $page.settitle("bcode");
    $page.initializeIfNotAlreadyInitialized();

    if (!document.getElementById(STYLE_ID)) {
      const style = document.createElement("style");
      style.id = STYLE_ID;
      style.textContent = css;
      document.head.appendChild(style);
    }

    const root = document.createElement("div");
    root.classList.add("bc-page");
    $page.appendBody(root);

    await this.#store.load(options?.ctx ?? null);
    this.#unmountUI = mountChat(root, {
      store: this.#store,
      getApi: () => this.#getApi(),
      toast: (msg) => {
        try {
          window.toast(msg);
        } catch {
          /* toast unavailable */
        }
      },
      openSettings: () => this.#store.update({ view: "settings" }),
    });

    acode.addCommand({
      name: OPEN_CMD,
      description: "bcode: open remote chat",
      exec: () => {
        this.#page?.show();
        return true;
      },
    });
  }

  /** Lazily (re)build the client so Settings saves take effect immediately. */
  #getApi(): ServeClient | null {
    const st = this.#store.state;
    if (!st.serverUrl || !this.#store.password) return null;
    const key = `${st.serverUrl}|${st.username}|${this.#store.password.length}`;
    if (!this.#api || this.#apiKey !== key) {
      this.#api = new ServeClient(st.serverUrl, st.username, this.#store.password);
      this.#apiKey = key;
    }
    return this.#api;
  }

  async destroy(): Promise<void> {
    this.#unmountUI?.();
    this.#unmountUI = null;
    try {
      acode.removeCommand(OPEN_CMD);
    } catch {
      /* older Acode */
    }
    document.getElementById(STYLE_ID)?.remove();
    this.#page = null;
    this.#api = null;
  }
}

if (window.acode) {
  const instance = new BcodePlugin();
  acode.setPluginInit(plugin.id, (baseUrl, $page, options) => instance.init(baseUrl, $page, options));
  acode.setPluginUnmount(plugin.id, () => instance.destroy());
}
