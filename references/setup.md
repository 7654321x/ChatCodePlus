# First-time setup

Normal flow:

```text
LOCAL_SETUP → CONNECTOR_SETUP → OAUTH_PAGE_OPEN → PAIRING_REQUIRED
            → PAIRING_CODE_ISSUED → PAIRING_COMPLETED → OAUTH_READY
            → PREFLIGHT
              ├─ confirmed binding → reuse → DONE
              ├─ target workspace selected → FRESH_BINDING_INIT
              │                         → CONVERSATION_BOUND → DONE
              └─ binding unknown/no capability → CHECK_INIT
                                         ├─ reuse → DONE
                                         └─ WORKSPACE_NOT_BOUND → FRESH_BINDING_INIT
                                                                  → DONE
```

`PAIRING_COMPLETED` means the user submitted the pairing code and the OAuth
page successfully finished. Opening the OAuth page is not authorization
completion. `OAUTH_READY` means the browser authorization completed after
pairing; `PREFLIGHT` then confirms locally that OAuth is usable. Only after that
successful check report `ChatGPT 连接成功。` A successful first
`workspace_snapshot(bind_code)` means `当前 ChatGPT 对话已绑定工作区。`

## ChatGPT conversation mode

ChatCodePlus does not require Chat mode or Work mode. Do not infer workspace
binding requirements from ChatGPT UI modes. Binding depends only on available
ChatCodePlus workspace tools and the canonical conversation binding. If tools
are available, execute the binding/reuse flow directly. If tools are
unavailable, report that unavailable capability; do not invent UI restrictions.

## Local setup

Run the full onboarding sequence only once:

1. `<chatcodeplus> discover -w <workspace> --json`.
2. Run the platform bootstrap check. If a dependency is missing, route to
   `bootstrap.md`.
3. Reuse saved `fixed` or `temporary` mode. Ask for fixed versus temporary only
   when unconfigured; route to `named-tunnel.md` only for fixed mode.
4. `<chatcodeplus> setup -w <workspace> --json` starts/reuses the Gateway,
   registers the workspace, and establishes the selected connection.

Setup must not create an OAuth pairing code or workspace bind capability.
Corrupt state is recovery, not a new installation.

## Connector packet

Open ChatGPT in the built-in browser and give this as one user task, using the
currently visible localized menu labels where necessary:

```text
已打开 ChatGPT 页面。请在页面中完成 ChatCodePlus 首次连接配置：

1. 进入 **设置 → 账户安全与登录**，打开 **开发人员模式**。

2. 返回 ChatGPT 主界面，点击左侧的 **插件/应用按钮**，在打开的面板中
   找到搜索框旁边的 **“+”**，点击后选择 **添加插件/连接器**。

3. 按以下信息创建 ChatCodePlus：
   - Name：ChatCodePlus
   - Description：Securely connect ChatGPT to the current Codex workspace for planning and review.（可不填）
   - Server URL：<current MCP URL>
   - Authentication：OAuth

4. 保存后点击 **Connect / Authorize**，选择并连接 ChatCodePlus。

5. 如果随后出现 **ChatCodePlus 配对码输入页面**，请保持当前页面打开，
   并告诉我：

   `需要配对码`

此时只是进入 OAuth 授权流程，授权尚未完成。

我提供一次性配对码后，请在当前页面输入并点击 Connect / Authorize。
页面成功完成授权后，再告诉我：

`配对完成`
```

Do not split these ordinary page steps across turns. If the Connector already
exists, reuse it; do not create a duplicate.

## OAuth continuation

Use current task state; do not rerun local setup.

- If the visible authorization page requests a pairing code, immediately run
  `<chatcodeplus> pair --json`. Return only the code, expiry, and instruction to
  enter it and click Connect. Pairing is machine-level, 30-minute, and
  single-use. Pause while the user submits it; do not run preflight yet.
- Treat pairing as completed only after the user reports that the code was
  submitted and the authorization page successfully finished. During this
  first-time flow, a vague `已授权` does not prove pairing completion. Continue
  from the last confirmed stage without probing via setup, status, doctor,
  discovery, or Tunnel commands.
- Never generate pairing during setup, before the page asks, from unknown OAuth
  state alone, or after OAuth succeeds.
- Login, consent, CAPTCHA, 2FA, and pairing submission are user boundaries.

## Just-in-time INIT

