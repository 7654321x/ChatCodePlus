# Integrated runtime and dependencies

Use this workflow for first installation, `CHATCODEPLUS_RUNTIME_INTEGRITY_FAILED`,
`CHATCODEPLUS_NODE_UNSUPPORTED`, or `CHATCODEPLUS_CLOUDFLARED_MISSING`.

1. Run `<chatcodeplus> bootstrap --check --json` when the launcher can run. The Windows
   `bootstrap.ps1 -Check` and POSIX `sh bootstrap.sh --check` scripts are also available
   before Node.js is installed.
2. Report platform, architecture, missing components, official download sources and
   the user-scoped install directory. Ask for one confirmation.
3. After confirmation, run the platform bootstrap script with `--install`/`-Install`.
   It downloads the latest Node.js 22 LTS and cloudflared release, verifies official
   SHA-256 metadata, stages files in a temporary directory, and atomically activates
   them without changing system PATH.
4. Run check again. If an unsupported platform, missing curl/tar, network error,
   checksum mismatch, or write-permission failure remains, stop and show only the first
   stable error plus the exact manual prerequisite. Never bypass checksum validation.
5. Runtime integrity failures are repaired by reinstalling the complete Skill package,
   not by downloading an individual `chatcodeplus.mjs` file.
