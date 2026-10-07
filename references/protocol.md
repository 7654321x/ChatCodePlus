<!-- GENERATED FILE
Canonical source: docs/protocol.md
Do not edit this copy directly.
Run pnpm build:skill after changing the canonical source.
-->
# ChatCodePlus protocol

This file is the canonical source for the generated
`ChatCodePlus/references/protocol.md` copy. Change this file, then run
`pnpm build:skill`; do not edit the generated copy directly.

OAuth authorizes a ChatGPT Connector to the machine Gateway. It does not select
a workspace. Each authenticated conversation is separately bound to one
locally registered workspace.

## Conversation binding

The binding store is the canonical source of `conversationKey → workspaceId`
records. A key is derived from the Connector-provided
`openai/subject + "\0" + openai/session`; raw values are never persisted or
logged. Both metadata fields are required. Each record keeps `createdAt` for
the first bind and `updatedAt` for the latest successful fresh bind, rebind, or
reconfirmation. Ordinary reads never update either timestamp.

Multiple conversations may bind to the same workspace. A saved session URL is
routing metadata, not an authorization source. Gateway, Codex, machine, and
Tunnel restarts do not invalidate a binding. Older session-only keys may be
migrated once to the principal-aware key, preserving the workspace and
timestamps; they are never a runtime fallback.

With no bind code, `workspace_snapshot()` only reuses the current binding and
returns `WORKSPACE_NOT_BOUND` when none exists. A caller with an explicitly
selected target workspace may issue a fresh CSPRNG, five-minute, single-use
capability just in time. The first operation is:

```text
workspace_snapshot({"bind_code":"XXXX-XXXX"})
```

The Gateway validates and reserves the capability, resolves its registered
workspace, atomically creates or replaces the binding, then consumes the code
and returns the snapshot. A persistence failure leaves the previous binding
intact and releases the capability. Missing conversation metadata, an unknown
workspace, or a missing, expired, or consumed capability fails closed. There is
no workspace path, workspace ID, or active-workspace selector accepted from
ChatGPT and no fallback workspace.

`WORKSPACE_ALREADY_BOUND` and `CONVERSATION_ALREADY_BOUND` remain strict
low-level results of the non-replacing store API. They are not the normal
result of capability-bearing `workspace_snapshot`. `WORKSPACE_NOT_BOUND`
proves Connector/OAuth reachability, not OAuth failure.

## Workspace read tiers

Binding is resolved before any read-only context is returned. `detail` changes
only the amount of context after that resolution:

- `workspace_snapshot()` or `workspace_snapshot({"detail":"binding"})` returns
  workspace identity, root alias, and binding status. It does not scan a tree,
  inspect Git, detect the project, or read execution history.
- `workspace_snapshot({"detail":"overview"})` adds project metadata, a
  top-level directory page, count-only Git summary, and the latest test
  summary. It does not return changed-file lists.
- `workspace_snapshot({"detail":"full"})` explicitly requests the expanded
  legacy view and should be used only when that combined payload is needed.

After a binding-only result, request `overview` only for broad context;
otherwise use `list_directory`, `read_file`, `search_workspace`, `git_status`,
or `git_diff` for specific evidence. `RESUME` and `NEW_TASK` do not repeat a
snapshot. Directory and file pagination is bounded; sizes and exact total
line counts are opt-in.

MCP responses may contain bounded local performance telemetry with only tool
name, duration, response bytes, result count, engine, and truncation state.
Queries, paths, workspace roots, file/diff content, metadata, credentials, and
tokens are excluded.

## Workspace write feedback

The Gateway always advertises `write_file`, `edit_file`, and `apply_patch`
with a stable schema. `edit_file` performs one exact replacement; `apply_patch`
performs 1-64 ordered exact replacements in one existing file and validates the
entire in-memory result before one file commit. Neither tool performs fuzzy
matching. Existing-file mutation snapshots are limited to 8 MiB, reject NUL
binary content and malformed UTF-8, and use the SHA-256 of the current raw bytes
for optimistic conflict protection. `write_file` remains the create/intentional
whole-file replacement surface. When `writeMode: workspace` permits a call,
callers may request progress with the standard MCP `_meta.progressToken`. Those calls receive request-scoped
`notifications/progress` over their POST response stream for real file-operation
stages: checking the file, saving the change, verifying the saved content, then
completion or failure. Unchanged content is reported without claiming a write
occurred. The increasing progress value counts stages, not a percentage or an
ETA. Messages contain no file content, paths, hashes, or conversation metadata.

Calls without a progress token retain the normal JSON response. No background
stream or session is created. Delivery failure disables further progress for
that call, logs one diagnostic, and does not change the write outcome. The final
tool result remains authoritative; hash verification does not mean tests ran.

