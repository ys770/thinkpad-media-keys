# Builds bin\MediaKey.exe plus Next/Prev/PlayPause copies.
# Uses the C# compiler that ships with Windows (.NET Framework 4.x) - nothing to install.
$ErrorActionPreference = 'Stop'
$csc = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) { throw "C# compiler not found at $csc" }

$bin = Join-Path $PSScriptRoot 'bin'
New-Item -ItemType Directory -Force $bin | Out-Null
& $csc /nologo /target:winexe /optimize "/out:$bin\MediaKey.exe" (Join-Path $PSScriptRoot 'src\MediaKey.cs')
if ($LASTEXITCODE -ne 0) { throw "Build failed" }
foreach ($n in 'Next', 'Prev', 'PlayPause') { Copy-Item "$bin\MediaKey.exe" "$bin\$n.exe" -Force }
Write-Host "Built: $bin"
