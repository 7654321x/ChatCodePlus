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
  Reuse a saved conversation without issuing a bind capability; only a new
  conversation receives a fresh one.
- Preflight confirms OAuth: report `ChatGPT 连接成功。` and immediately return
  setup.md's matching reuse or new-binding INIT.

Reuse established Gateway, URL, connection mode, workspace registration, and
OAuth state. A greeting, manual per-conversation Connector selection, broad UI
inspection, and repeated authorization are recovery measures, not normal setup.
If a browser open is queued, give the direct user path and stop probing.

## User-action boundary

Give one complete packet for a continuous page task such as Connector creation.
Pause only at a real user/security boundary: login, consent, CAPTCHA, 2FA,
pairing-code entry, DNS, or another explicit confirmation. Report the real
failure and enter the narrow recovery route; never manufacture success.
