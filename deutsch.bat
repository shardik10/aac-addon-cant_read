@echo off
set LANG=de

:START
echo Der Cant Read Hintergrundübersetzer läuft jetzt. Übersetzungen werden im Spiel angezeigt.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts/google_translate.ps1" -lang %LANG%
if %ERRORLEVEL% NEQ 0 (
    echo An error has been encountered, attempting to restart...
    timeout /t 1 > nul
    goto START
)
echo Der Cant Read Hintergrundübersetzer ist jetzt geschlossen.
pause