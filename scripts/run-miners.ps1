# Testnet-10 only. Exactly 20 miners. Restarts a dead slot in place.
# Does not open extra miners past 20.
# kaspa-miner 0.2.5 has no --user-agent-suffix, so the stp grok bot tag is not sent.
# Create C:\kaspa-tn10-miner\STOP to kill only the miner PIDs this script started.

$ErrorActionPreference = 'Continue'
$Root = 'C:\kaspa-tn10-miner'
$Exe = Join-Path $Root 'kaspa-miner.exe'
$StopFile = Join-Path $Root 'STOP'
$PidFile = Join-Path $Root 'miner-pids.txt'
$SupLog = Join-Path $Root 'supervisor.log'
$Target = 20

function Write-Sup([string]$msg) {
  $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
  [System.IO.File]::AppendAllText($SupLog, $line + [Environment]::NewLine)
}

function Save-Pids {
  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($s in $script:slots) {
    if (Test-SlotAlive $s) {
      $lines.Add(('{0}={1}' -f $s.N, $s.Id))
    }
  }
  [System.IO.File]::WriteAllText($PidFile, [string]::Join([Environment]::NewLine, $lines.ToArray()))
}

function Test-SlotAlive($slot) {
  if ($null -eq $slot -or $slot.Id -le 0) { return $false }
  $live = Get-Process -Id $slot.Id -ErrorAction SilentlyContinue
  return ($null -ne $live -and $live.ProcessName -eq 'kaspa-miner')
}

function Start-MinerSlot([int]$n) {
  $log = Join-Path $Root ('miner{0}.log' -f $n)
  $hist = Join-Path $Root ('miner{0}.history.log' -f $n)
  $stdout = Join-Path $Root ('miner{0}.stdout.log' -f $n)
  if (Test-Path $log) {
    try {
      [System.IO.File]::AppendAllText($hist, [System.IO.File]::ReadAllText($log))
      Remove-Item $log -Force -ErrorAction Stop
    } catch {
      Write-Sup ('slot {0} log busy; left the existing process alone' -f $n)
      return $null
    }
  }
  if (Test-Path $stdout) {
    Remove-Item $stdout -Force -ErrorAction SilentlyContinue
  }

  $proc = Start-Process -FilePath $Exe -ArgumentList @(
    '--testnet',
    '-s', 'grpc://[tunnel]',
    '-p', '3567',
    '-t', '1',
    '--mine-when-not-synced',
    '-a', '[address]'
  ) -WorkingDirectory $Root -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $log

  $started = Get-Date
  try { $started = $proc.StartTime } catch {}
  return [pscustomobject]@{ N = $n; Id = [int]$proc.Id; Started = $started }
}

function Stop-TrackedMiners {
  foreach ($s in @($script:slots)) {
    if (-not (Test-SlotAlive $s)) { continue }
    $live = Get-Process -Id $s.Id -ErrorAction SilentlyContinue
    $same = $false
    if ($live -and $live.ProcessName -eq 'kaspa-miner') {
      try { $same = ([math]::Abs(($live.StartTime - $s.Started).TotalSeconds) -lt 3) } catch { $same = $true }
    }
    if ($same) {
      Stop-Process -Id $s.Id -Force -ErrorAction SilentlyContinue
      Write-Sup ('stopped slot {0} pid {1}' -f $s.N, $s.Id)
    } else {
      Write-Sup ('skipped slot {0} pid {1}; process identity did not match' -f $s.N, $s.Id)
    }
  }
}

if (Test-Path $StopFile) {
  Write-Sup 'STOP present at launch; exiting without starting miners'
  exit 0
}
if (-not (Test-Path $Exe)) {
  Write-Sup "missing $Exe"
  exit 1
}

$gotMutex = $false
$mutex = New-Object System.Threading.Mutex($false, 'Local\kaspa-tn10-miner-supervisor')
try {
  $gotMutex = $mutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
  $gotMutex = $true
}
if (-not $gotMutex) {
  Write-Sup 'another supervisor already holds the lock; exiting'
  exit 1
}

$script:slots = New-Object System.Collections.Generic.List[object]
try {
  Set-Location $Root
  Write-Sup ('supervisor pid {0} target {1}' -f $PID, $Target)
  for ($n = 1; $n -le $Target; $n++) {
    $slot = Start-MinerSlot -n $n
    if ($null -ne $slot) {
      $script:slots.Add($slot)
      Write-Sup ('started slot {0} pid {1}' -f $n, $slot.Id)
    }
    Start-Sleep -Milliseconds 250
  }
  Save-Pids

  while ($true) {
    Start-Sleep -Seconds 30
    if (Test-Path $StopFile) {
      Write-Sup 'STOP file seen; stopping tracked miners'
      Stop-TrackedMiners
      [System.IO.File]::WriteAllText($PidFile, '')
      Write-Sup 'supervisor exit after STOP'
      break
    }
    for ($i = 0; $i -lt $script:slots.Count; $i++) {
      $s = $script:slots[$i]
      if ($s.N -gt $Target) { continue }
      if (Test-SlotAlive $s) { continue }
      Write-Sup ('slot {0} pid {1} is gone; restarting' -f $s.N, $s.Id)
      $fresh = Start-MinerSlot -n $s.N
      if ($null -ne $fresh) {
        $script:slots[$i] = $fresh
        Write-Sup ('restarted slot {0} pid {1}' -f $fresh.N, $fresh.Id)
      }
    }
    # Fill any slot number that never started. Never go past 20.
    $have = @{}
    foreach ($s in $script:slots) { if (Test-SlotAlive $s) { $have[$s.N] = $true } }
    for ($n = 1; $n -le $Target; $n++) {
      if ($have.ContainsKey($n)) { continue }
      $fresh = Start-MinerSlot -n $n
      if ($null -ne $fresh) {
        $script:slots.Add($fresh)
        Write-Sup ('filled slot {0} pid {1}' -f $fresh.N, $fresh.Id)
      }
    }
    Save-Pids
    $alive = 0
    foreach ($s in $script:slots) { if (Test-SlotAlive $s) { $alive++ } }
    Write-Sup ('alive {0} of {1}' -f $alive, $Target)
  }
} finally {
  if ($gotMutex) {
    try { $mutex.ReleaseMutex() } catch {}
  }
  try { $mutex.Dispose() } catch {}
}
