@echo off
setlocal
set "EDGE=%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" set "EDGE=%ProgramFiles%\Microsoft\Edge\Application\msedge.exe"
if not exist "%EDGE%" (
  echo 未找到 Microsoft Edge。
  pause
  exit /b 1
)
start "Tianyi Edge Extension Test" "%EDGE%" --app="https://cloud.189.cn/" --start-maximized --no-first-run
endlocal
