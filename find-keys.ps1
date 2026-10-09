#Requires -RunAsAdministrator
# Finds the internal Lenovo key IDs of your hotkeys.
#
# Temporarily adds a "probe" entry for every possible ID under
# HKLM\SOFTWARE\Lenovo\ShortcutKey\AppLaunch, restarts the Lenovo hotkey service,
# and logs which IDs fire while you press keys. All probe entries are removed afterwards.
#
# While the probe is active, keys that go through this table do nothing visible
# (that's expected) - including possibly volume/brightness. Everything is restored at the end.
$ErrorActionPreference = 'Stop'
$base = 'HKLM:\SOFTWARE\Lenovo\ShortcutKey\AppLaunch'
if (-not (Test-Path $base)) { throw "$base not found. Is the Lenovo Hotkey driver (fn.inf / TPHKLOAD) installed?" }
if (-not (Get-Service TPHKLOAD -ErrorAction SilentlyContinue)) { throw "TPHKLOAD service not found." }

& (Join-Path $PSScriptRoot 'build.ps1')
$exe = Join-Path $PSScriptRoot 'bin\MediaKey.exe'
$log = Join-Path $PSScriptRoot 'bin\probe.log'
Remove-Item $log -ErrorAction SilentlyContinue

$ids = (0..255 | ForEach-Object { 'Ex_{0:X2}' -f $_ }) + (0..255 | ForEach-Object { '{0:X2}' -f $_ }) + (0..64 | ForEach-Object { "$_" })
$added = New-Object System.Collections.Generic.List[string]
try {
    foreach ($id in ($ids | Select-Object -Unique)) {
        if (Test-Path "$base\$id") { continue }   # never touch Lenovo's own entries
        New-Item "$base\$id\Desktop" -Force | Out-Null
        Set-ItemProperty "$base\$id" AppType 1 -Type DWord
        Set-ItemProperty "$base\$id\Desktop" File $exe
        Set-ItemProperty "$base\$id\Desktop" Parameters "probe $id"
        $added.Add($id)
    }
    Restart-Service TPHKLOAD -Force
    Write-Host ""
    Write-Host "Probe active ($($added.Count) entries)." -ForegroundColor Green
    Write-Host "Press each key you want to identify ONCE, waiting ~5 seconds between keys."
    Write-Host "Write down the order you pressed them in. Then press Enter here."
    [void](Read-Host)
}
finally {
    foreach ($id in $added) { Remove-Item "$base\$id" -Recurse -Force -ErrorAction SilentlyContinue }
    Restart-Service TPHKLOAD -Force
    Write-Host "Probe entries removed, hotkey service restarted."
}

if (Test-Path $log) {
    Write-Host "`nKey IDs that fired (in order):" -ForegroundColor Green
    Get-Content $log
    Write-Host "`nUse these with install.ps1, e.g.:  .\install.ps1 -PrevKeyId Ex_91"
} else {
    Write-Host "`nNo keys went through the AppLaunch table." -ForegroundColor Yellow
    Write-Host "The Phone Link key is handled separately by install.ps1 (see README)."
}
