#!/usr/bin/env sh
set -eu
MODE=${1:---check}
DEFAULT_STATE="$HOME/.chatcodeplus"
STATE_DIR=${CHATCODEPLUS_STATE_DIR:-"$DEFAULT_STATE"}
TOOLS="$STATE_DIR/tools"
NODE_DIR="$TOOLS/node"
CF_DIR="$TOOLS/cloudflared"
MANAGED_NODE="$NODE_DIR/bin/node"
MANAGED_CF="$CF_DIR/cloudflared"
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
SKILL_ROOT=$(dirname "$SCRIPT_DIR")
RUNTIME="$SKILL_ROOT/runtime/chatcodeplus.mjs"
MANIFEST="$SKILL_ROOT/runtime/manifest.json"
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in x86_64|amd64) ARCH=x64; CF_ARCH=amd64 ;; arm64|aarch64) ARCH=arm64; CF_ARCH=arm64 ;; *) echo "{\"ok\":false,\"code\":\"CHATCODEPLUS_PLATFORM_UNSUPPORTED\",\"architecture\":\"$ARCH\"}"; exit 1 ;; esac
case "$OS" in darwin|linux) ;; *) echo "{\"ok\":false,\"code\":\"CHATCODEPLUS_PLATFORM_UNSUPPORTED\",\"platform\":\"$OS\"}"; exit 1 ;; esac

case "$MODE" in --check|--install) ;; *) echo '{"ok":false,"code":"CHATCODEPLUS_BOOTSTRAP_MODE_INVALID"}'; exit 1 ;; esac

hash_file() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; elif command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | awk '{print $1}'; else return 1; fi; }
runtime_ok=false; runtime_version=""; runtime_detail="Skill runtime or manifest is missing"
if [ -f "$RUNTIME" ] && [ -f "$MANIFEST" ]; then
  runtime_version=$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$MANIFEST")
  expected_runtime=$(sed -n 's/.*"runtimeSha256": "\([0-9a-f]*\)".*/\1/p' "$MANIFEST")
  actual_runtime=$(hash_file "$RUNTIME" 2>/dev/null || true)
  if [ -n "$expected_runtime" ] && [ "$actual_runtime" = "$expected_runtime" ]; then runtime_ok=true; runtime_detail="SHA-256 verified"; else runtime_detail="Runtime SHA-256 does not match manifest"; fi
fi

