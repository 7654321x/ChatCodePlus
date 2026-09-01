# ChatCodePlus protocol

OAuth authorizes one ChatGPT Connector to the machine Gateway. It does not
select a workspace. Each authenticated ChatGPT conversation is separately and
persistently bound to one locally registered workspace.

## Binding

Conversation bindings are persistent `conversationKey → workspaceId` records.
Multiple conversations may bind to the same workspace, while one conversation
cannot switch to another workspace implicitly. A saved session URL is not an
authorization source and does not limit the workspace to one conversation.

For a new conversation, preflight issues a CSPRNG, five-minute, single-use
capability because no saved conversation exists. For an existing conversation
whose binding is explicitly missing, `<chatcodeplus> bind -w <workspace>
--json` issues the same capability just in time. New-binding INIT carries it as
`WORKSPACE_BIND_CODE`; the receiver's first operation is:

```text
workspace_snapshot({"bind_code":"XXXX-XXXX"})
```

The Gateway consumes the capability and returns the snapshot atomically. It
stores only a SHA-256 conversation key and workspace ID. Missing conversation
metadata, unknown workspace, missing/expired/consumed capability, or attempted
rebind returns a specific failure with no fallback workspace. Later snapshots
and all normal reuse omit the code. Gateway, Codex, machine, or Tunnel restarts
do not invalidate persisted bindings.

An already-bound conversation that supplies any bind capability receives
`WORKSPACE_ALREADY_BOUND`; the capability is neither inspected nor consumed and
remains available to its intended unbound conversation.

`WORKSPACE_NOT_BOUND` proves Connector/OAuth reachability, not OAuth failure.
The public Connector exposes nine tools; `workspace_snapshot` owns optional
`bind_code` and there is no separate binding tool.

## Control messages

Messages begin `[CHATCODEPLUS]`, remain under 1 KB, and contain no files, diffs,
logs, secrets, credentials, tokens, cookies, or raw conversation metadata.

```text
INIT → PLAN → EXECUTING → EXECUTED → REVIEW
     → (PLAN | DONE | BLOCKED | ERROR)
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

Reuse INIT omits `WORKSPACE_BIND_CODE` and never invents an empty or fake field:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<unique>
ITERATION: 0

GOAL:
Reuse this ChatGPT conversation with its existing workspace binding.

INSTRUCTION:
Call workspace_snapshot without a bind code, verify the returned workspace,
and continue using the existing binding.
```

PLAN contains the goal, rationale, finite actions, likely files, tests, and
success criteria. EXECUTED contains only result metadata, changed-file count,
and the real test summary after Codex records the iteration locally. REVIEW asks
ChatGPT to inspect current workspace/diff through MCP. DONE summarizes success;
BLOCKED preserves the real reason and required user decision.

## Ownership

ChatGPT may inspect only the bound workspace through read-only MCP tools. Codex
owns all edits, commands, tests, Git operations, and recovery. A saved
conversation URL is default/last-used routing metadata, not the binding store
or an authorization source; replacement conversations require a fresh
capability and compact handoff.
