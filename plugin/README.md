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

Tools: `bcode_pair` (pairing codes), `bcode_notify` (phone notifications).
