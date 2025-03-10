@echo off
set LANG=pt

:START
echo Cant Read tradutor de fundo está em execução agora. As traduções começarão a aparecer no jogo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts/google_translate.ps1" -lang %LANG%
if %ERRORLEVEL% NEQ 0 (
    echo An error has been encountered, attempting to restart...
    timeout /t 1 > nul
    goto START
)
echo Cant Read tradutor de fundo agora está fechado.
pause