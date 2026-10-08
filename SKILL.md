---
name: chatcodeplus
description: >
  Use when the user explicitly wants ChatCodePlus or a ChatGPT↔Codex workspace
  connection: connecting or reconnecting ChatGPT to the current Codex workspace,
  using ChatGPT as a remote planning/review brain through ChatCodePlus, resuming
  a ChatCodePlus planning/review loop, or checking or repairing a connection.
  Do not invoke for ordinary local coding, planning, review, debugging, or Git
  tasks that do not involve ChatCodePlus or a ChatGPT workspace connection.
---

# ChatCodePlus

ChatGPT plans and reviews through workspace-scoped MCP tools. Access is
binding- and OAuth scope-gated; direct `write_file`, `edit_file`, `apply_patch`
and `run_command` also require enabled Gateway modes. Codex remains the local
execution harness for delegated work. Use the installed Skill launcher:
Windows `pwsh -NoProfile -File <skill>/scripts/chatcodeplus.ps1`, or macOS/Linux
`sh <skill>/scripts/chatcodeplus.sh`. Pass `-w <workspace>` where required.

## First action — choose one route

| Current situation | Immediate action |
| --- | --- |
| Codex/host creates a capability-bearing INIT for an explicitly selected workspace | After confirmed connection readiness and first-bind/switch authorization, run `<chatcodeplus> bind -w <workspace> --packet` **once** and send the packet unchanged through the authorized host. Do not reconstruct it with a model. |
| ChatGPT receives INIT with `WORKSPACE_BIND_CODE` | Call `workspace_snapshot({"bind_code":"<provided code>"})` (default binding tier), verify `BOUND` and expected workspace, then call `workspace_self_check({})` exactly once. Report both results; no preflight, file reads or commands. |
| ChatGPT receives a no-code `CHECK_BINDING` INIT | Call `workspace_snapshot({})` once; `BOUND` → one `workspace_self_check({})`; `WORKSPACE_NOT_BOUND` → report it to the host, which may issue a fresh code only for an explicitly selected target. |
| Confirmed same-workflow `RESUME`, or `NEW_TASK` after `DONE` | Reuse the confirmed binding; skip preflight, snapshot, capability and self-check. |
| User only asks whether the Gateway/connection is up | Run `<chatcodeplus> status --json` (read-only). Report actual Gateway version, OAuth and Tunnel state; never start, restart, pair or bind as a status-check side effect. |
| User asks to connect or reuse an existing ChatGPT Connector | Run `<chatcodeplus> preflight -w <workspace> --json` once. Follow its `connectionRoute`: `REUSE` → reuse the saved/current conversation and check binding only if unknown; `RECOVERY` → follow its `nextAction`; `FIRST_SETUP` → [setup.md](references/setup.md). |
| Actual disconnection or stale runtime | Read [recovery.md](references/recovery.md): `status --json` first, then `doctor --no-fix --json` only if the cause is unclear. Repair the observed layer once; do not recreate OAuth, binding or Tunnel for a transient failure. |
| User explicitly requests starting a Gateway | Check/install the latest local Skill, then `<chatcodeplus> start -w <workspace> --json`; it reuses an existing healthy Gateway. Add `--tunnel` only when public connection was requested. Verify returned state, not merely exit code. |
| User explicitly requests Gateway restart | Check current installed Skill first, then `<chatcodeplus> restart`; use `--tunnel` only when explicitly establishing the public connection. Verify afterward with `status --json`. Preserve existing modes, sessions, OAuth and bindings. |
| User explicitly requests stopping the Gateway | Run `<chatcodeplus> stop`, not `unpair`. Do not revoke OAuth or clear bindings. |
| User explicitly requests disconnecting/revoking machine authorization | Only then run `<chatcodeplus> unpair` and use [recovery.md](references/recovery.md) for the user-side Connector action. Never unpair to fix a network outage. |

`status` is observation only; `preflight` may start/reuse the Gateway and
register a workspace. `bind --packet` is opt-in; `bind --json` stays unchanged.
Issue a five-minute capability just in time for an authorized first bind/switch,
never from a saved URL or unknown binding alone. Do not repeat checks after a
confirmed RESUME, retry blindly, or claim readiness from process status alone.

## Invariants

- One OS user owns one machine Gateway, state root, and active public endpoint.
  The Gateway lifetime is machine-owned, not Codex-owned: closing or restarting
  Codex must not stop an already-running connection. Windows uses a current-user
  Task Scheduler boundary; macOS/Linux detach the daemon. The Gateway owns
  Named Tunnel recovery and verified readiness; Quick Tunnel URLs never change
  silently. Heavy `run_command` uses a bounded process queue and one monitor
  Worker that never calls GPT or MCP. Request-local progress does not create
  another model round-trip. Logs correlate by opaque `executionId`, without
  command arguments, workspace paths or output; child processes exclude the
  `CHATCODEPLUS_*` control-plane environment. All accessible workspaces are
  registered in that machine state; ChatGPT never selects a filesystem root
  by sending a path or workspace ID.
- One machine may retain multiple OAuth client registrations and token
  generations. Machine Trust is Gateway-level machine trust established by local pairing, not a trusted
  OpenAI account identity; client ID, browser, and token generation are not
  account identity and there is no latest-wins replacement.
- A conversation binding is separate from OAuth and uses the Connector's
  `openai/subject + openai/session` identity. Missing or invalid metadata fails
  closed. A saved URL, browser state, task ID, previous message, or process
  lifetime cache never proves a binding. There is no fallback workspace.
