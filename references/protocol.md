# ChatCodePlus protocol

OAuth authorizes one ChatGPT Connector to the machine Gateway. It does not
select a workspace. Each authenticated ChatGPT conversation is separately and
persistently bound to one locally registered workspace.

## Binding

Conversation bindings are persistent `conversationKey → workspaceId` records
with `createdAt` and `updatedAt`. `createdAt` is the first time the
conversation key was bound; `updatedAt` is the most recent successful fresh
bind, rebind, or same-workspace reconfirmation. Ordinary snapshot/read/list/
search operations never update either authorization timestamp.
Multiple conversations may bind to the same workspace. A saved session URL is
not an authorization source and does not limit the workspace to one
conversation.

The binding store is the canonical source. With no bind code,
`workspace_snapshot()` only reuses the current binding and returns
`WORKSPACE_NOT_BOUND` when none exists. A caller that has selected a target
workspace may instead issue a fresh CSPRNG, five-minute, single-use capability
just in time and send it directly in a capability-bearing INIT. The receiver's
first operation is:

```text
workspace_snapshot({"bind_code":"XXXX-XXXX"})
```

The Gateway validates and reserves the capability, resolves its registered
workspace, atomically creates or replaces the conversation binding, and only
then consumes the capability and returns the snapshot. A valid capability is
therefore explicit authorization to create a first binding, confirm the same
workspace idempotently, or switch to its target workspace. A persistence
failure leaves the old binding intact and releases the capability. It stores
only a SHA-256 conversation key, workspace ID, `createdAt`, and `updatedAt`.
Missing conversation
metadata, unknown workspace, or missing/expired/consumed capability returns a
specific failure with no fallback workspace. Later snapshots and normal reuse
omit the code. Gateway, Codex, machine, or Tunnel restarts do not invalidate
persisted bindings.

`WORKSPACE_ALREADY_BOUND` and `CONVERSATION_ALREADY_BOUND` remain strict
low-level error codes for callers of the non-replacing
`ConversationBindingStore.bind()` API; they are not the normal result of a
capability-bearing `workspace_snapshot`.

`WORKSPACE_NOT_BOUND` proves Connector/OAuth reachability, not OAuth failure.
The public Connector exposes nine tools; `workspace_snapshot` owns optional
`bind_code` and there is no separate binding tool.

## Machine OAuth authority

The machine auth store may retain multiple dynamic client registrations, but it
has at most one current authorization generation. The latest successful
authorization-code exchange becomes current only after its complete token
state is atomically persisted. That persistence replaces the previous
generation's token authority, so its access and refresh tokens are no longer
accepted. If the exchange or persistence fails, the previous authorization
remains usable and the new token response is not returned.

Refresh-token rotation is a separate transaction within the current
authorization. It consumes one refresh token and atomically persists its
replacement pair without activating a new authorization generation. A failed
refresh persistence leaves the old refresh token usable. The generation is an
opaque machine transaction identifier; ChatCodePlus does not receive a trusted
OpenAI account identity and must not infer one.

## Message readiness routing

`checkMessageReadiness()` is a local, pure routing classifier. It consumes only
facts already observed from the Gateway, OAuth, workspace, and current binding
path; it does not perform a snapshot, retain conversation data, or generate a
capability.

- `BOUND` plus active `PLAN`, `EXECUTING`, `EXECUTED`, or `REVIEW` routes to
  `RESUME`. `EXECUTED → REVIEW` keeps the existing task ID and execution record;
  it never adds preflight, a binding check, INIT, or a capability.
