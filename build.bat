@echo off
setlocal EnableDelayedExpansion

set MAIN_EXE_NAME=primordial
set SHADERCOMP_NAME=shadercomp
set BUILD_LABEL=release
set BUILD_LEVEL=speed

set DEBUG_FLAG=
set VET_FLAG=

if "%1" == "debug" (
    set MAIN_EXE_NAME=!MAIN_EXE_NAME!_d
    set BUILD_LABEL=debug
    set BUILD_LEVEL=minimal
    set DEBUG_FLAG=-debug
)

if "%1" == "vet" ( set "VET_FLAG=-vet" )
if "%2" == "vet" ( set "VET_FLAG=-vet" )

set BUILD_DIR=build\!BUILD_LABEL!

for %%d in ( "!BUILD_DIR!" ) do if exist %%~sd rd /s /q "!BUILD_DIR!"
md "!BUILD_DIR!"

<nul set /p build_message=[94mBuilding !BUILD_LABEL! binaries 
if not [!VET_FLAG!] equ [] <nul set /p build_message=(vetted)
echo ...

echo ==========[0m
echo [94mShader compiler:[0m
odin run shadercomp -out:"!BUILD_DIR!\!SHADERCOMP_NAME!.exe" -o:!BUILD_LEVEL! !DEBUG_FLAG! !VET_FLAG! -microarch:native -show-timings
if %ERRORLEVEL% neq 0 (
    echo [91m==========
    echo Build failed ^(shader compiler^)^![0m
    exit /b 1
)

echo [94m==========
echo Main program:[0m
odin build primordial -out:"!BUILD_DIR!\!MAIN_EXE_NAME!.exe" -o:!BUILD_LEVEL! !DEBUG_FLAG! !VET_FLAG! -microarch:native -show-timings
if %ERRORLEVEL% neq 0 (
    echo [91m==========
    echo Build failed ^(Primordial^)^![0m
    exit /b 1
)

echo [94m==========
echo Done.[0m

endlocal