node_ok=false; node_path=""
if [ -x "$MANAGED_NODE" ]; then node_ok=true; node_path=$MANAGED_NODE; elif command -v node >/dev/null 2>&1 && [ "$(node -p "Number(process.versions.node.split('.')[0]) >= 20")" = true ]; then node_ok=true; node_path=$(command -v node); fi
cf_ok=false; cf_path=""
if [ -x "$MANAGED_CF" ]; then cf_ok=true; cf_path=$MANAGED_CF; elif command -v cloudflared >/dev/null 2>&1; then cf_ok=true; cf_path=$(command -v cloudflared); fi
write_parent=$STATE_DIR
while [ ! -e "$write_parent" ] && [ "$write_parent" != / ]; do write_parent=$(dirname "$write_parent"); done
writable=false
[ -d "$write_parent" ] && [ -w "$write_parent" ] && writable=true
node_network=false; github_network=false; NODE_INDEX=""; CF_API=""; NODE_AVAILABLE=""; CF_AVAILABLE=""
if command -v curl >/dev/null 2>&1; then
  NODE_INDEX=$(curl -fsSL --max-time 5 https://nodejs.org/dist/index.json 2>/dev/null || true)
  CF_API=$(curl -fsSL --max-time 5 -H 'User-Agent: chatcodeplus' https://api.github.com/repos/cloudflare/cloudflared/releases/latest 2>/dev/null || true)
  [ -z "$NODE_INDEX" ] || { node_network=true; NODE_AVAILABLE=$(printf '%s' "$NODE_INDEX" | tr '{' '\n' | grep '"version":"v22\.' | grep '"lts":' | head -n 1 | sed -n 's/.*"version":"\([^"]*\)".*/\1/p'); }
  [ -z "$CF_API" ] || { github_network=true; CF_AVAILABLE=$(printf '%s' "$CF_API" | sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' | head -n 1); }
fi
overall=false
[ "$runtime_ok" = true ] && [ "$writable" = true ] && [ "$node_ok" = true ] && [ "$cf_ok" = true ] && overall=true
emit() { printf '{"schemaVersion":1,"ok":%s,"platform":"%s","architecture":"%s","writable":%s,"runtime":{"ok":%s,"version":"%s","detail":"%s"},"node":{"ok":%s,"path":"%s"},"cloudflared":{"ok":%s,"path":"%s"},"network":{"nodejs":%s,"github":%s},"downloads":[{"component":"node","version":"%s","source":"https://nodejs.org/dist/","required":%s},{"component":"cloudflared","version":"%s","source":"https://github.com/cloudflare/cloudflared/releases","required":%s}],"installDirectory":"%s"}\n' "$overall" "$OS" "$ARCH" "$writable" "$runtime_ok" "$runtime_version" "$runtime_detail" "$node_ok" "$node_path" "$cf_ok" "$cf_path" "$node_network" "$github_network" "$NODE_AVAILABLE" "$( [ "$node_ok" = true ] && printf false || printf true )" "$CF_AVAILABLE" "$( [ "$cf_ok" = true ] && printf false || printf true )" "$TOOLS"; }
[ "$MODE" = "--install" ] || { emit; exit 0; }
[ "$runtime_ok" = true ] || { echo '{"ok":false,"code":"CHATCODEPLUS_RUNTIME_INTEGRITY_FAILED","action":"Reinstall the complete Skill package."}'; exit 1; }
command -v curl >/dev/null 2>&1 || { echo '{"ok":false,"code":"CHATCODEPLUS_DOWNLOAD_TOOL_MISSING","action":"Install curl and retry."}'; exit 1; }
[ "$writable" = true ] || { echo '{"ok":false,"code":"CHATCODEPLUS_INSTALL_DIRECTORY_NOT_WRITABLE"}'; exit 1; }
mkdir -p "$TOOLS"
TMP=$(mktemp -d "$TOOLS/.install.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM
sha_file() { hash_file "$1"; }
swap_dir() {
  stage=$1; destination=$2; backup="$destination.old-$$"
  [ ! -e "$backup" ] || rm -rf "$backup"
  if [ -e "$destination" ]; then mv "$destination" "$backup"; fi
  if mv "$stage" "$destination"; then
    [ ! -e "$backup" ] || rm -rf "$backup"
  else
    [ ! -e "$backup" ] || mv "$backup" "$destination"
    return 1
  fi
}
if [ "$node_ok" != true ]; then
  [ -n "$NODE_INDEX" ] || NODE_INDEX=$(curl -fsSL https://nodejs.org/dist/index.json)
  VERSION=$(printf '%s' "$NODE_INDEX" | tr '{' '\n' | grep '"version":"v22\.' | grep '"lts":' | head -n 1 | sed -n 's/.*"version":"\([^"]*\)".*/\1/p')
  [ -n "$VERSION" ] || { echo "Unable to resolve Node.js 22 LTS" >&2; exit 1; }
  case "$OS" in darwin) ASSET="node-$VERSION-darwin-$ARCH.tar.gz" ;; linux) ASSET="node-$VERSION-linux-$ARCH.tar.xz" ;; esac
  curl -fsSL "https://nodejs.org/dist/$VERSION/SHASUMS256.txt" -o "$TMP/SHASUMS256.txt"
  EXPECTED=$(awk -v asset="$ASSET" '$2 == asset {print $1}' "$TMP/SHASUMS256.txt")
  curl -fL "https://nodejs.org/dist/$VERSION/$ASSET" -o "$TMP/$ASSET"
  [ "$(sha_file "$TMP/$ASSET")" = "$EXPECTED" ] || { echo "Node.js checksum verification failed" >&2; exit 1; }
  mkdir "$TMP/node"; tar -xf "$TMP/$ASSET" -C "$TMP/node" --strip-components=1
  swap_dir "$TMP/node" "$NODE_DIR"
  node_ok=true; node_path=$MANAGED_NODE
fi
if [ "$cf_ok" != true ]; then
  case "$OS" in darwin) ASSET="cloudflared-darwin-$CF_ARCH.tgz" ;; linux) ASSET="cloudflared-linux-$CF_ARCH" ;; esac
  [ -n "$CF_API" ] || CF_API=$(curl -fsSL -H 'User-Agent: chatcodeplus' https://api.github.com/repos/cloudflare/cloudflared/releases/latest)
  BLOCK=$(printf '%s' "$CF_API" | awk -v asset="$ASSET" '
    index($0, "\"name\": \"" asset "\"") { found=1 }
    found { print }
    found && /"browser_download_url"/ { exit }
  ')
  URL=$(printf '%s' "$BLOCK" | sed -n 's/.*"browser_download_url": "\([^"]*\)".*/\1/p')
  EXPECTED=$(printf '%s' "$BLOCK" | sed -n 's/.*"digest": "sha256:\([0-9a-f]*\)".*/\1/p')
  [ -n "$URL" ] && [ -n "$EXPECTED" ] || { echo "cloudflared release metadata is incomplete" >&2; exit 1; }
  curl -fL "$URL" -o "$TMP/$ASSET"
  [ "$(sha_file "$TMP/$ASSET")" = "$EXPECTED" ] || { echo "cloudflared checksum verification failed" >&2; exit 1; }
  mkdir "$TMP/cloudflared-ready"
  if [ "$OS" = darwin ]; then tar -xzf "$TMP/$ASSET" -C "$TMP"; mv "$TMP/cloudflared" "$TMP/cloudflared-ready/cloudflared"; else mv "$TMP/$ASSET" "$TMP/cloudflared-ready/cloudflared"; fi
  chmod 755 "$TMP/cloudflared-ready/cloudflared"
  swap_dir "$TMP/cloudflared-ready" "$CF_DIR"
  cf_ok=true; cf_path=$MANAGED_CF
fi
emit
