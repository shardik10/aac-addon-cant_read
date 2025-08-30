@echo off
set VOICE=%1
if "%VOICE%"=="" set VOICE=Ash

:START
echo Cant Read TTS playback is now running.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "scripts/tts_play.ps1" -voice "%VOICE%"
if %ERRORLEVEL% NEQ 0 (
    echo An error has been encountered, attempting to restart...
    timeout /t 1 > nul
    goto START
)
echo Cant Read TTS playback is now closed.
pause
