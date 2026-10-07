# Connector UI guidance

This is the host-UI reference for first setup. The labels may be localized or
change; the protocol does not depend on them.

1. Open ChatGPT in the built-in browser and find the Connector/plugin creation
   entry from the account/settings or composer integrations area.
2. Create or reuse the ChatCodePlus Connector with these stable fields:
   - **Name**: `ChatCodePlus`
   - **Server URL**: the current public URL followed by `/mcp`
   - **Authentication**: `OAuth`
3. Save it, then choose **Connect** or **Authorize** on the same Connector.
4. If the authorization page asks for a pairing code, keep that page open and
   tell Codex that the pairing boundary is reached. Enter the one-time code
   only after Codex provides it, then report completion after the page finishes.

Do not infer that a missing menu, an unavailable host observation, or a stale
localized label means the Connector is absent. Use `setup.md`'s explicit
first-setup gate and `recovery.md` for an observed invocation failure.
