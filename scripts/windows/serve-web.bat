@echo off
REM =====================================================================
REM  The Wisdom Project - Windows server launcher
REM
REM  Usage:
REM    serve-web.bat            starts on port 8081
REM    serve-web.bat 9000       starts on the given port
REM
REM  Deployed by scripts/deploy-web.sh from the Mac. Place a shortcut to
REM  this file in the Windows Startup folder (Win+R -> shell:startup) so
REM  the server starts at login.
REM =====================================================================

setlocal

REM --- Default port (8080 is taken on this box, so use 8081) -----------
set "PORT=8081"
if not "%~1"=="" set "PORT=%~1"

REM --- Always run relative to this script's folder ---------------------
cd /d "%~dp0"

REM --- 1. Confirm Dart SDK is available --------------------------------
where dart >nul 2>nul
if errorlevel 1 goto :no_dart

REM --- 2. Confirm sqlite3.dll is present -------------------------------
REM The package:sqlite3 Dart package loads a native DLL at runtime.
REM On Windows we expect it next to the server executable.
if not exist "server\sqlite3.dll" goto :no_dll
goto :dll_ok

:no_dll
echo.
echo [WARNING] server\sqlite3.dll not found.
echo The server will fail when it tries to open a database.
echo.
echo Fix:
echo   1. Download the "Precompiled Binaries for Windows" zip
echo      from https://sqlite.org/download.html
echo   2. Extract sqlite3.dll into the server\ folder.
echo   3. Re-run this script.
echo.

:dll_ok

REM --- 3. First-run: install server dependencies -----------------------
if exist "server\.dart_tool" goto :deps_ok
echo Installing server dependencies for the first run...
pushd server
call dart pub get
if errorlevel 1 goto :pub_fail
popd
echo.

:deps_ok

REM --- 4. Start the server ---------------------------------------------
echo =====================================================================
echo  Starting The Wisdom Project server on port %PORT%
echo  Local:   http://localhost:%PORT%
echo  LAN:     http://192.168.1.200:%PORT%
echo  Press Ctrl+C to stop.
echo =====================================================================
echo.

cd server
dart run bin\server.dart --assets ..\assets --web-root ..\build\web --port %PORT%
goto :eof

:no_dart
echo.
echo [ERROR] Dart SDK not found in PATH.
echo Install from https://dart.dev/get-dart
echo Then close this window, open a new Command Prompt, and try again.
echo.
exit /b 1

:pub_fail
echo [ERROR] dart pub get failed.
popd
exit /b 1
