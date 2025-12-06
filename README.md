# WindowsPinger

A tiny PowerShell helper that pings a few targets and only logs when something **changes**. It is a standalone network check script; [SvcWatchDog](https://github.com/matjazt/SvcWatchDog) can optionally host it as a Windows service. The goal is to keep logs small while still giving useful timing info when connectivity flips.

## What it does
- Pings a configurable list of addresses on a schedule.
- Retries each target up to `Count` times before marking it unreachable (avoids one-off glitches).
- Logs only on state changes: Unknown → Accessible/Inaccessible, or Accessible ↔ Inaccessible.
- Records how long the previous state lasted (hh:mm:ss) so you can see outage lengths at a glance.
- Emits lightweight logs to `log/WindowsPinger.log`.
- Keeps the original SvcWatchDog integration (UDP heartbeat + graceful shutdown event) untouched.

## Quick start (stand-alone)
1) Edit the config at the top of `scripts/WindowsPinger.ps1`:

```powershell
$pingEntries = @(
    @{ Name = "Google DNS"; Address = "8.8.8.8"; Timeout = 1000; Count = 3; State = "Unknown"; LastChange = $null },
    @{ Name = "Cloudflare DNS"; Address = "1.1.1.1"; Timeout = 1000; Count = 3; State = "Unknown"; LastChange = $null },
    @{ Name = "Local Gateway"; Address = "192.168.1.1"; Timeout = 500; Count = 6; State = "Unknown"; LastChange = $null },
    @{ Name = "UbuntuDev"; Address = "10.255.254.150"; Timeout = 500; Count = 2; State = "Unknown"; LastChange = $null }
)
```

- `Name`: label for logs.
- `Address`: IP or hostname to ping.
- `Timeout`: per-ping timeout in milliseconds.
- `Count`: maximum attempts per cycle; stops early on first success.
- Leave `State` and `LastChange` as-is; the script manages them.

2) Set the interval between cycles in `scripts/WindowsPinger.ps1`:

```powershell
$interval = 10  # seconds
```

3) Run it:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\WindowsPinger.ps1
```

Check `log/WindowsPinger.log` for change-only entries like:
```
[Google DNS] 8.8.8.8 is Accessible
[UbuntuDev] 10.255.254.150 is now Inaccessible (was Accessible for 00:12:34)
[UbuntuDev] 10.255.254.150 is now Accessible (was Inaccessible for 00:03:10)
```

## Using with SvcWatchDog
This script is standalone. SvcWatchDog is optional, but handy when you want it to run as a Windows service on client machines so IT can deploy it and later read the logs. The script already supports SvcWatchDog’s environment variables:
- `WATCHDOG_SECRET`, `WATCHDOG_PORT`: if set, it sends UDP heartbeats to the watchdog each loop.
- `SHUTDOWN_EVENT`: if set, it exits cleanly when the event is signaled.

For most users, the default SvcWatchDog configuration is fine; just point SvcWatchDog to run this script as the service command. Keep the script’s `interval` shorter than the watchdog timeout so heartbeats arrive in time.

## Why this script is useful
- Helps diagnose flaky links without drowning in repetitive logs.
- Captures outage durations automatically.
- Simple PowerShell—easy to tweak targets, timeouts, and retry counts.

## Requirements
- Windows with PowerShell (tested with Windows PowerShell 5.1).
- Network access to the addresses you list.

## Notes
- Logging is change-driven; if the network stays stable, the log stays quiet.
- Increase `Count` if your network is noisy; decrease it for faster detection.
- `Timeout` is per attempt; total wait per target is roughly `Count * Timeout`.
