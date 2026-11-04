# Astro Boy: Omega Factor (gbarecomp) setup.
#
# Builds Astro Boy: Omega Factor as a native Windows program on this PC: it downloads gbarecomp's
# public source and a portable compiler, adds this kit's game configuration, translates YOUR
# cartridge dump's program and compiles it. Nothing from the game or the GBA BIOS is shipped in
# this kit.
#
# Run by AstroBoy.exe when needed; safe to re-run. -Root is the app folder (the one with kit\).
# Your files and everything setup downloads (game\, tools\, build\) go in -Data, which AstroBoy.exe
# sets to %LOCALAPPDATA%\AstroBoy-OmegaFactor-Recomp so app updates leave them alone.
param(
    [Parameter(Mandatory = $true)][string]$Root,
    [string]$Data,
    [string]$Rom,
    [string]$Bios,
    [switch]$Rebuild
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest crawls with a progress bar on PowerShell 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = (Resolve-Path -LiteralPath $Root).Path
if (-not $Data) { $Data = $Root }
New-Item -ItemType Directory -Force -Path $Data | Out-Null
$Data = (Resolve-Path -LiteralPath $Data).Path
$KitVersion = (Get-Content -LiteralPath "$Root\kit\kit-version.txt" -Raw).Trim()   # not version.txt: Quiver owns that file

# Everything downloaded is pinned. Binaries must match their SHA-256; GitHub's source archives are
# pinned by commit and only warn on a different checksum, since GitHub may repack them.
$Pins = @{
    llvm    = @{ Url = 'https://github.com/mstorsjo/llvm-mingw/releases/download/20260616/llvm-mingw-20260616-ucrt-x86_64.zip'
                 Sha = 'b9b68a4d276e16fa25802aaba458e4638f64b3884c290aaccdc2d87083b6ca35'; Dir = 'llvm-mingw' }
    cmake   = @{ Url = 'https://github.com/Kitware/CMake/releases/download/v3.31.12/cmake-3.31.12-windows-x86_64.zip'
                 Sha = '0c4baa40f28b3f8225eb3fdf6946c987b4fe901403b4eaf2fbbd9378100aaa0c'; Dir = 'cmake' }
    ninja   = @{ Url = 'https://github.com/ninja-build/ninja/releases/download/v1.13.2/ninja-win.zip'
                 Sha = '07fc8261b42b20e71d1720b39068c2e14ffcee6396b76fb7a795fb460b78dc65'; Dir = 'ninja' }
    sdl2    = @{ Url = 'https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-devel-2.32.10-mingw.zip'
                 Sha = 'f15cff5fca62ec9381a016ef1d42a95c638cd72d2f226ba5781c76fe43dbd1ac'; Dir = 'sdl2' }
    gbarc   = @{ Url = 'https://codeload.github.com/mstan/gbarecomp/zip/c1a5fda36fb41c2fcba6c901692006ac69d50555'
                 Sha = 'e640b561bce779a536c6574634c6f7d14d46e0cded8768d14956f5ce8c75205f'; Dir = 'gbarecomp-src'; Source = $true }
    armcore = @{ Url = 'https://codeload.github.com/mstan/arm-recomp-core/zip/63dd32dd210a8bf18bbd11933393a7b87f9b3bf6'
                 Sha = '20245b530c3b0dbec7d1b04c9b4dfd88a6d8387e9a6bbf7fc766c3b48d5cd86c'; Dir = 'arm-recomp-core-src'; Source = $true }
    tomlpp  = @{ Url = 'https://codeload.github.com/marzer/tomlplusplus/zip/30172438cee64926dc41fdd9c11fb3ba5b2ba9de'
                 Sha = '0badb114fa26325320cfbcce28b5953f85942d2a0bb1e4fdd99197497afd2ed5'; Dir = 'tomlplusplus-src'; Source = $true }
}
# The configuration is made for this exact cartridge dump and the retail GBA BIOS (gbarecomp runs
# the real BIOS; it has no built-in replacement).
$RomSha1  = '4d652c24979dd7a08ee683b32d1d8986a5511a87'   # Astro Boy: Omega Factor (USA), BTAE
$BiosSha1 = '300c20df6731a33952ded8c436f7f186d25d3492'   # Game Boy Advance BIOS

$kit   = "$Root\kit"
$tools = "$Data\tools"
$dl    = "$tools\downloads"
$build = "$Data\build"
$src   = "$build\src"
$out   = "$build\out"
$game  = "$Data\game"
New-Item -ItemType Directory -Force -Path $tools, $dl, $build, $game, "$game\roms", "$game\bios", "$game\saves" | Out-Null
Start-Transcript -LiteralPath "$Data\setup.log" -Force | Out-Null

function Step([string]$m) { Write-Host ''; Write-Host "== $m" -ForegroundColor Cyan }
# Native tools write progress to stderr; under 'Stop', PowerShell 5.1 would make that fatal.
function Native([scriptblock]$b) { $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'; try { & $b } finally { $ErrorActionPreference = $old } }
function Fail([string]$m) { Write-Host ''; Write-Host "SETUP FAILED: $m" -ForegroundColor Red; Stop-Transcript | Out-Null; exit 1 }
function Sha1([string]$f) { (Get-FileHash -LiteralPath $f -Algorithm SHA1).Hash.ToLower() }

function Pick-File([string]$title, [string]$filter) {
    Add-Type -AssemblyName System.Windows.Forms
    $owner = New-Object System.Windows.Forms.Form -Property @{ TopMost = $true; ShowInTaskbar = $false }
    $dlg = New-Object System.Windows.Forms.OpenFileDialog -Property @{ Title = $title; Filter = $filter }
    try { if ($dlg.ShowDialog($owner) -eq 'OK') { return $dlg.FileName } } finally { $owner.Dispose() }
    return $null
}

# Downloads one pinned zip, checks it and unpacks it into tools\<Dir> (once; a marker records the
# checksum, so a changed pin replaces it). Returns the folder the zip's single top folder became.
function Get-Pinned([string]$key) {
    $p = $Pins[$key]; $dest = "$tools\$($p.Dir)"; $marker = "$dest\.pinned"
    if ((Test-Path -LiteralPath $marker) -and (Get-Content -LiteralPath $marker -Raw).Trim() -eq $p.Sha) { return $dest }
    $zip = "$dl\$key.zip"
    Write-Host "Downloading $($p.Url.Split('/')[-1]) ..."
    Invoke-WebRequest $p.Url -OutFile $zip -UseBasicParsing
    $sha = (Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLower()
    if ($sha -ne $p.Sha) {
        if (-not $p.Source) { Remove-Item -LiteralPath $zip; Fail "The download of $($p.Url) failed its checksum." }
        Write-Host "Note: GitHub repacked this source archive (checksum $sha); it is pinned by commit, continuing." -ForegroundColor Yellow
    }
    if (Test-Path -LiteralPath $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    $tmp = "$dl\$key.x"
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    Native { & "$env:SystemRoot\System32\tar.exe" -xf $zip -C $tmp }
    if ($LASTEXITCODE -ne 0) { Fail "Could not unpack $zip." }
    $items = @(Get-ChildItem -LiteralPath $tmp -Force)
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) { Move-Item -LiteralPath $items[0].FullName -Destination $dest }
    else { Move-Item -LiteralPath $tmp -Destination $dest }
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    Remove-Item -LiteralPath $zip
    Set-Content -LiteralPath $marker -Value $p.Sha
    return $dest
}

# ---------------------------------------------------------------- your files
Step 'Your Astro Boy: Omega Factor cartridge dump'
$romDst = "$game\roms\astroboy_omega_factor_usa.gba"
if (-not $Rom -and (Test-Path -LiteralPath $romDst) -and (Sha1 $romDst) -eq $RomSha1) { Write-Host 'Already in place.' }
else {
    if (-not $Rom) {
        Write-Host 'Choose your Astro Boy: Omega Factor (USA) .gba file.'
        $Rom = Pick-File 'Choose your Astro Boy: Omega Factor (USA) cartridge dump' 'GBA ROM (*.gba)|*.gba|All files (*.*)|*.*'
        if (-not $Rom) { Fail 'No ROM chosen.' }
    }
    $Rom = (Resolve-Path -LiteralPath $Rom).Path
    $s = Sha1 $Rom
    if ($s -ne $RomSha1) {
        Fail "That file is not the Astro Boy: Omega Factor (USA) dump this kit is made for (SHA-1 $s, expected $RomSha1). European and Japanese versions, and patched or trimmed dumps, are not supported."
    }
    Copy-Item -LiteralPath $Rom -Destination $romDst -Force
    Write-Host "ROM: $Rom"
}

Step 'Your Game Boy Advance BIOS'
$biosDst = "$game\bios\gba_bios.bin"
if (-not $Bios -and (Test-Path -LiteralPath $biosDst) -and (Sha1 $biosDst) -eq $BiosSha1) { Write-Host 'Already in place.' }
else {
    if (-not $Bios) {
        Write-Host 'Choose your GBA BIOS dump (usually gba_bios.bin, 16 KB).'
        $Bios = Pick-File 'Choose your Game Boy Advance BIOS (gba_bios.bin)' 'GBA BIOS (*.bin)|*.bin|All files (*.*)|*.*'
        if (-not $Bios) { Fail 'No BIOS chosen.' }
    }
    $Bios = (Resolve-Path -LiteralPath $Bios).Path
    $s = Sha1 $Bios
    if ($s -ne $BiosSha1) { Fail "That file is not the retail GBA BIOS (SHA-1 $s, expected $BiosSha1). The Nintendo DS's GBA BIOS and replacement BIOSes do not work." }
    Copy-Item -LiteralPath $Bios -Destination $biosDst -Force
    Write-Host "BIOS: $Bios"
}
Copy-Item -LiteralPath "$kit\game\game.toml" -Destination "$game\game.toml" -Force

$stamp = "$game\.kit-build"
if (-not $Rebuild -and (Test-Path -LiteralPath "$game\AstroBoyRecomp.exe") -and (Test-Path -LiteralPath $stamp) -and
    (Get-Content -LiteralPath $stamp -Raw).Trim() -eq $KitVersion) {
    Step 'Astro Boy is already built for this kit version.'
    Stop-Transcript | Out-Null; exit 0
}

# ---------------------------------------------------------------- toolchain
Step 'Build tools (portable clang, CMake, Ninja, SDL2; about 1 GB, kept in tools\)'
$llvm  = Get-Pinned 'llvm'
$cmake = "$(Get-Pinned 'cmake')\bin\cmake.exe"
$ninja = "$(Get-Pinned 'ninja')\ninja.exe"
$sdl2  = "$(Get-Pinned 'sdl2')\x86_64-w64-mingw32"
foreach ($f in "$llvm\bin\clang++.exe", $cmake, $ninja, "$sdl2\include\SDL2\SDL.h", "$sdl2\lib\libSDL2.dll.a", "$sdl2\bin\SDL2.dll") {
    if (-not (Test-Path -LiteralPath $f)) { Fail "The build tools are incomplete: $f is missing." }
}

# ---------------------------------------------------------------- source
Step 'gbarecomp source (c1a5fda = v0.4.1, github.com/mstan/gbarecomp) and the Astro Boy configuration'
$gbarc   = Get-Pinned 'gbarc'
$armcore = Get-Pinned 'armcore'
$tomlpp  = Get-Pinned 'tomlpp'
if (Test-Path -LiteralPath $src) { Remove-Item -LiteralPath $src -Recurse -Force }
New-Item -ItemType Directory -Force -Path $src | Out-Null
Copy-Item -LiteralPath "$kit\game\CMakeLists.txt", "$kit\game\game.toml" -Destination $src
Copy-Item -LiteralPath "$kit\game\src" -Destination "$src\src" -Recurse
Copy-Item -LiteralPath $gbarc -Destination "$src\gbarecomp" -Recurse
$coreDst = "$src\gbarecomp\external\arm-recomp-core"
if (Test-Path -LiteralPath $coreDst) { Remove-Item -LiteralPath $coreDst -Recurse -Force }
Copy-Item -LiteralPath $armcore -Destination $coreDst -Recurse
Get-ChildItem -LiteralPath $src -Recurse -Force -Filter '.pinned' | Remove-Item -Force
Copy-Item -LiteralPath $biosDst -Destination "$src\gbarecomp\bios\gba_bios.bin" -Force

# ---------------------------------------------------------------- build
$env:PATH = "$llvm\bin;$(Split-Path -Parent $cmake);$(Split-Path -Parent $ninja);$env:PATH"
# The translated game is ~90 MB of C++, and each compile job can take over 1 GB of memory.
$freeMB = [math]::Floor((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
$jobs = [math]::Max(1, [math]::Min([Environment]::ProcessorCount, [math]::Floor($freeMB / 1200)))
if ($Rebuild -and (Test-Path -LiteralPath $out)) { Remove-Item -LiteralPath $out -Recurse -Force }
$sdlUnix = $sdl2 -replace '\\', '/'
$cfg = @('-S', $src, '-B', $out, '-G', 'Ninja', '-DCMAKE_BUILD_TYPE=Release',
    "-DCMAKE_MAKE_PROGRAM=$ninja", "-DCMAKE_C_COMPILER=$llvm\bin\clang.exe", "-DCMAKE_CXX_COMPILER=$llvm\bin\clang++.exe",
    "-DGBARECOMP_MINGW_PREFIX_UNIX=$sdlUnix", "-DGBARECOMP_TOMLPP_INCLUDE_DIR=$($tomlpp -replace '\\', '/')",
    '-DGBARECOMP_COMPILER_CACHE=OFF', '-DGBARECOMP_STATIC_RELEASE=OFF', '-DBUILD_TESTING=OFF')
function Configure {
    Native { & $cmake @cfg 2>&1 | ForEach-Object { "$_" } | Select-String -Pattern 'gbarecomp:|error|Error' | ForEach-Object { "$_" } }
    if ($LASTEXITCODE -ne 0) { Fail "CMake could not configure the build. See $Data\setup.log." }
}

Step 'Building the translator'
Configure
Native { & $cmake --build $out --target gba_recompile --parallel $jobs 2>&1 | ForEach-Object { "$_" } | Select-String -Pattern 'error:|FAILED' | ForEach-Object { "$_" } }
$recomp = "$out\gbarecomp_build\gba_recompile.exe"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $recomp)) { Fail "The translator did not build. See $Data\setup.log." }

Step 'Translating your BIOS and cartridge into C++'
Native { & $recomp --bios "$src\gbarecomp\bios\gba_bios.bin" --config "$src\gbarecomp\bios\gba_bios.toml" --out "$out\generated_bios" 2>&1 | Select-Object -Last 3 | ForEach-Object { "$_" } }
if ($LASTEXITCODE -ne 0) { Fail "The BIOS translation failed. See $Data\setup.log." }
Native { & $recomp --rom $romDst --config "$src\game.toml" --out "$src\generated" --max-functions 65536 2>&1 | Select-Object -Last 3 | ForEach-Object { "$_" } }
if ($LASTEXITCODE -ne 0) { Fail "The game translation failed. See $Data\setup.log." }

Step "Compiling Astro Boy ($jobs at a time; about 15 to 40 minutes)"
Configure   # gbarecomp decides at configure time whether the translated BIOS is linked in
Native { & $cmake --build $out --target AstroBoyRecomp --parallel $jobs 2>&1 | ForEach-Object { "$_" } | Select-String -Pattern 'error:|FAILED|Linking CXX executable' | ForEach-Object { "$_" } }
$exe = "$out\AstroBoyRecomp.exe"
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) { Fail "Astro Boy did not build. See $Data\setup.log." }

# ---------------------------------------------------------------- install
Step 'Installing'
Copy-Item -LiteralPath $exe -Destination $game -Force
Copy-Item -LiteralPath "$sdl2\bin\SDL2.dll" -Destination $game -Force
foreach ($dll in 'libc++.dll', 'libunwind.dll') { Copy-Item -LiteralPath "$llvm\bin\$dll" -Destination $game -Force }
Set-Content -LiteralPath $stamp -Value $KitVersion
Write-Host ''
Write-Host 'Setup complete. Starting Astro Boy...' -ForegroundColor Green
Stop-Transcript | Out-Null
exit 0
