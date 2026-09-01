# Coding, planning, and review

ChatGPT plans/reviews through read-only MCP tools; Codex owns all local edits,
commands, tests, Git, and recovery.

## Preflight

Run `<chatcodeplus> preflight -w <workspace> --json` once when beginning a real
task. It starts/reuses the Gateway, registers the workspace, reads the saved
conversation, and issues a short-lived bind capability only when no saved
conversation exists.

- If OAuth is not usable, preflight must not produce a bind capability. If the
  public connection is unhealthy, route to recovery before sending INIT.
- A saved conversation is default/last-used routing metadata, not an
  authorization source or the workspace's only valid conversation. Open its
  URL; preflight does not issue a workspace bind capability for this normal
  reuse path. Call `workspace_snapshot()` without a bind code and verify the
  returned workspace before continuing.
- If no saved conversation exists, create a new conversation and immediately
  send the new-binding INIT with preflight's fresh capability.
- If the saved conversation returns `WORKSPACE_NOT_BOUND`, keep that same
  conversation and follow recovery.md's one-time lazy bind path. If the saved
  URL is confirmed missing, create a replacement conversation and use
  `<chatcodeplus> bind -w <workspace> --json` just in time.
- Read `protocol.md` before composing a control message. After choosing the
  reuse or new-binding path, send its INIT immediately; do not run unrelated
  status, discovery, browser, or documentation checks.
- Reuse a saved conversation only for its existing workspace binding. Use a
  new conversation for another workspace; never rebind implicitly.

Binding semantics and control-message formats are canonical in `protocol.md`.
Normal operation never asks for a greeting or manual Connector selection.

## Execution loop

Follow:

```text
INIT → PLAN → EXECUTING → EXECUTED → REVIEW → (PLAN | DONE | BLOCKED)
```

1. Send either a reuse INIT without a capability or a new-binding INIT with the
   user's goal and fresh capability. ChatGPT resolves the workspace and returns
   a finite plan with concrete files, risks, tests, and success criteria.
2. Codex validates the plan against current source and executes it. ChatGPT does
   not operate the shell, files, Git, or tests.
3. Record the result with `<chatcodeplus> record -w <workspace>`, including real
   changed-file count, test summary, and exit status.
4. Send EXECUTED without diffs/logs/file bodies. ChatGPT independently reviews
   current workspace state and recorded results through MCP.
5. Continue on PLAN, finish on DONE, and surface only the specific user choice
   on BLOCKED. Update the saved session's task, iteration, and state.

Control messages stay under 1 KB and never contain secrets, raw metadata,
credentials, workspace file content, diffs, or logs.

## Restart boundary

After recovery/restart, compare the preflight URL. A fixed URL must remain
unchanged. A changed temporary URL requires updating the existing Connector,
then reopening the same saved conversation. Named/Quick Tunnel changes affect
reachability only: re-test `workspace_snapshot()` without a bind code once and
never clear a binding, create a conversation, or select another workspace as
fallback merely because the Tunnel changed.
