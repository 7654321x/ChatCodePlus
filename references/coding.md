# Coding, planning, and review

ChatGPT plans/reviews through read-only MCP tools; Codex owns all local edits,
commands, tests, Git, and recovery.

## Fast resume decision order

Before beginning a task, running `preflight`, preparing a binding check, or
composing INIT, first determine whether the same currently confirmed ChatGPT
conversation is already in `PLAN`, `EXECUTING`, `EXECUTED`, or `REVIEW`.

- If it is, use the `RESUME` route below and stop this decision path. Do not
  continue to preflight or any INIT/binding-check instruction.
- After `DONE`, an explicit new task request uses a no-capability new-task
  INIT with a new task ID and iteration zero in the same confirmed bound
  conversation. Do not resume the completed task or repeat binding checks.
- Use normal initialization only when neither bound-task path qualifies, or when
  direct evidence shows a new conversation, a different workspace,
  `WORKSPACE_NOT_BOUND`, or a binding failure.

This is a routing priority, not a second binding state or a post-preflight
optimization.

## Message readiness resolver

`src/conversation/readiness.ts` defines a pure classification of facts
that are already observed at the Gateway, OAuth, workspace, and binding
boundaries. `checkMessageReadiness()` performs no I/O and stores no
conversation, URL, browser, timestamp, or binding data.

- A currently confirmed `BOUND` conversation in `PLAN`, `EXECUTING`, `EXECUTED`,
  or `REVIEW` routes to `RESUME`.
- INIT has three local purposes: `CHECK_BINDING` for unknown binding,
  `BIND_WORKSPACE` for an explicit target (or after `WORKSPACE_NOT_BOUND` on
  the no-capability fallback), and `NEW_TASK` after `DONE` with an explicit
  new task request. Only `BIND_WORKSPACE` may issue a capability.
- A verified Gateway, OAuth, workspace, or binding failure routes to
  `RECOVERY` and must not generate INIT.
- Missing runtime/task prerequisites route to `BLOCKED`; unknown binding alone
  allows `CHECK_BINDING` when runtime prerequisites are ready. Do not infer
  binding from a saved URL, browser state, or earlier control message.

Message readiness determines message routing only. It does not replace
`workspace_snapshot()` or the Gateway binding store, which remain the
canonical binding source.

## Browser and conversation resume

Before composing a control message, the Skill executor uses the host's actual
available browser tools as described in SKILL.md. It performs one readiness
check per continuous workflow and reuses the temporary readiness result for
INIT, PLAN, EXECUTING, EXECUTED, REVIEW, RESUME, and NEW_TASK. It does not
poll, wait for rendering, open a duplicate browser, or use the system browser.

`src/browser/browser-ready.ts` is an injected-host helper, and
`src/conversation/resume-resolver.ts` maps readiness results including the INIT
purpose. Neither has a production host caller; they are not exposed by the CLI
or included in the bundled Skill runtime. Do not claim the Skill automatically
calls these functions. Follow the documented decision using observed facts;
do not invent an adapter API or add a browser dependency to the CLI.

For an active confirmed conversation, browser preparation followed by `RESUME`
continues without preflight, `workspace_snapshot()`, INIT, or a bind capability.
A new/revalidated conversation follows the narrow binding path. If host
delivery/read access is unavailable, return the packet for manual delivery and
request the corresponding reply; do not claim it was sent or completed.

Browser readiness is environment preparation only. It never determines a
workspace binding; `workspace_snapshot()` and the Gateway binding store remain
the canonical binding source.

## Preflight

Only after both confirmed bound-task paths have been ruled out, run
`<chatcodeplus> preflight -w <workspace> --json` once for a new or revalidated
conversation. It never creates a bind capability because a
saved URL is not the canonical conversation binding. It starts/reuses the
Gateway, registers the workspace once, reuses the returned registration record,
reads the saved conversation,
and confirms OAuth. It does not list all registered workspaces just to confirm
that same registration.

- If OAuth is not usable, preflight must not produce a bind capability. If the
  public connection is unhealthy, route to recovery before sending INIT.
- ChatGPT mode is not a binding condition: ChatCodePlus requires neither Chat
  mode nor Work mode. When ChatCodePlus tools are available, use a no-code
  `workspace_snapshot()` only when the binding is unknown and no explicit
  capability is available. A selected target workspace with a fresh capability
  may take the capability-bearing INIT path directly. If tools are unavailable,
  report that capability failure; do not invent a UI-mode restriction.
