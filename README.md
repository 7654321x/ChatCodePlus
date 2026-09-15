# ChatCodePlus

ChatCodePlus 让 ChatGPT 负责规划和审阅，让 Codex 继续负责修改文件、运行命令、测试和 Git。

本仓库只包含由最新源码生成的可分发 Skill，不包含开发仓库中的 `src/`、`tests/`、构建配置或维护者凭据。

## 安装

可以在 Codex 中让 Skill Installer 从以下仓库安装：

```text
https://github.com/7654321x/ChatCodePlus.git
```

也可以手动克隆到 Codex Skills 目录。

Windows PowerShell：

```powershell
git clone https://github.com/7654321x/ChatCodePlus.git "$env:USERPROFILE\.codex\skills\ChatCodePlus"
```

macOS / Linux：

```bash
git clone https://github.com/7654321x/ChatCodePlus.git "${CODEX_HOME:-$HOME/.codex}/skills/ChatCodePlus"
```

安装后新建一个 Codex 任务，然后说：

```text
使用 ChatCodePlus 配置当前工作区。
```

## 分发内容

- `SKILL.md`：Skill 路由、状态和安全契约。
- `agents/openai.yaml`：Codex Skill 调用策略。
- `references/`：配置、连接恢复、编码协作和协议说明。
- `runtime/`：由当前源码构建的单文件运行时及完整性 manifest。
- `scripts/`：Windows、macOS 和 Linux 启动及 bootstrap 脚本。

`runtime/manifest.json` 记录生成运行时的 SHA-256。启动脚本会验证该哈希，确保下载后的 runtime 与构建产物一致。

## 安全边界

- 每位用户运行自己的本机 Gateway，并连接自己的 ChatGPT Connector。
- 仓库不包含共享 OAuth token、Cloudflare 凭据、配对码或工作区绑定码。
- ChatGPT 仅通过只读工具访问明确连接的工作区。
- 本机状态保存在 `~/.chatcodeplus`，不会写入被连接的项目仓库。

首次配置中涉及登录、授权、验证码、双重验证或配对码提交时，仍由用户在对应页面完成。
