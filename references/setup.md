# Connection setup

This reference owns startup/reuse, first setup, Connector creation, and OAuth
continuation. Binding and control-message formats are canonical in
[protocol.md](protocol.md); browser preparation is owned by
[coding.md](coding.md). Do not copy those state machines here.

## Quick local lifecycle selection

- **Check only:** `<chatcodeplus> status --json` is read-only. A healthy result
  needs no `start`, `restart`, OAuth, pairing, or new bind code.
- **Connect/reuse:** `<chatcodeplus> preflight -w <workspace> --json` once;
  it starts/reuses a machine Gateway and registers that selected workspace.
  Consume `connectionRoute`/`nextAction`; do not reconstruct the state machine.
- **Explicit start:** first verify/sync the installed local Skill; run
  `<chatcodeplus> start -w <workspace> --json` (add `--tunnel` only when
  publicly connecting). A healthy machine Gateway is reused.
- **Explicit restart:** after installed-Skill verification run
  `<chatcodeplus> restart`, then `status --json`. A plain restart preserves
  live `writeMode`/`commandMode`; do not silently change them or reset OAuth,
  session records, bindings, or Tunnel configuration.
- **Explicit stop:** `<chatcodeplus> stop` stops the machine service but does
  not mean OAuth revocation. Only an explicit machine authorization disconnect
  uses `unpair`; see [recovery.md](recovery.md).

This selection runs **after** Fast RESUME has been ruled out. Neither a Gateway
PID nor a saved conversation URL proves the current ChatGPT conversation bound.
If only status was requested, never use the mutating `preflight` entry.

## Connection entry

Requests such as `启动连接`, `连接 ChatGPT`, `继续使用 ChatCodePlus`, and
`恢复连接` are reuse requests, not first-install requests:

```text
CONNECTION_ENTRY → REUSE_CHECK
                  ├─ usable → restore saved-session routing → existing binding route
                  ├─ observed authorization/invocation failure → RECOVERY
                  └─ confirmed Connector absent + not_configured → FIRST_SETUP
```

Run `<chatcodeplus> preflight -w <workspace> --json` once and consume its
structured `connectionRoute` and `nextAction`:

- `REUSE`: Gateway, configured Tunnel, machine OAuth, and workspace
  registration are usable. Restore the saved session when present and follow
  the current binding route in `protocol.md`; do not create a capability just
  because startup was requested.
- `RECOVERY`: perform only the returned repair against the existing Connector;
  read [recovery.md](recovery.md) for the observed failure.
- `FIRST_SETUP`: continue to the first-setup gate below. Do not infer it from
  an unknown or unavailable Connector observation.

`preflight` does not generate a pairing code or workspace bind capability. When
readiness is confirmed and a first bind or explicit workspace switch is authorized,
`<chatcodeplus> bind -w <workspace> --packet` issues a fresh code and prints one
complete INIT message for the authorized host to deliver. Do not generate this
packet during an unknown-binding check or as a side effect of preflight. A
saved session URL is routing metadata only and never proves binding. A changed
temporary URL requires updating the existing Connector; it does not clear
OAuth, saved sessions, registrations, or bindings. An unhealthy configured
public connection is recovery, not successful setup.

## First setup gate

Enter first setup only when authorization is explicitly `not_configured` with
no reusable connection, or a real host operation confirms that the old
Connector is absent. “Cannot confirm” is not “absent”. Do not create a second
Connector on the reuse or recovery path.

Run the local setup sequence once:

1. `<chatcodeplus> discover -w <workspace> --json`.
2. Run `<chatcodeplus> bootstrap --check --json`; use [bootstrap.md](bootstrap.md)
   if a dependency is missing.
3. Reuse configured `fixed` or `temporary` mode. Ask only when unconfigured;
   use [named-tunnel.md](named-tunnel.md) for fixed mode.
4. `<chatcodeplus> setup -w <workspace> --json` starts/reuses the machine
   Gateway, registers the existing workspace, and establishes the connection.

Setup must not create pairing or bind capabilities. Corrupt state is a recovery
condition, not a new installation.

## Connector creation

Give one complete page task. Use [connector-ui.md](connector-ui.md) for the
current host UI path and localized labels. The stable packet is:

```text
Name: ChatCodePlus
Description: Securely connect ChatGPT to the current Codex workspace for planning and review.
Server URL: <current public URL>/mcp
Authentication: OAuth
```

After saving, ask the user to choose `Connect / Authorize`. Opening the OAuth
page is not proof of authorization. If the page asks for a pairing code, pause
at that user boundary and continue with the OAuth steps below.

## OAuth continuation

- When the visible authorization page requests a code, run
  `<chatcodeplus> pair --json` immediately. Return only the code, expiry, and
  the instruction to enter it on the current page. Pairing is machine-level,
  30-minute, and single-use.
- Do not generate pairing during setup, from unknown OAuth state, or after
  OAuth has completed. Treat pairing as complete only after the user reports
  that the code was submitted and the authorization page finished; `已授权`
  alone is not that confirmation.
- After pairing completes, run the one continuation preflight. Continue only
  when it returns `connectionRoute=REUSE` and `authorizationReady=true`.
  Follow `protocol.md` for the existing-binding check, a fresh capability, or
  the explicit target-workspace binding route. Do not reconstruct those rules
  here.
- Browser preparation is best-effort host work described in `coding.md`; it is
  not a CLI adapter and never proves a binding.

Login, consent, CAPTCHA, 2FA, pairing entry, and Connector edits are user
boundaries. Report the real state and pause there; never claim authorization,
binding, or delivery without the corresponding verified result.