- Runtime state belongs under `~/.chatcodeplus`, never in the Skill or workspace.
  Legacy files are migration-only input and are never a runtime fallback.
- Control messages contain no workspace file content, diffs, logs, raw
  conversation metadata, tokens, cookies, pairing codes, client secrets, or
  credentials. The one-time bind capability is sent only in the protocol INIT,
  just in time, and is never repeated or logged.
- Pairing is machine authorization and happens only when the OAuth page asks.
  Binding is authorized only by a fresh five-minute bind capability or by a
  no-capability `workspace_snapshot()` that proves an existing binding.
- Do not perform login, consent, CAPTCHA, 2FA, Connector edits, pairing entry,
  DNS changes, or other security/user confirmations for the user. Report real
  failures; do not manufacture success.

## Route only the needed reference

| User intent or observed state | Read | Owner |
| --- | --- | --- |
| connect, start, reuse, first setup, OAuth continuation | [setup.md](references/setup.md) | startup and Connector flow |
| coding, planning, review, resume, workspace inspection | [coding.md](references/coding.md) | coding loop and Fast RESUME |
| actual disconnect, binding, OAuth, MCP, or network failure | [recovery.md](references/recovery.md) | classification and minimal repair |
| control messages, binding, MCP/read tiers, reply reception | [protocol.md](references/protocol.md) | wire and binding contract |
| fixed Cloudflare hostname | [named-tunnel.md](references/named-tunnel.md) | Named Tunnel |
| missing runtime or dependency | [bootstrap.md](references/bootstrap.md) | bootstrap |
| explicit update request or explicit available update | [update.md](references/update.md) | update |

Do not preload every reference or reconstruct a route by combining duplicated
Markdown rules. `preflight --json` owns its structured `connectionRoute` and
`nextAction`; setup consumes that result. `protocol.md` is the canonical wire
contract, and `docs/protocol.md` is its source for the generated Skill copy.

## Fast RESUME boundary

Fast RESUME is valid only when the same continuous Codex/host workflow has a
currently confirmed conversation binding and task state `PLAN`, `EXECUTING`,
`EXECUTED`, or `REVIEW`. The confirmation must come from a successful
`workspace_snapshot()` or a later verified MCP invocation in that same
workflow. A restart, new process, reopened saved conversation, or changed
interaction environment resets `bindingState` to `UNKNOWN`; perform the
lightweight binding-only snapshot. `WORKSPACE_NOT_BOUND` enters normal binding
recovery. Tool unavailability or authorization failure enters `RECOVERY`.

The detailed decision and control-message formats live in [coding.md](references/coding.md)
and [protocol.md](references/protocol.md). Fast RESUME does not run preflight,
repeat a snapshot, issue INIT, or create a capability. `NEW_TASK` is separate:
it is a no-capability INIT with no capability field and requires an explicit
new task after `DONE` in the same confirmed binding.

## Workspace tool policy

For a new or unknown conversation, request the default binding-only
`workspace_snapshot()` first. It must not become a directory tree, Git status,
or execution-history scan merely for confirmation. After a successful INIT
binding or binding check, call `workspace_self_check` exactly once before
reporting readiness. That self-check is read-only: it performs a bounded root
directory probe plus authorized Git/execution reads, and reports search/write/
command availability from OAuth scopes and Gateway modes without writing files
or launching commands. Confirmed `RESUME` and `NEW_TASK` do not repeat either
check. Request `workspace_snapshot({"detail":"overview"})` only when broad
project context is needed; use `detail:"full"` only for the explicit combined
legacy view. For specific evidence, page `list_directory`, `read_file`,
`search_workspace`, `git_status`, or `git_diff` instead. `write_file`, `edit_file`, `apply_patch`, and `run_command` keep a stable
public tool schema. When `writeMode: workspace` is active and the token has
`workspace.write`, the write tools may modify non-protected paths in the bound
workspace using their optimistic-concurrency checks. Prefer `edit_file` for one exact replacement, `apply_patch` for multiple exact replacements in one existing file,
and `write_file` for file creation or an intentional whole-file rewrite.
Existing files handled by mutation tools must be bounded valid UTF-8 text; patch
matching is exact-only and never fuzzy. A fresh Gateway `start`
defaults to `writeMode: workspace` and full command mode, while a plain `restart`
preserves the live modes; `--no-write` and `--no-execute` are explicit opt-outs,
and `--execute safe` selects the validation allowlist. Disabled modes return a
stable disabled result instead of removing the tool. Full mode starts local processes from the
bound workspace with the OS user's permissions and is not an interactive shell
or a filesystem sandbox. Command execution requires the separate
`workspace.execute` authorization scope. New authorization requests include the
independent write and execute scopes; an older token missing either required
scope must reauthorize and is never silently expanded.

## Browser and user boundaries

Browser Ready is a best-effort host capability, not a production CLI/browser
pipeline. Reuse `READY`, open once on `NOT_READY`, and warn on `UNKNOWN`;
none prove a binding. See [coding.md](references/coding.md).

Give one complete user-action packet. Pause at login, consent, CAPTCHA, 2FA,
pairing entry, DNS or explicit confirmation boundaries. For substantial work,
report meaningful stages in the user's language; issue a short liveness update
around 45–60 seconds when possible. Do not create another GPT round-trip
merely to emit progress.
