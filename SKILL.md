---
name: chatcodeplus
description: >
  Use ChatGPT (web) as the planning and review brain for Codex coding sessions,
  while Codex keeps execution ownership. Use for ChatGPT workspace connection,
  ChatCodePlus planning/review loops, or connection recovery; use the fast status
  route for a connection-status request.
---

# ChatCodePlus

ChatGPT plans and reviews through read-only workspace tools; Codex owns edits,
commands, tests, recovery, and Git.

## Global invariants

- Use only this package's launcher: Windows `pwsh -NoProfile -File
  <skill>/scripts/chatcodeplus.ps1`; macOS/Linux `sh
  <skill>/scripts/chatcodeplus.sh`. Pass `-w <workspace>` to workspace commands.
- One OS user has one machine Gateway, OAuth store, Connector, and active
  connection. Codex must register every accessible workspace locally; remote
  calls cannot select or register filesystem roots.
- OAuth proves the ChatGPT-to-machine connection. A conversation is separately
  bound to one workspace by its authenticated metadata and a short-lived local
  capability. Missing or invalid identity fails closed; never add workspace
  parameters or a fallback workspace.
- Keep all runtime state under `~/.chatcodeplus`, never in the Skill or workspace.
  Never put workspace file content, diffs, logs, raw conversation metadata,
  tokens, cookies, OAuth pairing codes, client secrets, or credentials in
  control messages or ordinary logs. The current INIT may carry its five-minute,
  single-use workspace bind code as defined by `protocol.md`; never repeat or
  log that capability.
- Use the built-in browser for ChatGPT and authorization. Do not perform login,
  consent, CAPTCHA, 2FA, Connector edits, or pairing submission for the user.

Machine OAuth keeps historical client registrations separate from authorization
authority: at most one authorization generation is current. A successful new
authorization-code exchange atomically replaces the previous generation only
after token persistence succeeds. Refresh-token rotation stays within the
current generation. ChatCodePlus has no trusted OpenAI account identity and
must not infer one from OAuth state. Reauthorization does not delete
conversation bindings or saved workspace sessions.

Conversation bindings persist `createdAt` (first binding) and `updatedAt` (last
successful fresh bind, rebind, or reconfirmation). Ordinary workspace reads do
not refresh `updatedAt`. A saved session is only one preferred/latest URL per
workspace: setting a different URL clears inherited title and task metadata;
setting the same canonical URL may retain unspecified metadata. Only approved
HTTPS ChatGPT `/c/<conversation>` URLs are reusable. Invalid session metadata
is rejected on write; a corrupt saved-session file is ignored with a warning,
left untouched, and never blocks OAuth/workspace preflight. Session replacement
is atomic.

## ChatGPT conversation mode constraint

ChatCodePlus does not require Chat mode or Work mode. Do not infer workspace
binding requirements from ChatGPT UI modes. Workspace binding depends only on
whether the current conversation has ChatCodePlus workspace tools and its
canonical conversation binding. If the tools are available, execute the
binding/reuse flow directly. If they are unavailable, report that unavailable
capability; do not invent UI restrictions.

## Routing

- **Status only:** run `<chatcodeplus> status -w <workspace> --json` once. Read
  [recovery.md](references/recovery.md) only when unhealthy or missing a public
  URL.
- **First setup or normal setup continuation:** read
  [setup.md](references/setup.md) only.
- **Fixed hostname selected:** after setup routes there, read
  [named-tunnel.md](references/named-tunnel.md).
- **Missing/damaged runtime or dependency:** read
  [bootstrap.md](references/bootstrap.md).
- **Coding, planning, or review:** read [coding.md](references/coding.md). Read
  [protocol.md](references/protocol.md) only when composing/debugging control
  messages or changing binding/MCP contracts.
- **Repair, reconnect, or disconnect:** read
  [recovery.md](references/recovery.md). Follow a linked network reference only
  when the observed failure is actually network-related.
- **Update:** read [update.md](references/update.md).

Do not preload references to understand the whole system. Read only the route
needed by the current state.

## Task-entry priority

Before following any normal coding, setup, preflight, binding-check, or INIT
instruction, first decide whether the current task qualifies for active-task
fast resume. The same currently confirmed ChatGPT conversation at `PLAN`,
`EXECUTING`, `EXECUTED`, or `REVIEW` must take the `RESUME` route below. This priority is
not optional and is not an optimization to apply after initialization.

After `DONE`, an explicitly requested new task in the same currently confirmed
bound conversation uses a no-capability new-task INIT with a new task ID; it
does not resume the completed task or repeat preflight/binding checks.

Use the normal setup or coding route only when neither bound-task path qualifies, or
when direct evidence shows a new conversation, a different workspace,
`WORKSPACE_NOT_BOUND`, or a binding failure.

Treat this as one message-readiness decision: `RESUME` for an active confirmed
binding; INIT for a no-capability binding check, a new binding, or a new task.
Only the no-capability fallback requires `WORKSPACE_NOT_BOUND` before issuing a
capability; a capability-bearing INIT may be sent directly after a target
workspace is explicitly selected.
Verified runtime or binding failures route to `RECOVERY`; missing runtime or
task facts route to `BLOCKED`. Unknown binding alone permits a no-capability
check when runtime prerequisites are ready. This does not replace binding proof.

## Built-in browser readiness

Before returning or sending a ChatGPT control message, ask the Codex host for
one lightweight built-in-browser readiness check for the current continuous
workflow. Reuse a caller-owned, temporary readiness context after `READY` (or
after a successful open); do not ask the host again for each INIT, PLAN,
EXECUTING, EXECUTED, REVIEW, RESUME, or NEW_TASK message. On
`NOT_READY`, ask the host to open `https://chatgpt.com/` once without waiting
for page rendering; on `UNKNOWN`, record a warning and continue the existing
message route. Do not poll, open a duplicate browser, inspect browser
processes, or use the system browser.