- INIT is not synonymous with capability issuance. Its local `initPurpose`
  distinguishes the following decisions (not new wire-protocol fields):

  | Binding | Task / intent | Route | initPurpose |
  | --- | --- | --- | --- |
  | UNKNOWN | Check current binding | INIT | CHECK_BINDING |
  | NOT_BOUND | Explicit WORKSPACE_NOT_BOUND | INIT | BIND_WORKSPACE |
  | BOUND | DONE + newTaskRequested | INIT | NEW_TASK |

  Only `BIND_WORKSPACE` may request a fresh just-in-time capability. The
  `WORKSPACE_NOT_BOUND` result is still the no-capability route's proof that
  the current conversation needs one, but it is not a prerequisite when the
  caller already has an explicit target workspace and a fresh capability.
  CHECK_BINDING and NEW_TASK omit the code entirely. A NEW_TASK uses a new
  unique task ID and iteration zero; it does not resume the completed task.
  DONE alone does not authorize another task. Runtime prerequisites must be
  ready for all three.
- Gateway, OAuth, workspace, or binding failure routes to `RECOVERY` with no
  INIT.
- Unknown runtime prerequisites or missing task intent route to `BLOCKED`.
  Unknown binding alone allows a no-capability check, not a guessed binding.

Message readiness determines message routing only. `workspace_snapshot()` and
the Gateway binding store remain the canonical binding source.

The readiness/resume helpers currently have only test callers, not a production
host entry point. The Skill executor follows this contract with observed facts;
the CLI does not invoke these helpers or automate message delivery.

## Saved workspace session

The CLI stores one preferred/latest ChatGPT conversation URL per workspace.
Only HTTPS `/c/<conversation>` URLs on the approved ChatGPT hosts
`chatgpt.com` and `chat.openai.com` are accepted. Query strings, fragments,
host case, and meaningless trailing slashes are removed before comparison and
storage. Updating the same canonical URL may preserve unspecified title, task,
iteration, and last-state metadata. Setting a different URL replaces the
preferred session; only metadata explicitly supplied with that command is
stored, so the old conversation's title and task state are not inherited.
Session metadata is strictly validated, including non-negative integer
iterations and known protocol states. Invalid input is rejected before writing.
If the existing session file is corrupt or schema-invalid, preflight treats it
as absent, reports a warning, and leaves the file untouched; it does not treat
the session as OAuth or workspace authority. The replacement is atomic, and a
failed write leaves the previous session intact.

## Browser readiness

Browser readiness is a host-only environment action before a control message:
for one continuous workflow, check once and reuse `READY`; on `NOT_READY`,
request one open of `https://chatgpt.com/`; on `UNKNOWN`, warn and continue the
selected route. Recheck only on direct host/browser invalidation or an explicit
interaction-environment switch. The temporary readiness context does not retain
a browser session, conversation ID, URL, or binding timestamp. It does not poll, wait for
page rendering, retain a browser session, or determine workspace binding.
The repository's injected browser helper has no production host adapter; use
only actual available host tools, and report unavailable capability honestly.

For a currently confirmed active binding, browser preparation followed by the
`RESUME` route continues collaboration without preflight, a snapshot, INIT, or
a bind capability. A new or revalidated conversation follows the existing
binding route; browser readiness is never a substitute for its snapshot.

## Control messages

Messages begin `[CHATCODEPLUS]`, remain under 1 KB, and contain no files, diffs,
logs, secrets, credentials, tokens, cookies, or raw conversation metadata.

```text
INIT → PLAN → EXECUTING → EXECUTED → REVIEW
     → (PLAN | DONE | BLOCKED | ERROR)

RESUME → (PLAN | EXECUTING | REVIEW)
```

New-binding INIT contains `STATE`, unique `TASK_ID`, `ITERATION: 0`, the one-time
bind code, `GOAL`, and `INSTRUCTION`. Do not repeat the code later:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<unique>
ITERATION: 0
WORKSPACE_BIND_CODE: <fresh code>

GOAL:
Bind this ChatGPT conversation to the current workspace.

INSTRUCTION:
Call workspace_snapshot with the provided bind code and verify the workspace.
```

No-capability binding-check INIT omits `WORKSPACE_BIND_CODE` and never invents
an empty or fake field. It is valid for a saved or newly opened conversation
whose binding is unknown, before any WORKSPACE_NOT_BOUND response:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<unique>
ITERATION: 0

GOAL:
Check whether this ChatGPT conversation already has a workspace binding.

INSTRUCTION:
Call workspace_snapshot without a bind code, verify the returned workspace,
and continue using the existing binding. If it returns WORKSPACE_NOT_BOUND,
report that exact result and stop so Codex can issue one fresh capability.
```

