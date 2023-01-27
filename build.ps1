param (
    [string]$Target = "all",
    [switch]$Debug  = $false,
    [switch]$Vet    = $false
)

$MAIN_EXE_NAME   = "primordial"
$SHADERCOMP_NAME = "shadercomp"
$BUILD_LABEL     = "release"
$BUILD_LEVEL     = "speed"

$DEBUG_FLAG = ""
$VET_FLAG   = ""

if ($Debug) {
    $MAIN_EXE_NAME   += "_d"
    $SHADERCOMP_NAME += "_d"
    $BUILD_LABEL      = "debug"
    $BUILD_LEVEL      = "minimal"
    $DEBUG_FLAG       = "-debug"
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

$message = "Building $BUILD_LABEL binaries"
if ($Vet) { $message += " (vetted)" }
$message += "..."
Write-Host -ForegroundColor Blue "$message"

if ($Target -eq "shadercomp" -or $Target -eq "all") {
    Write-Host -ForegroundColor Blue "==========`nShader compiler:"

    if (Test-Path -Path "build\shader_cache") {
        Write-Host -ForegroundColor Blue "Removing existing shader cache..."
        Remove-Item -Force -Recurse "build\shader_cache"
    }

    Write-Host -ForegroundColor Blue "Compiling new shaders..."
    odin run shadercomp -out:"$BUILD_DIR\$SHADERCOMP_NAME.exe" -o:$BUILD_LEVEL $DEBUG_FLAG $VET_FLAG -microarch:native -show-timings
    if (! $?) {
        Write-Host -ForegroundColor Red "==========`nBuild failed (shader compiler)!"
        Exit 1
    }
}


if ($Target -eq "primordial" -or $Target -eq "all") {
    Write-Host -ForegroundColor Blue "==========`nPrimordial:"
    odin build primordial -out:"$BUILD_DIR\$MAIN_EXE_NAME.exe" -o:$BUILD_LEVEL $DEBUG_FLAG $VET_FLAG -microarch:native -show-timings
    if (! $?) {
        Write-Host -ForegroundColor Red "==========`nBuild failed (Primordial)!"
        Exit 1
    }
}

Write-Host -ForegroundColor Blue "==========`nBuild successful."