After pairing is completed and OAuth has finished, prepare the ChatGPT browser
environment immediately before returning the message:

Message readiness determines the next control-message route only; it does not
replace `workspace_snapshot()` or the Gateway binding store. A no-capability
check INIT is available when the target binding is unknown and no capability is
available. If Codex has selected a target workspace and has a fresh capability,
the capability-bearing binding INIT may be sent directly; an earlier
`WORKSPACE_NOT_BOUND` check is not required. Gateway, OAuth, workspace, or
binding failures route to recovery; unknown runtime prerequisites remain
blocked. A confirmed binding reuses the binding and skips FRESH_BINDING_INIT.

Browser readiness is only environment preparation. Once the Codex host has
returned `READY` for this continuous setup/workflow, reuse that temporary
readiness for the subsequent control messages; do not repeat the host check
for every state. For a first check, reuse a `READY` built-in browser, open
`https://chatgpt.com/` once for `NOT_READY`, or warn and continue for
`UNKNOWN`. Recheck only on direct evidence that the host/browser environment
changed or became unavailable. It does not poll, wait for page rendering, or
decide conversation binding.

1. Run `<chatcodeplus> preflight -w <workspace> --json` once. This is the
   minimal OAuth verification. It registers the selected workspace and uses
   that successful registration result directly; it does not issue a second
   workspace-list request to confirm the same operation. Continue only when it returns `ok=true` and
   `authorizationReady=true`; on failure, return its recovery action and no
   INIT. Preflight never infers a conversation binding from a saved URL and
   never issues a bind capability.
2. Follow SKILL.md's browser-readiness instruction using available host tools
   before returning a binding message:
   - `READY`: reuse the current ChatGPT page; do not open a duplicate.
   - `NOT_READY`: request one open of `https://chatgpt.com/` in the built-in browser.
   - `UNKNOWN`: record a brief warning and continue returning the INIT.

   Browser preparation is best-effort and must not invalidate, replace, or
   delay a fresh bind capability. The Skill executor uses available host tools;
   do not implement it in the CLI, inspect browser processes, or open the
   system default browser. The in-app browser belongs to the Codex host, and
   its state never decides conversation binding. No production host adapter
   currently connects the repository's browser/readiness helpers to this flow.
3. Say `ChatGPT 连接成功。`. Open the saved conversation when available, otherwise
   create the target conversation. Read protocol.md for message formats and
   reply reception. Choose exactly one binding path:
   - If this conversation's binding is already confirmed and the target
     workspace is unchanged, reuse it and continue without a capability.
   - If Codex has selected a target workspace for first binding, recovery, or
     an explicit workspace switch, run `<chatcodeplus> bind -w <workspace>
     --json` once and immediately return the following capability-bearing INIT.
     Do not perform a preliminary no-code snapshot solely to obtain
     `WORKSPACE_NOT_BOUND`:

```text
[CHATCODEPLUS]
STATE: INIT
TASK_ID: chatcodeplus_<unique>
ITERATION: 0
WORKSPACE_BIND_CODE: <fresh code>

GOAL:
Bind this ChatGPT conversation to the current ChatCodePlus workspace.

INSTRUCTION:
Call workspace_snapshot with the provided bind code, verify the returned
workspace, and confirm successful binding.
```

   - If the binding is unknown and no capability is available, send
     protocol.md's no-capability binding-check INIT through a separately
     authorized host action, or return the packet for the user to send. Wait
     for its corresponding reply. It must call `workspace_snapshot()` without
     a bind code:
     - A successful snapshot confirms the existing canonical binding. Reuse
       that conversation and continue without generating a capability.
     - `WORKSPACE_NOT_BOUND` confirms that this no-capability path needs a
       fresh code. Keep that same conversation, run the bind command once,
       then immediately return the capability-bearing INIT above.

4. Tell the user: `请将上面整段消息发送到当前目标 ChatGPT 对话。`
5. After ChatGPT confirms the expected workspace, save its URL and report
   `当前 ChatGPT 对话已绑定工作区。`

The code is five-minute and single-use. Generate it as late as possible and do
nothing unrelated before returning INIT. A valid capability explicitly creates,
confirms, or switches the conversation binding; without one, snapshots only
reuse the current binding. Normal setup never asks for a greeting or manual
per-conversation Connector selection. Binding security and failure semantics
and reply reception are canonical in `protocol.md`.
