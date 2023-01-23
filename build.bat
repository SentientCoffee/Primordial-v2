@echo off
setlocal EnableDelayedExpansion

set EXE_NAME=primordial
set BUILD_LABEL=release
set BUILD_LEVEL=speed

set DEBUG_FLAG=
set VET_FLAG=

if "%1" == "debug" (
    set EXE_NAME=!EXE_NAME!_d
    set BUILD_LABEL=debug
    set BUILD_LEVEL=minimal
    set DEBUG_FLAG=-debug
)

if "%1" == "vet" ( set "VET_FLAG=-vet" )
if "%2" == "vet" ( set "VET_FLAG=-vet" )

set BUILD_DIR=build\!BUILD_LABEL!

for %%d in ( "!BUILD_DIR!" ) do if exist %%~sd rd /s /q "!BUILD_DIR!"
md "!BUILD_DIR!"

<nul set /p build_message=Building !BUILD_LABEL! binary 
if not [!VET_FLAG!] equ [] <nul set /p build_message=(vetted)
echo ...
echo ==========

odin build primordial -out:"!BUILD_DIR!\!EXE_NAME!.exe" -o:!BUILD_LEVEL! !DEBUG_FLAG! !VET_FLAG! -microarch:native -show-timings || (
    echo ==========
    echo Failed!
    exit 1
)

echo ==========
echo Done.

endlocal
