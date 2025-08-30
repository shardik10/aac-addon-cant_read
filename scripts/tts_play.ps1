param(
    [string]$voice = "Ash"
)

$baseUrl = "http://100.97.17.9:8080"
$pathFile = '.\to_be_translated.lua'
$logPath = '.\log.txt'

function Send-TTS {
    param(
        [string]$textToSpeak
    )
    $payload = @{ text = $textToSpeak; voice = $voice } | ConvertTo-Json
    try {
        $resp = Invoke-WebRequest -Uri "$baseUrl/tts_clone" -Method Post -Body $payload -ContentType "application/json"
        $tmp = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), '.wav')
        [System.IO.File]::WriteAllBytes($tmp, $resp.Content)
        $player = New-Object System.Media.SoundPlayer $tmp
        $player.PlaySync()
        Remove-Item $tmp -ErrorAction SilentlyContinue
    } catch {
        Write-Host "TTS request failed: $_" -ForegroundColor Red
    }
}

function Invoke-TTS {
    param(
        [string]$text
    )
    $fields = $text -split "\|\|\|\|"
    if ($fields.Length -lt 4) { return }
    $channel = $fields[1]
    $name = $fields[2]
    $message = $fields[3]
    $allowed = @("-3","0","4","6","9","14")
    if ($allowed -notcontains $channel) { return }

    $logLine = "$(Get-Date -Format 'u') [$name]: $message"
    Add-Content -Path $logPath -Value $logLine
    Write-Host $logLine

    Send-TTS -textToSpeak $message
}

# Play startup message to confirm audio
$startupMessage = "Voice audio working"
Add-Content -Path $logPath -Value "$(Get-Date -Format 'u') [System]: $startupMessage"
Write-Host "$(Get-Date -Format 'u') [System]: $startupMessage"
Send-TTS -textToSpeak $startupMessage

if (Test-Path $pathFile) {
    Get-Content -Path $pathFile -Wait -Tail 0 -Encoding UTF8 | ForEach-Object {
        if ($_ -ne "" -and $_ -ne "{" -and $_ -ne "}") {
            Invoke-TTS -text (Get-Content -Path $pathFile -Encoding UTF8)[1]
        }
    }
} else {
    Write-Host "Chat log file not found: $pathFile"
    exit 1
}
