# First-time setup

Normal flow:

```text
LOCAL_SETUP → CONNECTOR_SETUP → OAUTH_PAGE_OPEN → PAIRING_REQUIRED
            → PAIRING_CODE_ISSUED → PAIRING_COMPLETED → OAUTH_READY
            → PREFLIGHT → FRESH_INIT → CONVERSATION_BOUND → DONE
```

`PAIRING_COMPLETED` means the user submitted the pairing code and the OAuth
page successfully finished. Opening the OAuth page is not authorization
completion. `OAUTH_READY` means the browser authorization completed after
pairing; `PREFLIGHT` then confirms locally that OAuth is usable. Only after that
successful check report `ChatGPT 连接成功。` A successful first
`workspace_snapshot(bind_code)` means `当前 ChatGPT 对话已绑定工作区。`

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

After pairing is completed, OAuth has finished, and the user can immediately
receive the message:

1. Run `<chatcodeplus> preflight -w <workspace> --json` once. This is the
   minimal OAuth verification. It issues a bind capability only when OAuth is
   usable and no saved conversation exists. Continue only when it returns `ok=true` and
   `authorizationReady=true`; on failure, return its recovery action and no
   INIT.
2. If preflight returns a saved conversation and null bind fields, say
   `ChatGPT 连接成功。`, open that conversation, and immediately send
   protocol.md's reuse INIT without a bind code. If it returns
   `WORKSPACE_NOT_BOUND`, follow recovery.md's lazy bind path in the same
   conversation.
3. If there is no saved conversation, say `ChatGPT 连接成功。`, then immediately
   return this complete message using preflight's fresh code and a unique task
   ID:

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

4. Tell the user: `请新建一个 ChatGPT 对话，把上面整段消息发送进去。`
5. After ChatGPT confirms the expected workspace, save its URL and report
   `当前 ChatGPT 对话已绑定工作区。`

The code is five-minute and single-use. Generate it as late as possible and do
nothing unrelated before returning INIT. Normal setup never asks for a greeting
or manual per-conversation Connector selection. Binding security and failure
semantics are canonical in `protocol.md`; read it only for protocol work or a
binding failure.
