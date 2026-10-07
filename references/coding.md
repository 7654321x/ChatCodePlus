# Coding, planning, and review

ChatGPT plans and reviews through workspace-scoped MCP tools. Read tools are
always binding- and scope-gated. When the active Gateway exposes
`write_file` / `edit_file` / `apply_patch` or `run_command`, ChatGPT may use them directly
within the current `writeMode`, `commandMode`, workspace boundary, and OAuth
scopes. Codex remains the local execution harness for delegated work, Git flows,
and recovery. Startup and OAuth continuation are owned by
[setup.md](setup.md); wire and binding semantics are canonical in
[protocol.md](protocol.md).

## Fast RESUME contract

Before preflight, binding preparation, or INIT, check whether this is the same
continuous Codex/host workflow and the current conversation binding was truly
confirmed during that workflow. Confirmation must be a successful
`workspace_snapshot()` or a later verified MCP invocation. The task must be
`PLAN`, `EXECUTING`, `EXECUTED`, or `REVIEW`.

Only that combination permits `RESUME`. A saved URL, `lastState`, task ID,
browser `READY`, previous control message, or earlier process lifetime cache
is not binding proof. A restart, new process, reopened saved conversation, or
changed interaction environment sets `bindingState=UNKNOWN`; perform one
lightweight binding-only `workspace_snapshot()`.

The result controls the next route:

- successful snapshot or verified invocation: retain the confirmed binding and
  use `RESUME` for the active task;
- `WORKSPACE_NOT_BOUND`: leave Fast RESUME and use normal binding recovery;
- tool unavailable or authorization failure: use `RECOVERY`;
- missing runtime or task facts: use `BLOCKED` rather than guessing.

Fast RESUME does not run preflight, repeat a snapshot, issue INIT, or create a
capability. It keeps the existing task ID and uses the `RESUME` format in
`protocol.md`. After `DONE`, an explicit new task is a separate no-capability
`NEW_TASK` INIT; it is not a resume and does not carry a bind capability.

`src/conversation/readiness.ts` and `src/conversation/resume-resolver.ts` are the
machine-checkable projection of the rule set above and of
[protocol.md](protocol.md), which stays the single owner of the rules the
Connector follows. They are pure classifiers of already observed facts: they do
not query MCP, persist conversation data, or automate host delivery, and no
Gateway process path calls them. `tests/docs-contract.test.ts` compares the
projection with the canonical protocol rule table on every run, so changing a
rule in one place without the other fails the test;
`tests/conversation-readiness.test.ts` and
`tests/conversation-resume-resolver.test.ts` pin the classifier and presentation
behavior. The production routing rule is unchanged and belongs to the Gateway:
the conversation binding key is `sha256(openai/subject + "\0" + openai/session)`.

## Preflight and binding entry

Only after Fast RESUME is ruled out, run
`<chatcodeplus> preflight -w <workspace> --json` once for a new or revalidated
conversation. It confirms Gateway/OAuth/workspace readiness and consumes its
structured route; it never infers a binding from a saved URL or issues a bind
capability. Read [setup.md](setup.md) for `REUSE`, `RECOVERY`, and `FIRST_SETUP`
startup handling, and [protocol.md](protocol.md) for the one-time capability,
no-capability binding check, and `WORKSPACE_NOT_BOUND` semantics.

When a target workspace is explicitly selected for first binding, recovery, or
an intentional switch, the bind command may issue one fresh capability just in
time. When no capability is available and binding is unknown, the protocol's
no-capability check comes first; only its `WORKSPACE_NOT_BOUND` result permits
issuing a capability on that fallback path. Never select a fallback workspace.

## Browser Ready host contract

Browser Ready is a Skill-executor/host capability, not a production adapter.
This repository has no production browser-readiness caller or CLI/browser
dependency. If the host exposes the capability, perform one lightweight
readiness preparation per continuous
workflow:

- `READY`: reuse the temporary result;
- `NOT_READY`: request one open of `https://chatgpt.com/` without polling;
- `UNKNOWN`: warn briefly and continue the selected message route.

Recheck only after direct browser/host invalidation or an interaction-environment
change. Do not inspect browser processes, open duplicates, use the system
browser, or treat browser state as conversation binding. If the host capability
is unavailable, return the packet for the authorized user/host action.

## Coding loop

Use the protocol states:

