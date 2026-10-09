#Requires -RunAsAdministrator
<#
Installs ThinkPad Media Keys.

  -PrevKeyId / -PlayPauseKeyId / -NextKeyId
      Lenovo key IDs (from find-keys.ps1) to turn into media keys via the
      AppLaunch table. Defaults match the ThinkPad P14s Gen 5: F10 (Snipping Tool) = Ex_91.
  -PhoneLinkKey  prev|playpause|next|none   (default: playpause)
      What the Phone Link key (F11 on 2024+ ThinkPads) should do.

Run from an elevated PowerShell *as your own Windows user* (files go to your %LOCALAPPDATA%).
#>
param(
    [string]$PrevKeyId = 'Ex_91',
    [string]$PlayPauseKeyId = '',
    [string]$NextKeyId = '',
    [ValidateSet('prev', 'playpause', 'next', 'none')]
    [string]$PhoneLinkKey = 'playpause'
)
$ErrorActionPreference = 'Stop'
$appName = 'ThinkPad Media Keys'
$dest = Join-Path $env:LOCALAPPDATA 'ThinkPadMediaKeys'
$appLaunch = 'HKLM:\SOFTWARE\Lenovo\ShortcutKey\AppLaunch'
$exeFor = @{ prev = 'Prev.exe'; playpause = 'PlayPause.exe'; next = 'Next.exe' }

# 1. Build and copy binaries
& (Join-Path $PSScriptRoot 'build.ps1')
New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'bin\*.exe') $dest -Force
Write-Host "Installed binaries to $dest"

# 2. AppLaunch overrides (keys like the Snipping Tool key)
$state = Join-Path $dest 'applaunch-ids.txt'
$created = @(Get-Content $state -ErrorAction SilentlyContinue)
$map = [ordered]@{ prev = $PrevKeyId; playpause = $PlayPauseKeyId; next = $NextKeyId }
foreach ($action in $map.Keys) {
    $id = $map[$action]
    if (-not $id) { continue }
    if (-not (Test-Path $appLaunch)) { throw "$appLaunch not found. Is the Lenovo Hotkey driver installed?" }
    if ((Test-Path "$appLaunch\$id") -and ($created -notcontains $id)) {
        Write-Warning "$id is one of Lenovo's own entries - skipping (not overwriting it)."
        continue
    }
    New-Item "$appLaunch\$id\Desktop" -Force | Out-Null
    Set-ItemProperty "$appLaunch\$id" AppType 1 -Type DWord
    Set-ItemProperty "$appLaunch\$id\Desktop" File (Join-Path $dest $exeFor[$action])
    Set-ItemProperty "$appLaunch\$id\Desktop" Parameters ''
    if ($created -notcontains $id) { $created += $id }
    Write-Host "Key $id -> $action"
}
$created | Set-Content $state

# 3. Phone Link key
if ($PhoneLinkKey -ne 'none') {
    # Lenovo only fires the ms-phone: link if the Phone Link app is installed;
    # otherwise it opens a hardcoded Microsoft Store web page.
    $deprov = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Appx\AppxAllUserStore\Deprovisioned\microsoft.yourphone_8wekyb3d8bbwe'
    if (Test-Path "Registry::$deprov") {
        reg export $deprov (Join-Path $dest 'phonelink-deprovisioned-backup.reg') /y | Out-Null
        reg delete $deprov /f | Out-Null
        Write-Host "Removed the 'deprovisioned' block on Phone Link (backup saved in $dest)."
    }
    if (-not (Get-AppxPackage Microsoft.YourPhone)) {
        Write-Host "Installing Phone Link (needed so Lenovo fires the ms-phone: link)..."
        winget install --id 9NMPJ99VJBWV --source msstore --accept-package-agreements --accept-source-agreements
    }

    # Register as an app that can open ms-phone: links
    $progId = 'ThinkPadMediaKeys.ms-phone'
    $cls = "HKCU:\Software\Classes\$progId"
    New-Item "$cls\shell\open\command" -Force | Out-Null
    Set-ItemProperty $cls '(default)' "$appName (ms-phone)"
    Set-ItemProperty "$cls\shell\open\command" '(default)' ('"{0}"' -f (Join-Path $dest $exeFor[$PhoneLinkKey]))
    $cap = 'HKCU:\Software\ThinkPadMediaKeys\Capabilities'
    New-Item "$cap\URLAssociations" -Force | Out-Null
    Set-ItemProperty $cap ApplicationName $appName
    Set-ItemProperty $cap ApplicationDescription 'Turns ThinkPad hotkeys into media keys'
    Set-ItemProperty "$cap\URLAssociations" 'ms-phone' $progId
    if (-not (Test-Path 'HKCU:\Software\RegisteredApplications')) { New-Item 'HKCU:\Software\RegisteredApplications' | Out-Null }
    Set-ItemProperty 'HKCU:\Software\RegisteredApplications' 'ThinkPadMediaKeys' 'Software\ThinkPadMediaKeys\Capabilities'
    Write-Host "Registered '$appName' as an ms-phone: handler -> $PhoneLinkKey"
}

# 4. Start Menu shortcuts (Lenovo Vantage's user-defined key picker lists Start Menu apps)
$programs = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\ThinkPad Media Keys'
New-Item -ItemType Directory -Force $programs | Out-Null
$shell = New-Object -ComObject WScript.Shell
foreach ($p in @(@('Media Previous Track', 'Prev.exe'), @('Media Play Pause', 'PlayPause.exe'), @('Media Next Track', 'Next.exe'))) {
    $s = $shell.CreateShortcut((Join-Path $programs "$($p[0]).lnk"))
    $s.TargetPath = Join-Path $dest $p[1]
    $s.WorkingDirectory = $dest
    $s.Save()
}

Restart-Service TPHKLOAD -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "Done." -ForegroundColor Green
if ($PhoneLinkKey -ne 'none') {
    Write-Host "* Press the Phone Link key once. If Windows asks which app to use, pick '$appName' and tick 'Always'."
    Write-Host "  If Phone Link opens instead, see Troubleshooting in the README."
}
Write-Host "* For the star key (F12): Lenovo Commercial Vantage > User-defined key > Open an app >"
Write-Host "  pick 'Media Next Track' (Start Menu > ThinkPad Media Keys)."
