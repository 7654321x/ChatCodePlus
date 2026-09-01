#!/usr/bin/env sh
set -eu
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_ROOT=$(dirname "$SCRIPT_DIR")
RUNTIME="$SKILL_ROOT/runtime/chatcodeplus.mjs"
MANIFEST="$SKILL_ROOT/runtime/manifest.json"
DEFAULT_STATE="$HOME/.chatcodeplus"
STATE_DIR=${CHATCODEPLUS_STATE_DIR:-"$DEFAULT_STATE"}
TOOLS="$STATE_DIR/tools"
MANAGED_NODE="$TOOLS/node/bin/node"
MANAGED_CF="$TOOLS/cloudflared/cloudflared"

[ -f "$RUNTIME" ] && [ -f "$MANIFEST" ] || { echo "ChatCodePlus Skill runtime is incomplete. Reinstall the Skill." >&2; exit 1; }
EXPECTED=$(sed -n 's/.*"runtimeSha256": "\([0-9a-f]*\)".*/\1/p' "$MANIFEST")
MINIMUM_NODE=$(sed -n 's/.*"minimumNodeMajor": \([0-9][0-9]*\).*/\1/p' "$MANIFEST")
if command -v sha256sum >/dev/null 2>&1; then ACTUAL=$(sha256sum "$RUNTIME" | awk '{print $1}'); else ACTUAL=$(shasum -a 256 "$RUNTIME" | awk '{print $1}'); fi
[ "$EXPECTED" = "$ACTUAL" ] || { echo "ChatCodePlus Skill runtime integrity check failed. Reinstall the Skill." >&2; exit 1; }

NODE=""
if [ -x "$MANAGED_NODE" ]; then
  NODE="$MANAGED_NODE"
elif command -v node >/dev/null 2>&1 && [ "$(node -p "Number(process.versions.node.split('.')[0]) >= Number('$MINIMUM_NODE')")" = true ]; then
  NODE=$(command -v node)
fi
[ -n "$NODE" ] || { echo "Node.js is missing or too old. Run: $SCRIPT_DIR/bootstrap.sh --install" >&2; exit 1; }
if [ -x "$MANAGED_CF" ]; then PATH="$(dirname "$MANAGED_CF"):$PATH"; export PATH; fi
exec "$NODE" "$RUNTIME" "$@"