No-capability new-task INIT is distinct from the binding-check INIT. After DONE,
when the user requests another task and the same conversation/workspace binding
remains confirmed, send:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<new unique id>
ITERATION: 0

GOAL:
<new user-requested task>

INSTRUCTION:
Use the current confirmed workspace binding and return a plan for this new task.
Do not repeat a binding check or resume the completed task.
```

This NEW_TASK path does not run preflight or issue a capability. If the
conversation or workspace changed, binding is no longer confirmed: use the
normal no-capability check path instead.

`RESUME` continues the same currently confirmed conversation during `PLAN`,
`EXECUTING`, `EXECUTED`, or `REVIEW`. It omits `WORKSPACE_BIND_CODE` and never calls for a
new snapshot, INIT, preflight, or binding check:

```text
[CHATCODEPLUS]
STATE: RESUME
TASK_ID: <existing task id>
ITERATION: <current iteration>

REQUEST:
<compact continuation or review question>
```

`RESUME` does not create a conversation session, cache a raw conversation ID,
or authorize message delivery. It is valid only while the current conversation
and workspace remain confirmed. A new conversation, workspace change,
`WORKSPACE_NOT_BOUND`, or binding failure exits this shortcut and follows the
existing setup/recovery flow.

PLAN contains the goal, rationale, finite actions, likely files, tests, and
success criteria. EXECUTED contains only result metadata, changed-file count,
and the real test summary after Codex records the iteration locally. REVIEW asks
ChatGPT to inspect current workspace/diff through MCP. DONE summarizes success;
BLOCKED preserves the real reason and required user decision.

## Reply reception (host boundary)

Sending requires user authorization or a separately authorized host action.
Before sending, identify the target conversation and the existing reply boundary
using available host tools. Track only this in-flight request in temporary
context. Read only the new assistant reply belonging to that request, checking
TASK_ID/iteration when present. Do not use a previous reply/action bar, prompt
echo, quoted example, or unrelated tab as the result. If concurrent messages
make attribution unclear, report unavailable attribution rather than guessing.

Completion outcomes describe reception, not binding or task success:

- `COMPLETED`: the corresponding new reply has finished according to a verified
  host completion signal, and its final content is readable. Inspect its actual
  PLAN/REVIEW/DONE/BLOCKED/ERROR result before advancing the task.
- `INTERRUPTED`: the host reports cancellation, generation failure, or navigation
  interrupting this request. Partial text is not a completed reply.
- `TIMEOUT`: the bounded wait expires without confirmed completion. Keep the
  pending task; do not automatically resend, reinitialize, or generate a code.
- `UNAVAILABLE`: no supported observation/read capability, inaccessible target,
  or no reliable way to attribute/confirm the reply. Request the corresponding
  reply from the user instead of claiming completion.

Never click stop, regenerate, copy, rating, or other reply controls to detect
completion. Stop-button disappearance plus a new reply action area are candidate
signals only: the two manual UI observations did not validate an event listener,
debounce, cancellation handling, or a reliable completion detector. There is no
verified host event adapter or implemented reply observer in this package. Do
not invent MutationObserver/host APIs or claim event-driven completion support.
If a host exposes a documented completion/wait facility, use it within a bounded
wait; otherwise report that detection is unavailable. Do not persist reply text,
browser sessions, conversation IDs, or completion timestamps. Reception failure
never proves WORKSPACE_NOT_BOUND and must not trigger binding recovery by itself.

## Ownership

ChatGPT may inspect only the bound workspace through read-only MCP tools. Codex
owns all edits, commands, tests, Git operations, and recovery. A saved
conversation URL is default/last-used routing metadata, not the binding store
or an authorization source. A replacement conversation may receive a fresh
capability directly once Codex has selected its target workspace; a no-code
binding check remains the strict reuse path when no capability is available.
