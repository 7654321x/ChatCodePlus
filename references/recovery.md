# Recovery and disconnect

Use this reference only after an actual status, OAuth, Connector, binding, MCP,
Tunnel, or runtime failure. Setup owns normal startup and [protocol.md](protocol.md)
owns wire/binding semantics.

```text
OBSERVE → CLASSIFY → MINIMAL REPAIR → RETRY ORIGINAL FAILURE → VERIFY → STOP
```

Preserve the first real error. Run `<chatcodeplus> status -w <workspace> --json`;
use `doctor --no-fix --json` only when status cannot identify the boundary.
Apply at most the one repair returned by the owner, retry the original action
once, and stop when the smallest read verifies recovery.

## Failure classes

- `Unauthorized`: reconnect or reauthorize the existing Connector. Do not
  create a duplicate and do not generate pairing unless the page asks.
- `WORKSPACE_NOT_BOUND`: OAuth and MCP transport are reachable. Keep the same
  conversation, run `<chatcodeplus> bind -w <workspace> --json`, send the fresh
  capability through the same conversation, and retry
  `workspace_snapshot({ bind_code })` once. On success, continue without a
  code. Never choose a fallback workspace.
- Expired or rejected bind capability: first retry a no-code snapshot in the
  same conversation. Only `WORKSPACE_NOT_BOUND` permits one fresh capability
  and one binding retry.
- Missing ChatCodePlus tools or a stale snapshot schema: reconnect the same
  Connector and URL; reauthorize only if its page asks. A stale host schema is
  not proof that the binding or workspace is gone.
- A token is issued but ChatGPT reports a connection error before an
  authenticated MCP request: treat it as Connector linked-account setup, not a
  binding failure. Refresh the same Connector once after the runtime is
  current; do not generate another pairing code automatically.
- A stale linked-account entry: remove only that user-confirmed stale entry in
  ChatGPT settings, then authorize the existing Connector once. Local valid
  OAuth generations coexist; a later authorization does not invalidate them.
- Changed temporary public URL: update or recreate the existing ChatCodePlus
  Connector with the new `/mcp` URL, finish OAuth only if requested, and reopen
  the saved conversation. Do not clear local registrations, sessions, or
  bindings.
- Unhealthy fixed public connection: an enabled Named Tunnel is supervised by
  the machine Gateway. Brief public-health failures are tolerated; sustained
  failures or an unexpected cloudflared exit trigger automatic verified restart
  with bounded backoff. If it remains unhealthy after those retries, read
  [named-tunnel.md](named-tunnel.md); never replace it with a Quick Tunnel
  automatically.

`WORKSPACE_NOT_BOUND` is not an OAuth failure. A reception timeout or an
unreadable host reply is not binding evidence and must not trigger binding
recovery by itself.

## Network boundary

Investigate proxy or network state only when the original failure identifies
that path. Identify the active owner and its source configuration, make one
minimal reversible change through the owner's supported mechanism, retry the
original failure, and verify. If ownership or semantics are uncertain, stop
with one manual action. Never guess paths, edit generated/subscription-managed
output, disable TLS/security, change system routes, or create a relay.

## Long command diagnostics

If a long `run_command` appears stalled, inspect `~/.chatcodeplus/logs/gateway.log`
and follow its opaque `executionId` across dispatch, queue, process, and monitor
lifecycle events. Use queue position, PID, elapsed time, timeout/exit state,
activity byte counts, and monitor phase to identify the boundary. These records
do not include command arguments, workspace paths, stdout, or stderr content.
Do not start another GPT/Connector request merely to obtain progress; the
Gateway monitor reports status through the current MCP progress channel.

## State and process boundary

Canonical state is `~/.chatcodeplus`. Legacy formats are one-time migration
input only; preserve failed input and never keep an old-path runtime fallback.
Do not move, rewrite, or delete credentials as a read/repair side effect.

If a confirmed old Gateway serves the fixed hostname, stop it and restart this
runtime once; do not create a per-workspace service or second Tunnel. Existing
bindings persist across restart. If a saved conversation is confirmed gone,
create a replacement conversation and use the protocol's explicit target
binding path. Do not infer loss from an unavailable browser or stale URL.

## Pairing and disconnect

When the visible OAuth page asks for a code, run `<chatcodeplus> pair --json`
just in time, return it, and pause for the user to submit it. Do not precede
pairing with setup, discovery, doctor, Tunnel restart, or registration.

Run `<chatcodeplus> unpair` only for the user's explicit machine disconnect.
The user removes the Connector in ChatGPT Settings. Existing local conversation
bindings remain stored but cannot be used until a new authorization succeeds.
