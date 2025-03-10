@echo off
set LANG=sv

:START
echo Cant Read background translator is now running. Translations will begin appearing in game.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts/google_translate.ps1" -lang %LANG%
if %ERRORLEVEL% NEQ 0 (
    echo An error has been encountered, attempting to restart...
    timeout /t 1 > nul
    goto START
)
echo Cant Read background translator is now closed.
pause