# Updating ChatCodePlus

There is no remote update channel. ChatCodePlus publishes nothing to GitHub, so
`<chatcodeplus> update-check` no longer contacts a remote manifest: it always
reports `checked: false`, `updateAvailable: false`, logs that no channel exists,
and never claims the installed build is already current. Do not read that command
as evidence about currency.

The authoritative currency check is local and read-only:

```
pnpm skill:sync --check
```

It compares `package.json`, the canonical Skill runtime manifest, the Plugin
manifest, and the installed Skill package, and prints `already_current` or `stale`
with the first reason (exit code 1 means not current). Version-parity and the
"canonical distribution changed, so the version must already have increased" rule are
enforced by the same implementation in both `--check` and the real `sync`.

Use this reference only when:

1. the user explicitly asks to update; or
2. an explicit `<chatcodeplus> update-check` reports an available update — which
   the removed remote channel can no longer do, so today this branch only applies
   if a real, published channel is reintroduced.

1. Record the current public URL, authorization state, and requested lifecycle modes.
   The locally saved canonical `ChatCodePlus/` package is the distribution source;
   no Git commit, GitHub push, or release is required, and no startup network check
   substitutes for the local currency check above.
2. From the repository, run `pnpm skill:sync`. It refuses to distribute when a
   version has drifted or when canonical distribution changed without a version increment,
   builds only stale runtime output, verifies the runtime, updates the Plugin copy,
   and atomically installs the complete canonical package into the user Skill
   directory. A newer installed package is never overwritten by an older one.
   `pnpm skill:sync --check` is the read-only currency check. Never replace only
   `runtime/chatcodeplus.mjs`.
3. Start through `pnpm skill:launch -- start -w <workspace> [--no-write]
   [--execute [full|safe]|--no-execute] [--tunnel] [--json]`, or use
   `pnpm skill:launch -- restart [--write|--no-write] [--execute [full|safe]|--no-execute]
   [--tunnel] [--json]` when restart is intended. Both commands first synchronize,
   then invoke the installed launcher. The Gateway remains machine-level; `-w` is
   not a restart option. A fresh start defaults to workspace write mode and full
   command execution; plain restart preserves both live modes.
4. The current task can verify the new launcher immediately. A new Codex task may
   be needed to reload new Skill instructions in the host. Check Gateway status and
   run `<chatcodeplus> doctor -w <workspace> --no-fix --json` as needed.
5. If the public URL changed, follow the manual Server URL update handoff in
   [recovery.md](recovery.md) before resuming the original task.

Report that the update completed, then resume the triggering task. Never use git stash,
reset, clean, or a checkout-specific pnpm build in the installed Skill workflow.

`sourceSha256` covers runtime/source inputs only. `distributionSha256` also covers
the complete Skill instruction/reference/policy/launcher tree and packaging inputs.
Changing a distributed document or launcher requires one patch increment, just
like a source change. Generated manifest/bundle are excluded from that input hash:
the manifest records it, and `runtimeSha256` separately verifies raw bundle bytes.
The manifest stores hashes of external packaging inputs so the installed package
can verify its own full Skill tree without the repository. Plugin copies retain
canonical identity with only the declared implicit-invocation policy transform;
exact tree parity checks that transform. Legacy manifests retain the source guard
until the next version advance introduces the additive distribution fields.
