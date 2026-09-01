# Fixed Cloudflare hostname

Use only when the user selects a long-term fixed connection or an existing fixed
connection fails. One machine Gateway and Named Tunnel own one fixed Server URL;
workspaces never own or switch it.

## Configure or reuse

1. Accept a bare fully qualified hostname. Normalize lowercase; reject schemes,
   paths, ports, wildcards, and unrelated DNS changes.
2. Run `<chatcodeplus> tunnel show --json`; reuse healthy configuration and
   credentials.
3. If no accessible Tunnel exists, ask the user to complete `cloudflared tunnel
   login`, then run `<chatcodeplus> tunnel provision --hostname <hostname>
   --json`.
4. If the zone is inactive, the user adds it to Cloudflare, sets the assigned
   authoritative nameservers at the registrar, resolves DNSSEC warnings, and
   waits for activation. Never delete unrelated DNS.
5. `CHATCODEPLUS_DNS_CONFLICT` requires explicit overwrite confirmation; never
   add the flag silently.

Provisioning is transactional: stage candidate credentials, start alongside the
current provider, verify the hostname returns this Gateway service/version, then
commit machine configuration and stop the old provider. On failure, retain the
old provider/configuration. Do not automatically delete any Cloudflare Tunnel or
DNS route created before failure. `/mcp` belongs only in the Connector URL.

A configured fixed connection must never fall back to Quick Tunnel
automatically. Credential adoption is explicit and transactional; keep the
source recoverable until commit and never place credentials in the workspace,
logs, messages, or proxy configuration.

## Confirmed Windows Clash/Mihomo TUN

Use this procedure only after proving the active stack and source configuration:

1. Inspect the active profile source, not generated output.
2. Add the missing high-priority rule
   `PROCESS-NAME,cloudflared.exe,DIRECT` without reordering unrelated rules.
3. If the fixed hostname itself is unreachable, also add the missing adjacent
   `DOMAIN,<hostname>,DIRECT` rule.
4. Reload the proxy core, retry the original failure, and verify the Tunnel or
   authorization action.

Do not apply these rules to another platform or unknown proxy. Return to
`recovery.md` when network ownership/source is uncertain. Never disable proxy,
VPN, firewall, TLS, DNS security, or create a relay/local public port.

After the fixed health check succeeds, return to `setup.md` for Connector/OAuth
handoff. Do not duplicate its pairing or workspace-binding flow here.