For a token-bearing write/edit/patch request that remains in one stage for 45 seconds,
the Gateway sends a request-scoped liveness heartbeat, then repeats it at the
same interval while that stage continues. Before the first real stage it uses a
neutral message; afterward it names only the current stage. A real stage change
resets the interval. Heartbeats are not queued business work, percentage, ETA,
or evidence that the file changed. They stop when the operation reaches its
terminal result or progress delivery becomes unavailable. A host may use them
to keep its current activity indicator alive; they are not separate chat
messages and do not mean the overall task is complete.

Protocol progress is intentionally short and mechanical so a capable host can
render an activity indicator or compact status UI. Chat progress is separate:
MCP server instructions and write tool descriptions ask the assistant to explain
intended edits, summarize actual saves between meaningful batches, and surface
important findings or failures promptly. A completed `write_file`, `edit_file`,
or `apply_patch` means only that one file operation completed; it must not be presented as overall
task completion while planned edits, tests, Git review, runtime synchronization,
or final verification still remain. These chat updates remain useful when the
web client does not request or display protocol progress. The Gateway cannot
force the client to render notifications or the assistant to produce
intermediate prose.

## Workspace command execution

Command execution is a separate capability from file writes. A fresh machine
Gateway defaults to `writeMode: workspace` and `commandMode: full`. `--execute safe`
selects the validation allowlist, a live Gateway preserves its current modes across
a plain restart, and `--no-write` / `--no-execute` explicitly select the disabled
modes. Unknown `--execute` values are rejected rather than promoted to full.
`write_file`, `edit_file`, `apply_patch`, and `run_command` remain registered in every mode so a
host-cached tool schema cannot become stale after a lifecycle change. Disabled
modes return `WORKSPACE_WRITE_DISABLED` or `WORKSPACE_EXECUTION_DISABLED` before
scope, binding, or use-case dispatch.

New default OAuth requests include the independent `workspace.write` and
`workspace.execute` scopes. Existing tokens are never expanded silently and must
reauthorize if they do not already carry the required scope. Holding
`workspace.write` never grants command execution.
The tool advertises its separate OAuth scope. If an existing token lacks it,
`run_command` returns an `insufficient_scope` MCP authorization challenge so the
host can request incremental authorization; Machine Trust skips local pairing,
but the host may still ask the user to approve the added permission.

`run_command` accepts an executable command plus argument array,
workspace-relative optional working directory, and bounded timeout. Safe and
full modes intentionally advertise the same stable input schema so a host that
caches tool definitions cannot accidentally narrow full mode after a mode
switch; the server-side `CommandPolicy` remains authoritative. The tool does not
accept a raw shell string, interactive shell, pipes, or redirects.
In full mode, commands start with the bound workspace as their working directory
but inherit the OS user's permissions and may access resources outside that
workspace; full mode is not a filesystem sandbox. Safe mode is limited to
validation-oriented package scripts and test runners such as test, typecheck,
build, lint, check, verify, pytest, and validation scripts under `scripts/`.
Tests and builds execute repository code, so this remains an explicit local
code-execution permission.

Each invocation is request-local: there is no persistent shell or terminal
session. Processes run with stdin closed and visible terminal windows disabled.
They inherit the OS user's normal environment after the reserved
`CHATCODEPLUS_*` control-plane namespace is removed, so Gateway state paths,
launch metadata, and diagnostic toggles are not exposed to workspace code.
Heavy command execution is globally bounded to one active child-process tree
with at most four FIFO waiters. Queue wait is separately bounded to the lesser
of 120 seconds or the requested command timeout. MCP request cancellation
removes queued work before it starts or terminates the active process tree.
Timeout handling independently terminates the spawned process tree. Stdout and
stderr are bounded independently to 64 KiB; oversized output preserves useful
beginning and tail content and reports truncation instead of streaming unbounded
logs back to the model.

Every accepted `run_command` is registered with the Gateway-owned command
monitor even when the host did not request progress. The monitor receives only
throttled lifecycle/activity metadata and never command output, workspace paths,
or model traffic. When a standard MCP `_meta.progressToken` is present, the
current request may render those monitor events directly: an immediate submitted
message, a first liveness status after about 10 seconds, normal summaries about
every 30 seconds, an early QUIET transition after roughly 20 seconds without
stdout/stderr activity, an immediate RESUMED transition when output returns, and
a lower-frequency roughly 60-second heartbeat after three minutes. The final
completed, failed, timed-out, or cancelled notification terminates that request's
progress stream. Calls without a progress token retain the same monitoring and
normal JSON result but emit no progress notification. Progress never creates a
second ChatGPT planning/review round-trip.

## Message readiness and Fast RESUME

`checkMessageReadiness()` is a pure classifier of facts already observed by
Gateway/OAuth/workspace/binding owners. It performs no I/O and stores no
conversation, URL, browser, timestamp, or binding data.

The only INIT purposes are local routing details, not new wire fields:

| Binding | Task or intent | Route | initPurpose |
| --- | --- | --- | --- |
| UNKNOWN | check current binding | INIT | CHECK_BINDING |
| NOT_BOUND | explicit `WORKSPACE_NOT_BOUND` | INIT | BIND_WORKSPACE |
| BOUND | `DONE` plus explicit new task | INIT | NEW_TASK |

