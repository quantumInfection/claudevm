# Contributing to claudevm

Thanks for taking the time to contribute.

## Getting started

```bash
git clone https://github.com/quantumInfection/claudevm
cd claudevm
chmod +x claudevm
./claudevm help
```

No build step. No dependencies. Edit `claudevm` and run it directly.

## Running tests

```bash
bash tests/test.sh
```

## Guidelines

- **Keep it a single file.** The zero-dependency, single-file nature is a feature.
- **No new dependencies.** stdlib only.
- **Test your change** with both bash and zsh shell integration.
- **Don't print full API keys** anywhere — always use `mask()`.
- **Preserve Python 3.6 compatibility** (no walrus operator, no `match` statements).

## Reporting bugs

Open an issue with:
- Your OS and shell (`uname -a`, `echo $SHELL`)
- Python version (`python3 --version`)
- The command you ran and the output

## Pull requests

1. Fork → branch → commit → PR
2. Keep PRs focused — one feature or fix per PR
3. Update the README if you add or change a command
