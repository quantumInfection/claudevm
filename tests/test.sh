#!/usr/bin/env bash
# claudevm test suite
set -euo pipefail

CLAUDEVM="$(cd "$(dirname "$0")/.." && pwd)/claudevm"
PASS=0; FAIL=0

# Isolated storage for tests
export HOME; HOME="$(mktemp -d)"
trap 'rm -rf "$HOME"' EXIT

RED='\033[91m'; GREEN='\033[92m'; RESET='\033[0m'

# (( n++ )) returns old value; when n=0 that's falsy under set -e.
# Use || true to make the increment always succeed.
pass() { echo -e "  ${GREEN}✓${RESET} $1"; (( PASS++ )) || true; }
fail() { echo -e "  ${RED}✗${RESET} $1"; (( FAIL++ )) || true; }

# Capture both stdout+stderr; never propagate non-zero exit upward.
run() { NO_COLOR=1 python3 "$CLAUDEVM" "$@" 2>&1 || true; }

check() {
    local desc="$1" out="$2" pattern="$3"
    if [[ "$out" == *"$pattern"* ]]; then pass "$desc"; else fail "$desc (got: $out)"; fi
}

# ── add ───────────────────────────────────────────────────────────────────────
echo "add"

out=$(run add work sk-ant-api03-testkey1234567890abc)
check "add account"         "$out" "work added"

out=$(run add work sk-ant-api03-otherkey12345678)
check "reject duplicate"    "$out" "already exists"

run add work sk-ant-api03-newkey1234567890xyz --force > /dev/null
out=$(run list)
check "--force overwrites"  "$out" "work"

out=$(run add "bad name!" sk-ant-api03-x)
check "reject invalid name" "$out" "invalid name"

out=$(run add shortkey tooshort)
check "reject short key"    "$out" "invalid"

# ── list ──────────────────────────────────────────────────────────────────────
echo "list"

run add personal sk-ant-api03-personal000000000 > /dev/null
out=$(run list)
check "list shows accounts"  "$out" "work"
check "list shows multiple"  "$out" "personal"

# Key must be masked — the raw key fragment after prefix should not appear
if [[ "$out" == *"newkey1234567890xyz"* ]]; then
    fail "list must mask keys"
else
    pass "list masks keys"
fi

# ── use (shell mode) ──────────────────────────────────────────────────────────
echo "use --shell"

out=$(NO_COLOR=1 python3 "$CLAUDEVM" use work --shell 2>/dev/null)
check "use outputs export"       "$out" "export ANTHROPIC_API_KEY="
check "use sets CLAUDEVM_CURRENT" "$out" "export CLAUDEVM_CURRENT=work"

key=$(echo "$out" | grep ANTHROPIC_API_KEY | cut -d= -f2 | tr -d "'")
if [[ -n "$key" ]]; then pass "use exports non-empty key"; else fail "use exports non-empty key"; fi

# ── logout (shell mode) ───────────────────────────────────────────────────────
echo "logout --shell"

out=$(NO_COLOR=1 python3 "$CLAUDEVM" logout --shell 2>/dev/null)
check "logout unsets key"  "$out" "unset ANTHROPIC_API_KEY"
check "logout unsets name" "$out" "unset CLAUDEVM_CURRENT"

# ── exec ──────────────────────────────────────────────────────────────────────
echo "exec"

result=$(NO_COLOR=1 python3 "$CLAUDEVM" exec work -- env 2>/dev/null | grep "^ANTHROPIC_API_KEY=" | cut -d= -f2)
if [[ -n "$result" ]]; then pass "exec sets ANTHROPIC_API_KEY"; else fail "exec sets ANTHROPIC_API_KEY"; fi

cur_val=$(NO_COLOR=1 python3 "$CLAUDEVM" exec work -- env 2>/dev/null | grep "^CLAUDEVM_CURRENT=" | cut -d= -f2)
if [[ "$cur_val" == "work" ]]; then pass "exec sets CLAUDEVM_CURRENT"; else fail "exec sets CLAUDEVM_CURRENT: $cur_val"; fi

# exec must not mutate the parent shell
unset ANTHROPIC_API_KEY CLAUDEVM_CURRENT || true
NO_COLOR=1 python3 "$CLAUDEVM" exec work -- true 2>/dev/null
if [[ -z "${ANTHROPIC_API_KEY:-}" ]]; then pass "exec doesn't pollute parent env"; else fail "exec pollutes parent env"; fi

out=$(run exec nosuchaccount -- true)
check "exec rejects unknown account" "$out" "not found"

# ── remove ────────────────────────────────────────────────────────────────────
echo "remove"

run add tempacct sk-ant-api03-tempkey1234567890 > /dev/null
run remove tempacct --force > /dev/null
out=$(run list)
if [[ "$out" != *"tempacct"* ]]; then pass "remove deletes account"; else fail "remove deletes account: $out"; fi

out=$(run remove nosuchacct --force)
check "remove rejects unknown" "$out" "not found"

# ── rename ────────────────────────────────────────────────────────────────────
echo "rename"

run add oldname sk-ant-api03-renamekey1234567890 > /dev/null
run rename oldname newname > /dev/null
out=$(run list)
if [[ "$out" == *"newname"*   ]]; then pass "rename creates new name"; else fail "rename creates new name: $out"; fi
if [[ "$out" != *"oldname"*   ]]; then pass "rename removes old name"; else fail "rename removes old name: $out"; fi
run remove newname --force > /dev/null

# ── security: file permissions ────────────────────────────────────────────────
echo "security"

perms=$(stat -f '%Lp' "$HOME/.claudevm/accounts.json" 2>/dev/null \
     || stat -c '%a'  "$HOME/.claudevm/accounts.json")
if [[ "$perms" == "600" ]]; then pass "accounts.json is 600"; else fail "accounts.json is $perms, expected 600"; fi

# ── current ───────────────────────────────────────────────────────────────────
echo "current"

out=$(run current)
check "current shows no-account message" "$out" "no active account"

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
if [[ $FAIL -eq 0 ]]; then
    echo -e "${GREEN}All ${PASS} tests passed.${RESET}"
else
    echo -e "${RED}${FAIL} failed${RESET}, ${GREEN}${PASS} passed${RESET}."
    exit 1
fi
