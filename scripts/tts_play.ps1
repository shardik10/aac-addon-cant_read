param(
    [string]$voice = "Ash"
)

$baseUrl = "http://100.97.17.9:8080"
$pathFile = '.\to_be_translated.lua'

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
    $payload = @{ text = $message; voice = $voice } | ConvertTo-Json
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
