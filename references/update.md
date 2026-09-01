# Updating ChatCodePlus

Use this reference only after coding-task preflight reports an available update or when
the user explicitly asks to update.

1. Record the current public URL and authorization state. Obtain the complete newer
   Skill package from the same trusted distribution channel used for installation;
   never update only `runtime/chatcodeplus.mjs` or copy files from a development checkout.
2. Replace the complete Skill atomically, start a new Codex task so the new instructions
   load, then run `<chatcodeplus> bootstrap --check --json` and `<chatcodeplus> doctor -w <workspace>
   --no-fix --json`.
3. If a previous Gateway version is still running, run `<chatcodeplus> restart --tunnel`,
   preserving the existing state directory, authorization and Named Tunnel
   credentials. The Gateway remains machine-level; `-w` is not a restart option.
4. Run `<chatcodeplus> update-check --force --json` and `<chatcodeplus> preflight -w <workspace> --json`.
5. If the public URL changed, follow the manual Server URL update handoff in
   [recovery.md](recovery.md) before resuming the original task.

Report that the update completed, then resume the triggering task. Never use git stash,
reset, clean, or a checkout-specific pnpm build in the installed Skill workflow.
