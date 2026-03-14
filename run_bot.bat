@echo off
setlocal
cd /d "%~dp0"
echo Launching iFutures Trading Bot...
start "" "build\windows\x64\runner\Release\ifutures.exe"
endlocal
pause
