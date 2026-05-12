@echo off
REM =====================================================================
REM  The Wisdom Project - Windows desktop launcher (Flutter native)
REM
REM  Usage:
REM    run.bat              debug build (hot reload, slower)
REM    run.bat --debug      same as above
REM    run.bat --release    release build (faster, no hot reload)
REM
REM  Requires Visual Studio Build Tools with the "Desktop development
REM  with C++" workload and `flutter config --enable-windows-desktop`.
REM =====================================================================

setlocal

REM --- Default mode ----------------------------------------------------
set "MODE=--debug"
if /I "%~1"=="--debug"   set "MODE=--debug"
if /I "%~1"=="--release" set "MODE=--release"
if not "%~1"=="" if /I not "%~1"=="--debug" if /I not "%~1"=="--release" goto :bad_arg

REM --- Project root is two levels up: scripts\windows\ -> scripts\ -> project
cd /d "%~dp0..\.."

echo Running on Windows (%MODE%)...
flutter run -d windows %MODE%
goto :eof

:bad_arg
echo Unknown option: %~1
echo Usage: run.bat [--debug ^| --release]
exit /b 1
