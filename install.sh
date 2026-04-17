#!/usr/bin/env bash
# claudevm installer
# Usage: curl -fsSL https://raw.githubusercontent.com/quantumInfection/claudevm/main/install.sh | bash

set -euo pipefail

REPO="quantumInfection/claudevm"
SCRIPT="claudevm"
INSTALL_DIR="${CLAUDEVM_INSTALL_DIR:-/usr/local/bin}"

RED='\033[91m'; GREEN='\033[92m'; YELLOW='\033[93m'; BOLD='\033[1m'; RESET='\033[0m'

info()  { echo -e "${BOLD}$*${RESET}"; }
ok()    { echo -e "${GREEN}✓${RESET} $*"; }
warn()  { echo -e "${YELLOW}warning:${RESET} $*"; }
die()   { echo -e "${RED}error:${RESET} $*" >&2; exit 1; }

# Require Python 3.6+
python3 --version &>/dev/null || die "Python 3 is required but not found."
PY_VER=$(python3 -c 'import sys; print(sys.version_info.minor)')
[ "$PY_VER" -ge 6 ] || die "Python 3.6+ required (found 3.$PY_VER)."

info "Installing claudevm..."

# Determine install location
ADDED_TO_PATH=false
if [ ! -w "$INSTALL_DIR" ]; then
    warn "$INSTALL_DIR is not writable — trying ~/.local/bin"
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) ;;
        *) ADDED_TO_PATH=true ;;
    esac
fi

# Download
DEST="$INSTALL_DIR/$SCRIPT"
if command -v curl &>/dev/null; then
    curl -fsSL "https://raw.githubusercontent.com/$REPO/main/$SCRIPT" -o "$DEST"
elif command -v wget &>/dev/null; then
    wget -qO "$DEST" "https://raw.githubusercontent.com/$REPO/main/$SCRIPT"
else
    die "curl or wget required."
fi
chmod +x "$DEST"
ok "claudevm installed to $DEST"

# Shell integration
SHELL_INIT_LINE='eval "$(claudevm init)"'
DETECTED_RC=""
case "$SHELL" in
    */zsh)  DETECTED_RC="$HOME/.zshrc" ;;
    */bash) DETECTED_RC="$HOME/.bashrc" ;;
esac

# PATH not in current session always requires a reload
NEEDS_RELOAD=$ADDED_TO_PATH

echo ""
info "Shell integration:"
if [ -n "$DETECTED_RC" ]; then
    INIT_PRESENT=false
    grep -q 'claudevm init' "$DETECTED_RC" 2>/dev/null && INIT_PRESENT=true

    if $ADDED_TO_PATH; then
        if grep -q "$INSTALL_DIR" "$DETECTED_RC" 2>/dev/null; then
            ok "$INSTALL_DIR already in PATH config"
        else
            PATH_BLOCK="\\n# claudevm: add ~/.local/bin to PATH\\nexport PATH=\"$INSTALL_DIR:\$PATH\""
            if $INIT_PRESENT; then
                # Insert PATH export *before* the existing claudevm init block so it
                # is available when claudevm init runs on shell startup.
                python3 - "$DETECTED_RC" "$INSTALL_DIR" <<'PYEOF'
import sys
rc, install_dir = sys.argv[1], sys.argv[2]
lines = open(rc).readlines()
insert = [f'\n# claudevm: add ~/.local/bin to PATH\nexport PATH="{install_dir}:$PATH"\n']
out = []
injected = False
for line in lines:
    if not injected and 'claudevm shell integration' in line:
        out.extend(insert)
        injected = True
    out.append(line)
if not injected:
    out.extend(insert)
open(rc, 'w').writelines(out)
PYEOF
            else
                printf '\n# claudevm: add ~/.local/bin to PATH\nexport PATH="%s:$PATH"\n' "$INSTALL_DIR" >> "$DETECTED_RC"
            fi
            ok "Added $INSTALL_DIR to PATH in $DETECTED_RC"
        fi
    fi

    if $INIT_PRESENT; then
        ok "Already configured in $DETECTED_RC"
    else
        printf '\n# claudevm shell integration\n%s\n' "$SHELL_INIT_LINE" >> "$DETECTED_RC"
        ok "Added shell integration to $DETECTED_RC"
        NEEDS_RELOAD=true
    fi
else
    echo "  Add to your shell config (~/.zshrc or ~/.bashrc):"
    echo ""
    if $ADDED_TO_PATH; then
        echo "    export PATH=\"$INSTALL_DIR:\$PATH\""
    fi
    echo "    $SHELL_INIT_LINE"
    echo ""
fi

echo ""
if $NEEDS_RELOAD && [ -n "$DETECTED_RC" ]; then
    echo -e "  ${YELLOW}Reload your shell to apply changes:${RESET}"
    echo -e "    ${BOLD}source $DETECTED_RC${RESET}  (or open a new terminal)"
    echo ""
fi
ok "Done! Run ${BOLD}claudevm help${RESET} to get started."
