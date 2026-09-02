@echo off
setlocal
set "PS1=%~dp0RdpCoexist.ps1"
net session >nul 2>&1
if %errorlevel%==0 (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%" %*
) else (
    echo Requesting administrator elevation...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File','%PS1%' %*"
)
endlocal
