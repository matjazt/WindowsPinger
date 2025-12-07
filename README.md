# WindowsPinger

A lightweight PowerShell tool for monitoring network connectivity that only logs when something changes. It pings configured targets on a schedule and records state transitions with timestamps, helping diagnose network issues without generating excessive logs.

## What it does
- Pings a configurable list of IP addresses or hostnames on a regular interval.
- Retries each target up to `Count` times before marking it unreachable, filtering out transient network glitches.
- Logs only on state changes (Unknown → Accessible/Inaccessible, or Accessible ↔ Inaccessible).
- Records the duration of each state (formatted as hh:mm:ss) to track outage lengths.
- Writes change-only logs to `log/WindowsPinger.log`.
- Integrates with [SvcWatchDog](https://github.com/matjazt/SvcWatchDog) to run as a Windows service, enabling deployment on client machines for passive monitoring.

## Quick start (standalone)
1) Edit the configuration at the top of `scripts/WindowsPinger.ps1`:

```powershell
$pingEntries = @(
    @{ Name = "Google DNS"; Address = "8.8.8.8"; Timeout = 1000; Count = 3; State = "Unknown"; LastChange = $null },
    @{ Name = "Cloudflare DNS"; Address = "1.1.1.1"; Timeout = 1000; Count = 3; State = "Unknown"; LastChange = $null },
    @{ Name = "Local Gateway"; Address = "192.168.1.1"; Timeout = 500; Count = 6; State = "Unknown"; LastChange = $null },
)
```

**Configuration parameters:**
- `Name`: Descriptive label for log entries.
- `Address`: IP address or hostname to ping.
- `Timeout`: Timeout per ping attempt in milliseconds.
- `Count`: Maximum ping attempts per cycle; stops early on first success.
- `State` and `LastChange`: Leave as shown; managed internally by the script.

2) Set the interval between ping cycles:

```powershell
$interval = 10  # seconds
```

3) Run the script:

```powershell
powershell.exe -ExecutionPolicy Bypass -File .\scripts\WindowsPinger.ps1
```

4) Check `log/WindowsPinger.log` for change-only entries:
```
12/06/2025 10:15:23: [Google DNS] 8.8.8.8 is Accessible
12/06/2025 10:47:11: [UbuntuDev] 10.255.254.150 is now Inaccessible (was Accessible for 00:12:34)
12/06/2025 10:50:21: [UbuntuDev] 10.255.254.150 is now Accessible (was Inaccessible for 00:03:10)
```

## Running as a Windows service

WindowsPinger is a standalone PowerShell script, but running it as a Windows service is crucial for deployment scenarios. IT administrators can install it on client machines as a background service, allowing passive network monitoring without user interaction. Later, they can review the logs to diagnose connectivity issues.

This integration is enabled by [SvcWatchDog](https://github.com/matjazt/SvcWatchDog), a lightweight Windows service wrapper that can run any console application as a service. SvcWatchDog handles service lifecycle management, automatic restarts, and graceful shutdown.

### Preparation

**Option 1: Using the official release (recommended)**

Download the pre-packaged release from the [WindowsPinger Releases](https://github.com/matjazt/WindowsPinger/releases) section. The release already includes SvcWatchDog (renamed to `WindowsPingerService.exe`) and a sample configuration file (`WindowsPingerService.json`) in the `service` directory. You can skip to the Installation section below.

**Option 2: Manual setup**

If you're building from source or customizing the setup:

1. Download or build SvcWatchDog.exe from the [SvcWatchDog releases](https://github.com/matjazt/SvcWatchDog/releases).
2. Rename it to `WindowsPingerService.exe` (or your preferred service name).
3. Place `WindowsPingerService.exe` in the `service` directory of this project.
4. Create a configuration file named `WindowsPingerService.json` in the same `service` directory.

**Example `WindowsPingerService.json`:**

```json
{
  "log": {
    "minConsoleLevel": 99,
    "minFileLevel": 0,
    "filePath": "log\\SvcWatchDog.log",
    "maxFileSize": 10000000,
    "maxOldFiles": 3,
    "maxWriteDelay": 500
  },
  "svcWatchDog": {
    "workDir": "..",
    "args": [
      "powershell.exe",
      "-ExecutionPolicy",
      "Unrestricted",
      "-File",
      "scripts\\WindowsPinger.ps1"
    ],
    "usePath": true,
    "autoStart": true,
    "restartDelay": 2000,
    "shutdownTime": 3000,
    "watchdogTimeout": 30000
  }
}
```

**Key parameters:**
- `workDir`: Set to `".."` so paths are relative to the project root (parent of the `service` folder).
- `args`: Command line to launch PowerShell and execute `WindowsPinger.ps1`.
- `autoStart`: Set to `true` to start the service automatically on system boot.
- `watchdogTimeout`: UDP ping timeout in milliseconds. The script sends heartbeats to SvcWatchDog; if no heartbeat is received within this timeout, the service is restarted. Set this to at least twice your ping `$interval` (e.g., 30000 ms for a 10-second interval). Set to `-1` to disable watchdog monitoring.

### Installation (requires Administrator privileges)

Navigate to the project directory and run:

```powershell
# Install the service
service\WindowsPingerService.exe -i

# Start the service
net start WindowsPingerService

# Stop the service
net stop WindowsPingerService

# Uninstall the service
service\WindowsPingerService.exe -u
```

Once installed, the service files (`WindowsPingerService.exe` and `WindowsPingerService.json`) must remain in the `service` directory. Moving them will break the service.

### How it works

SvcWatchDog integrates with the Windows service system and manages the WindowsPinger script:
- Starts the script when the service starts.
- Monitors the script's health via optional UDP heartbeats.
- Automatically restarts the script if it crashes or becomes unresponsive.
- Signals graceful shutdown via a Win32 event (the `SHUTDOWN_EVENT` environment variable).

The script already includes integration code to:
- Send UDP heartbeats to SvcWatchDog (using `WATCHDOG_PORT` and `WATCHDOG_SECRET` environment variables).
- Monitor the `SHUTDOWN_EVENT` for graceful termination.

For most deployments, the example configuration above is sufficient. Refer to the [SvcWatchDog documentation](https://github.com/matjazt/SvcWatchDog) for advanced configuration options like email notifications, log rotation, and encrypted credentials.

## Use cases

- **Network diagnostics**: Identify when and for how long network resources become unavailable.
- **Passive monitoring**: Deploy as a service on client machines to collect connectivity data without user involvement.
- **Troubleshooting intermittent issues**: The retry mechanism filters out one-off glitches while capturing genuine outages.
- **Historical analysis**: Change-only logging keeps files small, making it easy to review connectivity patterns over weeks or months.

## Requirements
- Windows with PowerShell (tested with Windows PowerShell 5.1).
- Network access to the configured targets.
- (Optional) [SvcWatchDog](https://github.com/matjazt/SvcWatchDog) for running as a Windows service.

## Configuration tips
- **Increase `Count`** if your network is noisy or experiences frequent transient packet loss. This prevents false alarms.
- **Decrease `Count`** for faster detection of genuine outages.
- **Adjust `Timeout`** based on expected network latency. Lower values detect issues faster but may trigger false positives on slow links.
- **Total wait time** per target is roughly `Count * Timeout` milliseconds when the target is unreachable.
- **Ping interval** (`$interval`) should be shorter than the SvcWatchDog `watchdogTimeout` to ensure heartbeats arrive on time.
