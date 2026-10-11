# Prompt for later use

Paste the block below into a new session when the TN10 desk should mine to stp's node again. Testnet only. Do not start mainnet, a local kaspad, or a login task.

```text
You are on the Windows PC that already has the TN10 CPU miner test in C:\kaspa-tn10-miner. Read the private repo STP-KAS/tn10-storm-2026-09-27-desk-miners-public first (README.md and scripts/run-miners.ps1). Follow those notes. Testnet only. This never touches mainnet or real funds.

Goal: mine to stp's TN10 kaspad through the bore tunnel, with the published kaspa-miner 0.2.5 only.

Facts already tested on 27 Sep 2026:
- Endpoint is [tunnel] port 3567. Do not try another port. If it fails, report the exact log line and stop.
- The exe is C:\kaspa-tn10-miner\kaspa-miner.exe from https://github.com/elichai/kaspa-miner/releases/tag/v0.2.5 asset kaspa-miner-v0.2.5-win64-amd64.exe (4,054,016 bytes, SHA256 [hash]). kaspa-miner.exe --version must print "kaspa-miner 0.2.5".
- Do not pass --user-agent-suffix. v0.2.5 rejects it and exits before connecting. The tag "stp grok bot" cannot be sent until an official release contains that flag. Do not build unreleased source unless I ask.
- Do not pass -s [tunnel]. That exits with AddrParseError because this build wants an IP. The working form is -s grpc://[tunnel] -p 3567.
- Payout address: [address]
- One test command:
  kaspa-miner.exe --testnet -s grpc://[tunnel] -p 3567 -t 1 --mine-when-not-synced -a [address]
- Success is a log with "Kaspad version", then "Block submitted successfully!". This miner never prints the word "Connected". Hashrate looks like "Current hashrate is: 1.83 Mhash/s".
- "Block was not submitted: block is invalid" means two miners raced the same template. Keep going.
- "Kaspad is still not synced" with no hashrate means the node sent an empty template. v0.2.5 will not hash in that state. Report it. Do not open extra miners to push through it.
- "transport error" and "BrokenPipe" / "stream closed because of a broken pipe" means the tunnel accepted TCP and then closed the gRPC stream. Stop. Do not restart in a loop. Do not guess another port.
- On this i7-13700K, 15 miners at -t 1 used about 70% CPU and about 1.3 Mhash/s each. 30 miners pinned the CPU at 100%. The cap is 20 miners unless I say otherwise.
- Use scripts/run-miners.ps1. It must stay at 20, restart a dead slot by its own process ID, and never grow past 20. Check liveness with Get-Process -Id, not Process.HasExited.
- Start that script minimized and detached (WMI Win32_Process.Create). A miner started under a short-lived shell dies when the shell exits.
- Stop by creating C:\kaspa-tn10-miner\STOP. That kills only the miner PIDs the supervisor started. Do not add a startup task or a service. Do not start a local kaspad. Leave the desk watchers and the sixpack faucet alone.

Before starting the 20, run the single miner for about 60 seconds. If it cannot hold the stream, stop and report the exact error. If it submits blocks, start the 20 and tell me CPU use, hashrate per miner, and how many "Block submitted successfully!" lines each log got.
```
