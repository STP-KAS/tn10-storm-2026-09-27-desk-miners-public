> **Part of [tn-master](https://github.com/STP-KAS/tn-master)**, the map of every TN10 storm. Renamed on 11 Oct 2026 from `grok-desk-tn10`; old links redirect here.
>
> ← previous storm: [tn10-storm-2026-09-26-verdict](https://github.com/STP-KAS/tn10-storm-2026-09-26-verdict) | next storm: [tn10-storm-2026-10-01](https://github.com/STP-KAS/tn10-storm-2026-10-01) →
>
> **Public clean copy** of `STP-KAS/tn10-storm-2026-09-27-desk-miners` (private, archived), made on 11 Oct 2026 from its current files only. IPs, tunnel hosts, wallet addresses, 64-hex hashes and local paths are replaced by `[ip]`, `[tunnel]`, `[address]`, `[hash]` and `[local path]`. The full history stays private.

# grok / desk tn 10

Private notes from the 27 Sep 2026 Testnet-10 CPU miner test on this Windows PC. The miners join stp's TN10 kaspad through a bore tunnel. This is testnet only. It does not touch mainnet, a local kaspad, or real funds.

The later-use prompt is [PROMPT.md](PROMPT.md). The supervisor that keeps 20 miners up is [scripts/run-miners.ps1](scripts/run-miners.ps1).

## What the node is

The gRPC endpoint is `[tunnel]` port `3567`. That port is a tunnel to stp's own TN10 kaspad. No login. On 27 Sep 2026 a TCP connection to that port succeeded. DNS for `[tunnel]` was `[ip]` and `[ip]`. Those addresses can change. Use the hostname.

The payout address is the locked TN10 pay-from address:

`[address]`

The requested miner tag is `stp grok bot`. The published miner cannot send it. See below.

## Miner binary

Official Windows file only, from the GitHub release. No other download source.

- Repo: https://github.com/elichai/kaspa-miner/releases/tag/v0.2.5
- Asset: `kaspa-miner-v0.2.5-win64-amd64.exe`
- URL: https://github.com/elichai/kaspa-miner/releases/download/v0.2.5/kaspa-miner-v0.2.5-win64-amd64.exe
- Size: 4,054,016 bytes
- SHA256: `[hash]`
- GitHub does not publish a checksum for this asset. The size matched the release API, the file is a Windows executable, and `kaspa-miner.exe --version` printed `kaspa-miner 0.2.5`.
- The Windows release is an exe, not a zip. v0.2.5 (7 Jan 2024) is the newest published release.
- Local copy: `C:\kaspa-tn10-miner\kaspa-miner.exe`

`--user-agent-suffix` is not in v0.2.5. The flag exists on source `main`, where `Cargo.toml` says 0.2.7. It was added on 12 Feb 2026 in commit `38a31ff`. There is no v0.2.6 or v0.2.7 release. The unreleased flag allows at most 20 characters and rejects a `/`. `stp grok bot` is 12 characters, so length is not the problem. The published exe rejects the flag and exits code 2 before it connects:

```text
error: unexpected argument '--user-agent-suffix' found
```

`-s [tunnel]` also fails before any connection. This build accepts an IP, unless the value already starts with `grpc://`. The error is:

```text
Error: AddrParseError(Ip)
```

The form that connected is:

```text
kaspa-miner.exe --testnet -s grpc://[tunnel] -p 3567 -t 1 --mine-when-not-synced -a [address]
```

Do not try another port. If this endpoint fails, report the log line and stop.

## What a good log looks like

v0.2.5 never prints the word `Connected`. A working session prints these lines:

```text
Launching: 1 cpu miners
Kaspad version: 2.1.0
Registered for new template notifications
Found a block: <hex>
Block submitted successfully!
Current hashrate is: 1.83 Mhash/s
```

One thread on this PC (13th Gen Intel i7-13700K, 16 cores, 24 threads, Windows 11 Pro) held about 1.8 Mhash/s and the node accepted blocks within the first seconds. The first one-minute test on 27 Sep 2026 saw kaspad `2.1.0` and repeated `Block submitted successfully!` lines.

When several miners solve the same template, the node answers:

```text
Failed submitting block: RpcError { message: "Block was not submitted: block is invalid" }
```

That is a race, not a dead miner. Count `Block submitted successfully!` separately from those warnings.

## What was measured

Fifteen miners, one thread each, from 18:41 to 18:46 local time:

- All 15 stayed up. None restarted.
- Processor use averaged 70% (low 65%, high 87%).
- Each miner used about one full thread.
- Hashrate was 1.29–1.32 Mhash/s each.
- 820 blocks accepted in that window. 113 solves rejected as invalid.

Raising the count two miners every 30 seconds reached 30 at 18:52. Processor use was about 67% at 15 miners, passed 90% at 21, and sat at 100% from 25 miners onward. Hashrate fell to about 0.8–1.1 Mhash/s. Thirty threads on a 24-thread CPU is a full load. The requested lower target after that was 20.

## Why 20 did not stay up

Two separate failures showed up after the 30-miner run.

The node stopped handing out work. Logs repeated `Kaspad is still not synced` and the hashrate counters stayed at zero. In v0.2.5, an empty template sets the miner unsynced and skips the work. `--mine-when-not-synced` does not keep hashing when the node sends no block.

The supervisor then treated those processes as dead. `HasExited` came back with an empty exit code, so it restarted every slot and opened slots past 30. That burst broke the tunnel. The miner exits code 1 with:

```text
Error: Status { code: Unknown, message: "transport error", source: Some(tonic::transport::Error(Transport, hyper::Error(Io, Custom { kind: BrokenPipe, error: "stream closed because of a broken pipe" }))) }
```

After that, a clean set of 20 died the same way, and so did one miner tried again a little later. TCP to port 3567 still succeeded. The gRPC stream did not. No other port was tried.

At the end of this session the supervisor was stopped and no `kaspa-miner` process was left. Nothing is set to start at login.

## How to run it next time

1. Confirm `C:\kaspa-tn10-miner\kaspa-miner.exe --version` prints `kaspa-miner 0.2.5`.
2. Run one miner for about a minute with the command above. Success is `Kaspad version`, then `Block submitted successfully!`. A broken pipe or `AddrParseError` means stop.
3. If that one miner holds, start `scripts/run-miners.ps1` detached, minimized, from `C:\kaspa-tn10-miner`. A short-lived shell will kill the miners when the shell exits. Start it with WMI `Win32_Process.Create`, not as a child of a command that is about to exit.
4. The script keeps exactly 20 miners, one thread each, restarts a dead slot in place, and refuses to grow past 20. It checks every 30 seconds by process ID, not by `HasExited`.
5. Stop by creating `C:\kaspa-tn10-miner\STOP`. Within about 30 seconds it kills only the miner PIDs it started. Do not create a startup task or a service unless asked. Do not start the local Windows kaspad.

Logs are `C:\kaspa-tn10-miner\miner1.log` through `miner20.log` (stderr). The supervisor writes `supervisor.log`. Live PIDs are `miner-pids.txt`.
