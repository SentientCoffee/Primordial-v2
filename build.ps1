param (
    [switch]$Debug = $false,
    [switch]$Vet   = $false
)

$EXE_NAME    = "primordial"
$BUILD_LABEL = "release"
$BUILD_LEVEL = "speed"

$DEBUG_FLAG = ""
$VET_FLAG   = ""

if ($Debug) {
    $EXE_NAME = $EXE_NAME + "_d"
    $BUILD_LABEL = "debug"
    $BUILD_LEVEL = "minimal"
    $DEBUG_FLAG = "-debug"
}

if ($Vet) {
    $VET_FLAG = "-vet"
}

$BUILD_DIR = "build\" + $BUILD_LABEL

if (Test-Path -Path $BUILD_DIR) {
    Get-ChildItem -Path $BUILD_DIR -Recurse | Remove-Item -Force -Recurse
    Remove-Item $BUILD_DIR -Force
}
$null = New-Item -Path $BUILD_DIR -type Directory

$message = "Building $BUILD_LABEL binary"
if ($Vet) { $message += " (vetted)" }
$message += "..."
Write-Host "$message`n=========="

odin build primordial -out:"$BUILD_DIR\$EXE_NAME.exe" -o:$BUILD_LEVEL $DEBUG_FLAG $VET_FLAG -microarch:native -show-timings
if (! $?) {
    Write-Host "==========`nFailed!"
    Exit 1
}

Write-Host "==========`nDone."
