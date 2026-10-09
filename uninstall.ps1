#Requires -RunAsAdministrator
# Removes everything install.ps1 added. Leaves Phone Link installed and does not
# restore the Phone Link "deprovisioned" block (a backup .reg is kept if you want it back).
$ErrorActionPreference = 'Continue'
$dest = Join-Path $env:LOCALAPPDATA 'ThinkPadMediaKeys'
$appLaunch = 'HKLM:\SOFTWARE\Lenovo\ShortcutKey\AppLaunch'

$state = Join-Path $dest 'applaunch-ids.txt'
foreach ($id in @(Get-Content $state -ErrorAction SilentlyContinue | Where-Object { $_ })) {
    Remove-Item "$appLaunch\$id" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Removed AppLaunch override $id"
}

Remove-Item 'HKCU:\Software\Classes\ThinkPadMediaKeys.ms-phone' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\ThinkPadMediaKeys' -Recurse -Force -ErrorAction SilentlyContinue
Remove-ItemProperty 'HKCU:\Software\RegisteredApplications' 'ThinkPadMediaKeys' -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\ThinkPad Media Keys') -Recurse -Force -ErrorAction SilentlyContinue

$backup = Join-Path $dest 'phonelink-deprovisioned-backup.reg'
if (Test-Path $backup) {
    $keep = Join-Path $env:USERPROFILE 'phonelink-deprovisioned-backup.reg'
    Copy-Item $backup $keep -Force
    Write-Host "Kept Phone Link deprovision backup at $keep"
}
Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue

Restart-Service TPHKLOAD -Force -ErrorAction SilentlyContinue
Write-Host "Uninstalled. If you set the star key in Lenovo Vantage, change it back there."