Only `BIND_WORKSPACE` may carry or request a fresh bind capability. A
no-capability `CHECK_BINDING` omits `WORKSPACE_BIND_CODE`; `NEW_TASK` also
omits it and never resumes a completed task. Gateway, OAuth, workspace, or
binding failure routes to `RECOVERY` with no INIT. Unknown prerequisites route
to `BLOCKED`; unknown binding alone permits `CHECK_BINDING` when the other
prerequisites are ready.

Fast RESUME is valid only inside the same continuous Codex/host workflow when
the current conversation binding was confirmed in that workflow by a
successful `workspace_snapshot()` or a later verified MCP invocation. The
task state must be `PLAN`, `EXECUTING`, `EXECUTED`, or `REVIEW`. A saved URL,
`lastState`, task ID, browser READY result, previous control message, or an
earlier process lifetime cache is not proof. A restart, new process, reopened
saved conversation, or changed interaction environment resets binding state to
`UNKNOWN` and requires the lightweight binding-only snapshot. Its outcomes are:

- success: keep the confirmed binding and use `RESUME`;
- `WORKSPACE_NOT_BOUND`: use normal binding recovery;
- tool unavailable or authorization failure: use `RECOVERY`.

`RESUME` never runs preflight, repeats a snapshot, issues INIT, or creates a
capability. It keeps the task ID and is a message shortcut, not a persisted
conversation cache or delivery authorization.

## Control messages

Messages begin `[CHATCODEPLUS]`, stay under 1 KB, and contain no workspace
files, diffs, logs, raw conversation metadata, tokens, cookies, credentials,
or secrets. `WORKSPACE_BIND_CODE` is sent once, only in a capability-bearing
INIT, and is never repeated or logged.

The normal task loop is:

```text
INIT → PLAN → EXECUTING → EXECUTED → REVIEW → (PLAN | DONE | BLOCKED)
RESUME → (PLAN | EXECUTING | REVIEW)
```

Capability-bearing first binding or explicit workspace switch:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<unique>
ITERATION: 0
WORKSPACE_BIND_CODE: <fresh code>

GOAL:
Bind this ChatGPT conversation to the selected ChatCodePlus workspace.

INSTRUCTION:
Call workspace_snapshot with the provided bind code and verify the returned workspace.
After it returns BOUND, call workspace_self_check once. Confirm binding only after
reporting the self-check status; do not write files or launch commands as part of it.
```

No-capability binding check:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<unique>
ITERATION: 0

GOAL:
Check whether this ChatGPT conversation already has a workspace binding.

INSTRUCTION:
Call workspace_snapshot without a bind code. If it returns WORKSPACE_NOT_BOUND,
report that exact result so Codex can issue one fresh capability. If it returns
BOUND, call workspace_self_check once and report both the binding and self-check status.
```

No-capability new task after `DONE`:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<new unique id>
ITERATION: 0

GOAL:
<new user-requested task>

INSTRUCTION:
Use the current confirmed workspace binding. Do not repeat a binding check or
resume the completed task.
```

Fast RESUME:

```text
[CHATCODEPLUS]
STATE: RESUME
TASK_ID: <existing task id>
ITERATION: <current iteration>

REQUEST:
<compact continuation or review question>
```

`PLAN` contains the goal, rationale, finite actions, likely files, tests, and
success criteria. `EXECUTED` contains only result metadata, changed-file
count, and the real test summary after Codex records the iteration locally.
`REVIEW` asks ChatGPT to inspect current workspace state through MCP.

## Reply reception boundary

Sending requires user authorization or a separately authorized host action.
Read only the new assistant reply belonging to that request and verify the
task ID/iteration when present. Do not use a prompt echo, old reply, unrelated
tab, or action-bar state as completion evidence.

Reception outcomes describe host observation, not binding or task success:

- `COMPLETED`: a verified new reply finished and its final result is readable;
- `INTERRUPTED`: cancellation, generation failure, or navigation interrupted it;
- `TIMEOUT`: bounded wait ended without confirmed completion; do not resend;
- `UNAVAILABLE`: no reliable observation or attribution is available.

There is no production reply observer in this package. Do not invent host APIs,
polling, or browser controls. Reception failure never proves
`WORKSPACE_NOT_BOUND` and must not trigger binding recovery by itself.

## Ownership

ChatGPT may invoke MCP tools only within the active Gateway mode, OAuth scopes,
and bound workspace. Tool definitions remain stable; runtime modes authorize or
reject execution rather than adding or removing definitions. Read tools remain
workspace-bound; `workspace.write` authorizes protected `write_file` / `edit_file` /
`apply_patch` calls in workspace mode, and `workspace.execute` authorizes
`run_command` in safe
or full mode. Codex remains the local execution harness for delegated work, Git
flows, and recovery. The Gateway owns OAuth transport, workspace registration,
tool-mode enforcement, and conversation binding. The Skill owns routing and
user-action boundaries; it does not create a second state store or an implicit
browser/conversation adapter.
