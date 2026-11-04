# Builds AstroBoy.exe and the release zip: dist\AstroBoy-OmegaFactor-Recomp-v<version>-windows-x64.zip
# Needs an llvm-mingw (or other MinGW-w64) clang. Usage: powershell -File tools\package.ps1 [-Clang C:\llvm-mingw\bin\clang.exe]
param([string]$Clang = 'clang.exe')
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$version = (Get-Content -LiteralPath "$repo\kit\kit-version.txt" -Raw).Trim()
$stage = "$repo\dist\stage"
$zip = "$repo\dist\AstroBoy-OmegaFactor-Recomp-v$version-windows-x64.zip"

if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
& $Clang -O2 -std=c11 -Wall -Wextra -municode -mwindows -static "-DKIT_VER=$version" `
    "$repo\launcher\astroboy_launcher.c" -o "$stage\AstroBoy.exe"
if ($LASTEXITCODE -ne 0) { throw 'launcher build failed' }

Copy-Item -LiteralPath "$repo\kit" -Destination "$stage\kit" -Recurse
Copy-Item -LiteralPath "$repo\README.md", "$repo\LICENSE" -Destination $stage

if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip }
# Windows' tar writes forward-slash zip paths (PowerShell 5.1's Compress-Archive writes backslashes).
& "$env:SystemRoot\System32\tar.exe" -a -c -f $zip -C $stage AstroBoy.exe kit README.md LICENSE
if ($LASTEXITCODE -ne 0) { throw 'zip failed' }
Get-Item -LiteralPath $zip | Select-Object Name, Length