```text
INIT → PLAN → EXECUTING → EXECUTED → REVIEW → (PLAN | DONE | BLOCKED)
RESUME → (PLAN | EXECUTING | REVIEW)
```

1. Send the appropriate protocol packet only through an authorized host action.
2. Codex validates ChatGPT's finite plan against the current workspace, then
   edits files, runs commands/tests, and preserves real failures.
3. The installed ChatCodePlus plugin hook records validation command results
   after each command and finalizes the task's TestRun/Execution report when
   the Codex turn stops. A turn with no observed validation command is recorded
   as `unverified`, never as `ok` or PASS. Do not depend on the model
   remembering a reporting command. The hidden `record` command remains a
   compatibility entry point, not the normal reporting path.
4. Send `EXECUTED` with result metadata only. ChatGPT reviews current state
   through MCP; `EXECUTED → REVIEW` stays in the same active task.
5. Continue on a new plan, finish on `DONE`, or surface the specific decision
   needed for `BLOCKED`. Do not invent success or silently retry a failed step.

Control messages stay under 1 KB and contain no secrets, raw metadata, files,
diffs, logs, or credentials. Reply reception and delivery are host boundaries;
follow `protocol.md` and do not infer completion from a UI timeout or stale
reply.

## Workspace inspection order

The first call for a new or unknown conversation is the binding-only
`workspace_snapshot()`. Do not upgrade it to a tree, Git status, or execution
history merely for confirmation. Ask for `detail:"overview"` only when broad
project context is useful, and `detail:"full"` only for the explicit combined
legacy view. Otherwise request the narrow directory page, file range, search,
Git status, or diff needed for the current question. Use pagination markers;
do not request exact sizes or totals unless the task needs them.

## User-visible progress

For substantial multi-step review, investigation, debugging, architecture,
performance, security, or verification work, use stage-based and time-based
progress rather than tool-count-based progress. Start with one brief update,
then update when a meaningful task stage changes, an important finding or
failure is confirmed, or substantial final verification begins. Batch routine
reads, searches, Git checks, and related workspace calls silently.

Use the user's current language for user-visible progress headings and summaries;
keep code symbols, file names, and necessary proper nouns as-is. If meaningful
work is still running and roughly 45–60 seconds pass without a visible update,
send one short liveness update when the assistant has an opportunity to speak
between calls. Do not start another ChatGPT planning or review round-trip merely
to report progress. Progress is not a reason to create another request, and a
single long tool call should rely on protocol progress when available rather
than being interrupted or duplicated.

Treat MCP write progress as file-operation status, not task status. Prefer
`edit_file` for one exact replacement, `apply_patch` for multiple exact
replacements in one existing file, and `write_file` for creation or an
intentional whole-file rewrite. Existing-file mutation requires bounded valid
UTF-8 text and exact matching; never approximate a failed edit. A successful
`write_file`, `edit_file`, or `apply_patch` means only that file operation completed. If more
planned edits, tests, Git review, runtime synchronization, or final verification
remain, say what was completed and what comes next instead of saying the overall
task is complete. Reserve overall-completion wording for the point when the
requested task and its required verification are actually finished.

Long-running token-bearing write/edit/patch calls may also send a short MCP liveness
heartbeat while one real file-operation stage remains active. It is for the
Host's current activity indicator, not another chat update, a queued phase, or
evidence of completion. Do not echo each heartbeat in conversation; summarize
actual work only at meaningful task boundaries.

When `run_command` is available, use it according to the active command mode
and the user's task. In `safe` mode, the server permits validation-oriented
package scripts and test runners only. In `full` mode, the server permits
arbitrary structured executable-plus-argument commands, including local tooling
such as Git, package managers, language runtimes, and build tools. Full mode is
not an interactive shell or a filesystem sandbox: processes start from the bound
workspace but inherit the OS user's permissions. Never encode pipes, redirects,
or other raw shell syntax into arguments; invoke the executable and arguments
directly. Command output may be truncated; use the exit code, timeout flag,
bounded output, and follow-up file/test evidence as appropriate. A command
heartbeat belongs to the same MCP request and must not create another ChatGPT
round-trip.

## Live schema and restart boundary

When MCP schemas or tool descriptions change, verify the live Gateway's
`mcpSchemaVersion` and refresh/recreate the Connector when the host lacks a
reliable metadata refresh. Do not delete state to refresh metadata. A fixed
public URL must remain unchanged; a temporary URL change affects reachability
and requires the existing Connector URL to be updated, not a binding reset.
