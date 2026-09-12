# bcode-remote (OpenCode plugin)

Server-side half of bcode. Install globally on the machine that runs `opencode serve`:

```sh
opencode plugin ./plugin -g
# or after publish:
opencode plugin bcode-remote -g
```

`opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "plugin": ["bcode-remote"],
  "bcode": { "notifyUrl": "https://push.example.com/bcode" }
}
```

Tools: `bcode_pair` (generate code) / `bcode_pair_redeem` (verify +
consume, single-use) / `bcode_pair_list` (pending codes) /
`bcode_notify` (phone notifications).

Pairing flow (v0.1): desktop agent runs `bcode_pair` → reads the 6-digit
code to you → you type it into the phone with the server URL → agent
confirms with `bcode_pair_redeem`. Codes expire after 10 min and burn on
first use. Full device-approval handshake lands in v0.2.
