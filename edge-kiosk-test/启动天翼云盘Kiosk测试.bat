@echo off
setlocal
clear 2>nul
set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" set "EDGE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" (
  echo 未找到 Microsoft Edge。
  pause
  exit /b 1
)
start "Tianyi Edge Kiosk Test" "%EDGE%" --kiosk "https://cloud.189.cn/" --edge-kiosk-type=fullscreen --no-first-run
endlocal