Discard the temporary readiness context and check again only when the host
directly reports `NOT_READY`, the browser is closed or invalid, the host/browser
interaction environment changes, or the user explicitly switches it. This
context is not a conversation/session cache, a URL binding, or a workspace
binding.

Browser readiness is environment preparation only. It never proves, changes,
or replaces a workspace binding; `workspace_snapshot()` and the Gateway
binding store remain the canonical binding source.

The repository's browser/readiness helpers have no production host adapter or
CLI entry point. These are Skill-executor instructions using the host's actual
available tools, not an automatically wired TypeScript pipeline. If that host
capability is absent, report it and return the message for manual delivery.

## Setup continuation fast route

Once setup starts, continue from the last confirmed stage. Do not restart
`DISCOVER → REUSE → REPAIR → ONBOARD` without direct failure evidence.

- Connector configured: continue to the OAuth page. Opening that page does not
  mean OAuth is complete.
- Authorization page requests a code: run `<chatcodeplus> pair --json`
  immediately; do not run setup, status, doctor, discovery, or Tunnel commands.
  Return the code and pause at the user's pairing-submission boundary; do not
  run preflight yet.
- Pairing completed means the user submitted the code and the authorization
  page successfully finished. During first-time pairing, a vague `已授权` does
  not confirm this gate; continue from the last confirmed stage instead.
- After pairing completed, follow setup.md's single preflight continuation
  exactly once. Only `ok=true` with `authorizationReady=true` may continue.
  Reuse a saved conversation without issuing a bind capability when its current
  binding and target workspace are confirmed. For first binding, recovery, or
  an explicit workspace switch, a selected target workspace may receive a
  fresh capability directly.
- Preflight confirms OAuth: follow the host browser-readiness instruction
  above before returning a binding message. Reuse `READY`, request one open
  for `NOT_READY`, and warn on `UNKNOWN` without blocking the message.
  Never substitute the system
  browser or rerun preflight.
- After that best-effort browser preparation, report `ChatGPT 连接成功。` and
  choose setup.md's binding path. A confirmed current binding is reused. When
  the target workspace is selected, issue a fresh capability and return the
  capability-bearing INIT directly. If the binding is unknown and no
  capability is available, send the no-capability binding check; a successful
  `workspace_snapshot()` reuses the binding, while `WORKSPACE_NOT_BOUND` then
  permits the fresh new-binding INIT.

Reuse established Gateway, URL, connection mode, workspace registration, and
OAuth state. A greeting, manual per-conversation Connector selection, broad UI
inspection, and repeated authorization are recovery measures, not normal setup.
If a browser open is queued, wait only for the host action result; do not probe
the ChatGPT UI or ask the user to open it manually.

## Active-task fast resume

For the same currently confirmed ChatGPT conversation, a task at `PLAN`,
`EXECUTING`, `EXECUTED`, or `REVIEW` resumes directly with protocol.md's `RESUME` control
message. Do not run preflight, call `workspace_snapshot()`, generate INIT, or
issue a bind capability for this active-task path. Perform the one
  browser-readiness action above before returning or sending that message;
  within one continuous workflow, reuse the already-confirmed readiness
  context instead of checking again.

Leave fast resume only on direct evidence: a new conversation, a different
workspace, `WORKSPACE_NOT_BOUND`, or a binding failure. Then follow the narrow
existing setup or recovery route. `RESUME` neither stores a conversation ID nor
sends a message automatically; message delivery remains a user or separately
authorized host action.

For authorized delivery and reply reading, follow protocol.md's reply reception
contract. Browser button changes alone are not proof of successful completion.

## User-action boundary

Give one complete packet for a continuous page task such as Connector creation.
Pause only at a real user/security boundary: login, consent, CAPTCHA, 2FA,
pairing-code entry, DNS, or another explicit confirmation. Report the real
failure and enter the narrow recovery route; never manufacture success.
