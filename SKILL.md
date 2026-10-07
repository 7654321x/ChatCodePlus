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

ChatGPT plans and reviews through workspace-scoped MCP tools. Read access is
always binding- and scope-gated; write and command tools are exposed only when
the active Gateway mode enables them and the OAuth token carries the matching
scope. Codex remains the local execution harness for delegated work, but when
`write_file`, `edit_file`, `apply_patch`, or `run_command` are exposed ChatGPT may use those
tools directly within their documented boundaries. Use only this package's
launcher: Windows `pwsh -NoProfile -File <skill>/scripts/chatcodeplus.ps1`;
macOS/Linux `sh <skill>/scripts/chatcodeplus.sh`. Pass `-w <workspace>` to
workspace commands.

## Invariants

- One OS user owns one machine Gateway, state root, and active public endpoint.
  The Gateway lifetime is machine-owned, not Codex-owned: closing or restarting
  Codex must not stop an already-running connection. The packaged Windows Skill
  launches the Gateway through a current-user Task Scheduler boundary so it does
  not remain inside the Codex host process tree; macOS/Linux use a detached daemon.
  Runtime diagnostics distinguish the immutable launch method from the current
  Windows task-registration presence; the latter is a cached health observation,
  not proof of how the already-running Gateway was originally launched.
  Once a fixed Named Tunnel is enabled, the Gateway supervises its public health
  and automatically restores sustained disconnects with bounded backoff; an
  explicit tunnel stop disables recovery. Quick Tunnels are not silently
  auto-restarted because their public URL changes. Long `run_command` work uses
  one lazy Gateway-owned monitor Worker Thread only for task-state timing; it
  never runs commands, reads workspace data, calls MCP, or requests GPT. The
  Gateway thread renders its status directly through the current request's MCP
  progress channel when available; monitoring itself still runs without a
  progress token. Heavy commands are limited to one active child-process tree
  with at most four FIFO waiters. Queue wait is bounded to the lesser of 120
  seconds or the requested command timeout, and MCP cancellation removes queued
  work or terminates the active process tree. The command path is correlated by one opaque
  `executionId` across dispatch, queue, process, and monitor lifecycle logs;
  those logs keep diagnostic metadata only and never copy command arguments,
  workspace paths, stdout, or stderr content. Workspace child processes inherit
  the user's normal environment with the `CHATCODEPLUS_*` control-plane
  namespace removed before spawn.
  All accessible workspaces are explicitly registered in that machine state;
  ChatGPT never selects a filesystem root by sending a path or workspace ID.
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

Browser Ready is a host capability contract, not a production TypeScript or
CLI pipeline: when available, make one lightweight readiness preparation per
continuous workflow, reuse `READY`, request one open on `NOT_READY`, and warn
and continue on `UNKNOWN`. It never proves or changes conversation binding;
the host may be unable to provide it. Details belong to `coding.md`.

Give one complete user-action packet for a continuous page task. Pause only at
login, consent, CAPTCHA, 2FA, pairing-code entry, DNS, or another explicit
security/confirmation boundary. For substantial multi-step workspace work,
use concise progress in the user's current language at meaningful stage changes,
important findings or failures, and final verification. Batch routine tool calls
silently; if work continues for roughly 45–60 seconds without a visible update,
send one short liveness update when possible. Never start another ChatGPT
planning/review round-trip merely to report progress.
