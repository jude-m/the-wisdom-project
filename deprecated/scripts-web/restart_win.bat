@echo off
REM =====================================================================
REM  The Wisdom Project - Windows server restart helper
REM
REM  Use this after the Mac has rsynced a fresh build. Kills the running
REM  dart.exe process and launches run_win.bat in a new cmd window.
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
REM Use `ping` instead of `timeout` because `timeout` reads stdin and
REM fails under SSH with "Input redirection is not supported".
ping 127.0.0.1 -n 3 >nul 2>&1

echo Launching run_win.bat (detached)...
REM Spawn via WMI (Win32_Process::Create) instead of `start`. When this
REM script is invoked over SSH, sshd attaches every child to a job object
REM and kills the whole job on session close — so a `start`-spawned cmd
REM window dies the moment the SSH connection ends. WMI launches the new
REM process under the winmgmt service, outside sshd's job, so it survives.
powershell -NoProfile -Command "Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{CommandLine='cmd.exe /c \"%~dp0run_win.bat\"'} | Out-Null"

echo Done.
endlocal
