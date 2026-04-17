# claudevm

Manage multiple Anthropic Claude API keys — like `nvm`, but for Claude accounts.

```
  ▶ work          sk-ant-api0****a3f2  (active)
    personal      sk-ant-api0****9c11
    client-acme   sk-ant-api0****f807
```

Switch accounts instantly, run commands under a specific key without touching global state, and never paste an API key twice.

---

## Install

**One-liner:**
```bash
curl -fsSL https://raw.githubusercontent.com/quantumInfection/claudevm/main/install.sh | bash
```

**Manual:**
```bash
curl -fsSL https://raw.githubusercontent.com/quantumInfection/claudevm/main/claudevm \
  -o /usr/local/bin/claudevm && chmod +x /usr/local/bin/claudevm
```

Requires **Python 3.6+** (no third-party dependencies).

---

## Shell integration

Add to `~/.zshrc` or `~/.bashrc` (one time):
```bash
eval "$(claudevm init)"
```

Then reload:
```bash
source ~/.zshrc
```

> This installs a shell function that makes `claudevm use` and `claudevm logout` actually modify the current shell's environment. Without it, all other commands work — only `use`/`logout` need it.

---

## Usage

### Add an account
```bash
claudevm add work     sk-ant-api03-...
claudevm add personal sk-ant-api03-...
claudevm add work     sk-ant-api03-...  --force   # overwrite existing
```

### Switch accounts
```bash
claudevm use work          # switch by name
claudevm use               # interactive arrow-key picker
```

### List accounts
```bash
claudevm list
```
```
  ▶ work          sk-ant-api0****a3f2  (active)
    personal      sk-ant-api0****9c11
```

### Run a command under a specific account
```bash
claudevm exec personal -- claude "summarize this file"
claudevm exec client-acme -- claude --model claude-opus-4-5 "review this PR"
```
Does **not** modify global environment. Safe for scripts.

### Other commands
```bash
claudevm current              # show active account name
claudevm logout               # unset ANTHROPIC_API_KEY + CLAUDEVM_CURRENT
claudevm remove personal      # prompts to confirm (--force to skip)
claudevm rename work company  # rename without losing the key
```

---

## How it works

Claude CLI reads `ANTHROPIC_API_KEY` from the environment. `claudevm` stores named keys in `~/.claudevm/accounts.json` (permissions: `600`) and handles switching via a shell function wrapper:

```
claudevm use work
    └─► shell function calls: command claudevm use work --shell
            └─► Python outputs:  export ANTHROPIC_API_KEY='sk-ant-...'
                                  export CLAUDEVM_CURRENT='work'
        └─► shell eval()s the output → env vars set in current shell
```

`claudevm exec` forks a subprocess with a modified environment — the parent shell is untouched.

---

## Storage

```
~/.claudevm/
└── accounts.json    # permissions: 600 (owner read/write only)
```

```json
{
  "work": "sk-ant-api03-...",
  "personal": "sk-ant-api03-..."
}
```

Keys are **never printed in full** — always masked as `sk-ant-api0****xxxx`.

---

## Environment variables

| Variable | Set by | Purpose |
|---|---|---|
| `ANTHROPIC_API_KEY` | `claudevm use` | Picked up by the Claude CLI |
| `CLAUDEVM_CURRENT` | `claudevm use` | Tracks the active account name |

---

## Tips

**Use in scripts (CI/CD):**
```bash
claudevm exec ci-bot -- claude "run eval suite"
```

**One-time switch without shell integration:**
```bash
eval "$(claudevm use work --shell)"
```

**Disable colors:**
```bash
NO_COLOR=1 claudevm list
```

---

## Contributing

Bug reports and PRs welcome. See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT — see [LICENSE](LICENSE).