- A successful no-code snapshot proves and reuses the canonical conversation
  binding. A saved conversation is only default/last-used routing metadata; it
  is not an authorization source or the workspace's only valid conversation.
- If the target workspace is selected for first binding, recovery, or an
  explicit switch, run `<chatcodeplus> bind -w <workspace> --json` just in
  time and send the capability-bearing INIT directly. A preliminary no-code
  snapshot is not required to obtain `WORKSPACE_NOT_BOUND`. If no capability
  is available and the binding is unknown, use the no-capability snapshot
  check; only its `WORKSPACE_NOT_BOUND` result authorizes generating a code on
  that fallback path.
- Read `protocol.md` before composing a control message. After a successful
  binding check, continue planning without another check INIT. After generating
  a capability, return its binding INIT immediately; do not run unrelated
  status, discovery, browser, or documentation checks.
- Reuse a saved conversation only for its existing workspace binding. A
  workspace change requires a fresh explicit bind capability; without one,
  never switch implicitly.

Binding semantics and control-message formats are canonical in `protocol.md`.
Normal operation never asks for a greeting or manual Connector selection.

## Fast resume

When the same currently confirmed ChatGPT conversation is already in `PLAN`,
`EXECUTING`, `EXECUTED`, or `REVIEW`, continue the active task with protocol.md's `RESUME`
control message. This is a control-message shortcut, not a second binding or
session store:

- Do not run `preflight`, call `workspace_snapshot()`, generate INIT, or issue
  a bind capability.
- Keep the existing task ID and use the next appropriate iteration. The resume
  request contains only the compact task continuation or review question.
- At `EXECUTED`, proceed to REVIEW using the recorded execution result. The
  RESUME route does not replace the existing EXECUTED message format.
- Do not automatically send the message. The user or a separately authorized
  host action controls delivery to ChatGPT.

Leave this path only when there is direct evidence of a new conversation, a
different workspace, `WORKSPACE_NOT_BOUND`, or another binding failure. Use the
existing setup/recovery route for that evidence; do not create a cache of
conversation IDs, browser sessions, URLs as bindings, or binding timestamps.

## Execution loop

After the decision order above, follow:

```text
INIT → PLAN → EXECUTING → EXECUTED → REVIEW → (PLAN | DONE | BLOCKED)
```

1. For a confirmed binding, reuse the current workspace. For first binding,
   recovery, or an explicit workspace switch with a selected target, run the
   bind command and send a capability-bearing INIT directly; ChatGPT then
   resolves the target workspace and returns a finite plan with concrete
   files, risks, tests, and success criteria. If the binding is unknown and
   no capability is available, send a no-capability binding check INIT first;
   on a successful snapshot reuse the existing binding, and only its
   `WORKSPACE_NOT_BOUND` result permits issuing a capability on that fallback
   path. For `DONE` plus a new task request with binding still confirmed,
   instead send protocol.md's new-task INIT and proceed to PLAN without
   preflight, a binding check, or a capability.
2. Codex validates the plan against current source and executes it. ChatGPT does
   not operate the shell, files, Git, or tests.
3. Record the result with `<chatcodeplus> record -w <workspace>`, including real
   changed-file count, test summary, and exit status.
4. Send EXECUTED without diffs/logs/file bodies. ChatGPT independently reviews
   current workspace state and recorded results through MCP. `EXECUTED → REVIEW`
   stays in the same active task and never adds a binding operation.
5. Continue on PLAN, finish on DONE, and surface only the specific user choice
   on BLOCKED. Update the saved session's task, iteration, and state.

After authorized sending, use protocol.md's reply reception contract before
advancing a task state. A UI timeout does not restart setup or issue a code.

Control messages stay under 1 KB and never contain secrets, raw metadata,
credentials, workspace file content, diffs, or logs.

## Restart boundary

After recovery/restart, compare the preflight URL. A fixed URL must remain
unchanged. A changed temporary URL requires updating the existing Connector,
then reopening the same saved conversation. Named/Quick Tunnel changes affect
reachability only: re-test `workspace_snapshot()` without a bind code once and
never clear a binding, create a conversation, or select another workspace as
fallback merely because the Tunnel changed.
