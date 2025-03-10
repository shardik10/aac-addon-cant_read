@echo off
set LANG=fr

:START
echo Cant Read traducteur d'arrière-plan est désormais en cours d'exécution. Les traductions commenceront à apparaître dans le jeu.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts/google_translate.ps1" -lang %LANG%
if %ERRORLEVEL% NEQ 0 (
    echo An error has been encountered, attempting to restart...
    timeout /t 1 > nul
    goto START
)
echo Cant Read traducteur d'arrière-plan est désormais fermé.
pause