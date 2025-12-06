
filter Logger { "$(Get-Date -Format G): $_" | Out-File -Append "log\\WindowsPinger.log" }

# Configuration: Ping entries
$pingEntries = @(
    @{ Name = "Google DNS"; Address = "8.8.8.8"; Timeout = 1000; Count = 3; State = "Unknown"; LastChange = $null },
    @{ Name = "Cloudflare DNS"; Address = "1.1.1.1"; Timeout = 1000; Count = 3; State = "Unknown"; LastChange = $null },
    @{ Name = "Local Gateway"; Address = "192.168.1.1"; Timeout = 500; Count = 6; State = "Unknown"; LastChange = $null }
    @{ Name = "UbuntuDev"; Address = "10.255.254.150"; Timeout = 500; Count = 2; State = "Unknown"; LastChange = $null }
)

# Interval between pings in seconds, note that this also affects the SvcWatchdog UDP ping interval, so it should be
# less than the watchdog timeout
$interval = 10

# Get the UDP packet details from environment variables
$watchdogSecret = $env:WATCHDOG_SECRET
$watchdogPort = $env:WATCHDOG_PORT
if (-not $watchdogSecret -or -not $watchdogPort) {
    "WATCHDOG_SECRET or WATCHDOG_PORT environment variable is not set. Continuing without watchdog." | Logger
}
else {
    $port = [int]$watchdogPort
    "sending UDP ping packets to 127.0.0.1:'$watchdogPort'..."  | Logger
}

# Create a UDP client
$udpClient = New-Object System.Net.Sockets.UdpClient

# Get the event name from the environment variable SHUTDOWN_EVENT
$shutdownEventName = $env:SHUTDOWN_EVENT
if ($shutdownEventName) {
    "Monitoring the Win32 event named '$shutdownEventName'..."  | Logger
    # Open the Win32 event
    try {
        $eventHandle = [System.Threading.EventWaitHandle]::OpenExisting($shutdownEventName)
    }
    catch {
        "Failed to open the event '$shutdownEventName'. Please ensure it exists. Exiting." | Logger
        exit 1
    }
}
else {
    "SHUTDOWN_EVENT environment variable not set, continuing forever."  | Logger
}

 
while ($true) {
    if (-not $shutdownEventName) {
        Start-Sleep -Seconds $interval
    }
    # else wait for the event to be signaled, timeout after 10 seconds
    elseif ($eventHandle.WaitOne($interval * 1000)) {
        "Event '$shutdownEventName' was signaled. Exiting the loop." | Logger
        break
    }

    # Test case: increase interval so it gradually becomes too long so the watchdog restarts the service
    # $interval += 1

    # Ping each entry and track state changes
    $currentTime = Get-Date
    foreach ($entry in $pingEntries) {
        # Try to ping up to Count times, stop if successful
        $pingResult = $false
        for ($i = 1; $i -le $entry.Count; $i++) {
            $result = Get-WmiObject -Class Win32_PingStatus -Filter "Address = '$($entry.Address)' AND Timeout = $($entry.Timeout)"
            if ($result.StatusCode -eq 0) {
                $pingResult = $true
                break
            }
        }
        $newState = if ($pingResult) { "Accessible" } else { "Inaccessible" }
        
        if ($entry.State -ne $newState) {
            # State changed - log it
            $oldState = $entry.State
            
            if ($oldState -eq "Unknown") {
                # First check - log without interval
                "[$($entry.Name)] $($entry.Address) is $newState" | Logger
            }
            else {
                # Calculate time interval since last change
                $timeSpan = $currentTime - $entry.LastChange
                $duration = "{0:hh\:mm\:ss}" -f $timeSpan
                
                if ($newState -eq "Accessible") {
                    "[$($entry.Name)] $($entry.Address) is now Accessible (was Inaccessible for $duration)" | Logger
                }
                else {
                    "[$($entry.Name)] $($entry.Address) is now Inaccessible (was Accessible for $duration)" | Logger
                }
            }
            
            # Update state
            $entry.State = $newState
            $entry.LastChange = $currentTime
        }
    }

    if ($watchdogSecret -and $watchdogPort) {
        # Send the UDP packet
        $data = [System.Text.Encoding]::UTF8.GetBytes($watchdogSecret)
        $udpClient.Send($data, $data.Length, "127.0.0.1", $port) | Out-Null
    }
}

# Dispose the UDP client
$udpClient.Close()

"Script execution completed." | Logger