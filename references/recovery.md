# Recovery and disconnect

Use this reference only after an actual status, OAuth, Connector, binding, or
MCP failure. Normal setup acknowledgements use setup.md's continuation route.

```text
OBSERVE → CLASSIFY → MINIMAL REPAIR → RETRY ORIGINAL FAILURE → VERIFY → STOP
```

## Common recovery

1. Preserve the first real error. Run `<chatcodeplus> status -w <workspace>
   --json`; run `doctor --no-fix --json` only when status cannot identify the
   failing boundary. Apply at most its single automatic repair, then retry the
   original operation once.
2. Keep failure classes separate:
   - `Unauthorized`: reconnect/authorize the existing Connector.
   - `WORKSPACE_NOT_BOUND`: OAuth works. Keep the same conversation, run
     `<chatcodeplus> bind -w <workspace> --json`, send that fresh capability to
     the same conversation, and retry `workspace_snapshot({ bind_code })`
     exactly once. On success, continue with no code and stop recovery.
   - expired/rejected bind capability: run the same `bind` command for a fresh
     capability and retry the original snapshot once, with no fallback
     workspace.
   - stale `workspace_snapshot` schema or missing ChatCodePlus tools: reconnect
     the same Connector/URL; re-pair only if its authorization page asks.
   - changed Quick Tunnel URL: update the existing Connector Server URL, reopen
     the saved conversation, and retry without a bind code. Tunnel changes do
     not clear or replace conversation bindings.
   - unhealthy fixed connection: read `named-tunnel.md`; never replace it with a
     Quick Tunnel automatically.
3. Report success only after the original operation succeeds. Stop after the
   smallest read verifies recovery.

Pairing remains just-in-time: when the visible page requests it, run
`<chatcodeplus> pair --json` directly. Do not precede it with setup, discovery,
doctor, Tunnel restart, or workspace registration.

## Connector invocation

Manual per-conversation selection/enablement is allowed only when direct
evidence shows the INIT could not invoke ChatCodePlus: tools are absent, schema
is stale, the product explicitly requires enablement, or no
`workspace_snapshot` call followed the INIT. Then inspect/enable the existing
Connector and retry the same reuse INIT; use a new-binding INIT only after an
explicit `WORKSPACE_NOT_BOUND` result. Never make this normal onboarding, ask
for a greeting, or create a duplicate Connector.

## Network boundary

Investigate network/proxy state only when the original failure identifies that
path. For a fixed hostname or confirmed Windows Clash/Mihomo stack, use
`named-tunnel.md`, the canonical owner of those rules. For another stack:

1. Identify the running network owner and its active source configuration.
2. Modify only a confirmed, user-owned source using supported semantics.
3. Make one reversible, minimal change; reload through the owner's mechanism.
4. Retry the original failure and verify.

If ownership, source, policy, or semantics are uncertain, stop and give one
manual action. Never guess paths, edit generated/subscription-managed output,
disable TLS/security, change system DNS/routes, add a CA, use sudo/root, or
create a relay/public port.

## State and process recovery

Canonical state is `~/.chatcodeplus`. Legacy formats are one-time migration
input only; preserve failed input and never keep an old-path fallback. Do not
move, rewrite, or delete credentials as a read/repair side effect. Credential
adoption must be explicit and transactional, with the source recoverable until
commit.

If a confirmed old Gateway serves the fixed hostname, stop it and restart this
runtime once; do not create another per-workspace service or Tunnel. Existing
bindings persist across that restart. If a saved conversation is confirmed to
have disappeared, create a new conversation, run `<chatcodeplus> bind -w
<workspace> --json`, and use a fresh new-binding INIT.

## Disconnect

Run `<chatcodeplus> unpair` to revoke this OS user's machine OAuth tokens. The
user removes the Connector in ChatGPT Settings. Existing local conversation
bindings remain unusable until a new authorization succeeds.
