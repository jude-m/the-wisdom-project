@echo off
REM =====================================================================
REM  The Wisdom Project - Windows server restart helper
REM
REM  Use this after the Mac has rsynced a fresh build. Kills the running
REM  dart.exe process and launches serve-web.bat in a new cmd window.
REM
REM  Caveat: if you have other Dart processes running on this machine,
REM  they will also be killed. For this box (dedicated to the server),
REM  that is fine.
REM =====================================================================

setlocal

REM --- Always run relative to this script's folder ---------------------
cd /d "%~dp0"

echo Stopping existing dart.exe processes...
taskkill /F /IM dart.exe >nul 2>&1
if errorlevel 1 (
    echo   ^(nothing was running^)
) else (
    echo   stopped.
)

REM Small pause so the OS releases the port before we rebind.
timeout /t 2 /nobreak >nul

echo Launching serve-web.bat in a new window...
start "Wisdom Server" "%~dp0serve-web.bat"

echo Done.
endlocal
