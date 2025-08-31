param(
    [string]$voice    = "Ash",  # Default voice (override later if needed)
    [string]$language = "en"     # XTTS language code
)
# -------- Noise filter (item-code) --------
# Consider a message "noise" if it contains any super-long unbroken token, or matches
# the common 'i12345,9,1,<HUUUGE ALPHANUM STRING>' pattern.
$Noise_LongTokenLen   = 80     # any single token this long is considered noise
$Noise_MinTotalLen    = 120    # overall min length to trigger density check
$Noise_MinNoSpaceFrac = 0.90   # ≥90% non-space characters => likely noise

# -------- Config --------
$baseUrl         = "http://100.97.17.9:8080"
$endpoint        = "/tts_clone"
$voicesEndpoint  = "/voices"
$pathFile        = ".\to_be_translated.lua"
$logPath         = ".\log.txt"
$voicesLogPath   = ".\endpoints.log"
$DebugMode       = $false

# Channels to speak
$AllowedChannels = @("-3","0","2","3","4","5","6","7","8","9","14")

# Discovery toggles
$AllowAllChannels      = $true
$DiscoverUnknowns      = $true
$UnknownChannelLogPath = ".\unknown_channels.log"

# -------- Queue plumbing --------
$script:MsgQueue   = [System.Collections.Queue]::new()
$script:IsDraining = $false

# -------- Helpers --------

function Test-ItemCodeNoise([string]$s) {
    if ([string]::IsNullOrWhiteSpace($s)) { return $false }
    $t = $s.Trim()
    if ($t.Length -lt 40) { return $false }

    # A) very long unbroken token (e.g., massive code)
    foreach ($tok in ($t -split '\s+')) {
        if ($tok.Length -ge $Noise_LongTokenLen) { return $true }
    }

    # B) pattern like: WTS i20856,9,1,<really long alphanum + punctuation run...>
    if ($t -match '\bi\d{4,},\d+,\d+,[0-9A-Za-z\*\;\,\-_]{60,}') { return $true }


    # C) high density of non-space chars (codes pasted with almost no spaces)
    $nospace = ($t -replace '\s','')
    if ($t.Length -ge $Noise_MinTotalLen -and ($nospace.Length / [double]$t.Length) -ge $Noise_MinNoSpaceFrac) {
        return $true
    }

    return $false
}



function Join-Url([string]$base, [string]$path) {
    if ([string]::IsNullOrWhiteSpace($base)) { return $path }
    if ($base.EndsWith('/')) { $base = $base.TrimEnd('/') }
    if (-not $path.StartsWith('/')) { $path = "/$path" }
    return "$base$path"
}
$voicesUrl = Join-Url $baseUrl $voicesEndpoint
$ttsUrl    = Join-Url $baseUrl $endpoint

function Write-Log([string]$line, [ConsoleColor]$Color = [ConsoleColor]::Gray) {
    $stamp = Get-Date -Format 'u'
    $out   = "$stamp $line"
    try { Add-Content -Path $logPath -Value $out -Encoding UTF8 } catch {}
    Write-Host $out -ForegroundColor $Color
}

function Debug-Drop($why, $raw) {
    if ($DebugMode) {
        Write-Log "[DROP: $why] $raw" DarkYellow
    }
}

# -------- Voice Discovery --------
$script:AvailableVoices = @()
try {
    $voices = Invoke-RestMethod -Uri $voicesUrl -Method GET -TimeoutSec 10
    if ($voices -is [System.Collections.IEnumerable]) {
        $script:AvailableVoices = @($voices | ForEach-Object { $_.name } | Where-Object { $_ })
        $header = "$(Get-Date -Format 'u') Available Voices:"
        $voiceList = $script:AvailableVoices -join ", "
        Add-Content -Path $voicesLogPath -Value "$header $voiceList" -Encoding UTF8
        Write-Host $header -ForegroundColor Cyan
        Write-Host $voiceList -ForegroundColor Green

        if ($script:AvailableVoices.Count -gt 0 -and ($script:AvailableVoices -notcontains $voice)) {
            $old = $voice
            $voice = $script:AvailableVoices[0]
            Add-Content -Path $voicesLogPath -Value "$(Get-Date -Format 'u') Requested voice '$old' not found. Falling back to '$voice'." -Encoding UTF8
            Write-Host "Voice '$old' not found. Using '$voice'." -ForegroundColor Yellow
        }
    } else {
        Add-Content -Path $voicesLogPath -Value "$(Get-Date -Format 'u') Unexpected /voices response." -Encoding UTF8
    }
} catch {
    Add-Content -Path $voicesLogPath -Value "$(Get-Date -Format 'u') Failed to query /voices: $_" -Encoding UTF8
}

# [Rest of script remains unchanged, with careful fixes]

function Enqueue-Message([string]$m) {
    $script:MsgQueue.Enqueue($m)
    if ($DebugMode) {
        Write-Host ("[queue={0}]" -f $script:MsgQueue.Count) -ForegroundColor DarkGray
    }
}

function Drain-Queue {
    if ($script:IsDraining) { return }
    $script:IsDraining = $true
    try {
        while ($script:MsgQueue.Count -gt 0) {
            $next = [string]$script:MsgQueue.Dequeue()
            Send-TTS -textToSpeak $next
        }
    } finally {
        $script:IsDraining = $false
    }
}

$script:UnknownChannelCounts = @{}
function Track-UnknownChannel([string]$channel, [string]$name, [string]$message) {
    if (-not $DiscoverUnknowns) { return }
    if (-not $script:UnknownChannelCounts.ContainsKey($channel)) {
        $script:UnknownChannelCounts[$channel] = 0
    }
    $script:UnknownChannelCounts[$channel]++

    $stamp = Get-Date -Format 'u'
    $preview = if ($message.Length -gt 120) { $message.Substring(0,120) + "…" } else { $message }
    $line = "$stamp channel=$channel name=$name msg=$preview"
    try { Add-Content -Path $UnknownChannelLogPath -Value $line -Encoding UTF8 } catch {}
    if ($DebugMode) { Write-Host "[DISCOVER] $line" -ForegroundColor DarkYellow }
}

function Clean-ChatMessage([string]$msg) {
    if ([string]::IsNullOrWhiteSpace($msg)) { return $msg }
    $m = $msg.Trim()
    if ($m -eq '{' -or $m -eq '}') { return "" }
    if ($m.StartsWith('"') -and $m.EndsWith('"')) {
        $m = $m.Substring(1, $m.Length - 2)
    }
    $m = $m -replace '(?:\|\|\|\|)+"?\s*,?\s*$', ''
    $m = $m -replace '"\s*,?\s*$', ''
    $m = $m -replace '^\s*"', ''
    $m = $m -replace '\|\|\|\|\s*$', ''
    # collapse REAL newlines/tabs
    $m = $m -replace '\r?\n', ' ' -replace '\t', ' '
    # collapse ESCAPED sequences too (literal \r \n \t)
    $m = $m -replace '\\r?\\n', ' ' -replace '\\t', ' '
    $m = $m -replace '\s{2,}', ' '
    return $m.Trim()
}

function Split-ForTTS([string]$text, [int]$maxLen = 240) {
    $t = $text.Trim()
    if ($t.Length -le $maxLen) { return ,$t }

    $segs = [System.Text.RegularExpressions.Regex]::Split($t, '([\.!\?;]+)\s+')
    $builder = New-Object System.Text.StringBuilder
    $chunks  = New-Object System.Collections.Generic.List[string]

    for ($i=0; $i -lt $segs.Count; $i+=2) {
        $seg = $segs[$i]
        $pun = if ($i + 1 -lt $segs.Count) { $segs[$i+1] } else { "" }
        $add = ($seg + $pun).Trim()
        if ($add.Length -eq 0) { continue }

        if (($builder.Length + $add.Length + 1) -le $maxLen) {
            if ($builder.Length -gt 0) { [void]$builder.Append(' ') }
            [void]$builder.Append($add)
        } else {
            if ($builder.Length -gt 0) {
                $chunks.Add($builder.ToString().Trim())
                $builder.Clear() | Out-Null
            }
            if ($add.Length -le $maxLen) {
                $chunks.Add($add)
            } else {
                for ($p=0; $p -lt $add.Length; $p += $maxLen) {
                    $len = [Math]::Min($maxLen, $add.Length - $p)
                    $chunks.Add($add.Substring($p, $len).Trim())
                }
            }
        }
    }
    if ($builder.Length -gt 0) { $chunks.Add($builder.ToString().Trim()) }
    return $chunks.ToArray()
}

function Send-TTS {
    param(
        [Parameter(Mandatory=$true)][string]$textToSpeak,
        [int]$maxRetries = 3
    )

    $parts = Split-ForTTS $textToSpeak 240
    foreach ($part in $parts) {
        $msg = $part.Trim()
        if ([string]::IsNullOrWhiteSpace($msg)) { continue }

        $attempt = 0
        $delay   = 1
        $done    = $false

        while (-not $done -and $attempt -lt $maxRetries) {
            $attempt++
            $tmp = [System.IO.Path]::ChangeExtension([System.IO.Path]::GetTempFileName(), ".wav")
            try {
                $body = ("text={0}&voice_name={1}&language={2}" -f `
                    [uri]::EscapeDataString($msg),
                    [uri]::EscapeDataString($voice),
                    [uri]::EscapeDataString($language))

                Invoke-WebRequest -Uri $ttsUrl -Method POST `
                    -ContentType "application/x-www-form-urlencoded" `
                    -Body $body `
                    -TimeoutSec 20 `
                    -OutFile $tmp

                $player = New-Object System.Media.SoundPlayer $tmp
                try {
                    $player.Load()
                    $player.PlaySync()
                } finally {
                    $player.Stop()
                    $player.Dispose()
                }

                $done = $true
            } catch {
                $resp = $_.Exception.Response
                $code = if ($resp) { try { [int]$resp.StatusCode } catch { "no-code" } } else { "no-response" }
                $txt  = try {
                    if ($resp) {
                        $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
                        $raw = $sr.ReadToEnd()
                        if ($raw.Length -gt 500) { $raw.Substring(0,500) + "…" } else { $raw }
                    } else { "" }
                } catch { "" }

                Write-Log ("TTS request failed (attempt {0}/{1}, code={2}): {3}" -f $attempt,$maxRetries,$code,$txt) Red

                if ($attempt -lt $maxRetries) {
                    Start-Sleep -Seconds $delay
                    $delay = [Math]::Min($delay * 2, 8)
                }
            } finally {
                try { Remove-Item $tmp -ErrorAction SilentlyContinue } catch {}
            }
        }
    }
}

$ChatLineRegex = '^(?<ts>.*?)\|\|\|\|(?<channel>-?\d+)\|\|\|\|(?<name>.*?)\|\|\|\|(?<msg>.*)$'
function Parse-ChatLine([string]$raw) {
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $line = $raw.Trim()
    if ($line -match '^[\},\s]*$') { Debug-Drop "brace/comma-only" $raw; return $null }

    $m = [System.Text.RegularExpressions.Regex]::Match($line, $ChatLineRegex)
    if (-not $m.Success) {
        $fields = $line -split "\|\|\|\|", 4
        if ($fields.Length -ge 4) {
            return [pscustomobject]@{
                Channel = $fields[1].Trim()
                Name    = $fields[2].Trim()
                Message = $fields[3]
            }
        }
        Debug-Drop "parse-failed" $raw
        return $null
    }

    return [pscustomobject]@{
        Channel = $m.Groups['channel'].Value.Trim()
        Name    = $m.Groups['name'].Value.Trim()
        Message = $m.Groups['msg'].Value
    }
}

function Invoke-TTS {
    param([string]$text)

    $obj = Parse-ChatLine $text
    if ($null -eq $obj) { return }

    $channel = $obj.Channel
    $name    = $obj.Name
    $rawMsg  = $obj.Message

    # quick trims & cheap drops before heavy cleaning
    if ([string]::IsNullOrWhiteSpace($rawMsg)) { Debug-Drop "empty" $text; return }
    $rawTrim = $rawMsg.Trim()
    if ($rawTrim -match "https?://") { Debug-Drop "link" $text; return }
    if ($rawTrim.StartsWith("[") -and $rawTrim.EndsWith("]")) { Debug-Drop "bracketed-emote" $text; return }
    if (Test-ItemCodeNoise $rawTrim) { Debug-Drop "item-code-noise" $text; return }
    $message = Clean-ChatMessage $rawMsg

    if (-not $AllowAllChannels) {
        if ($AllowedChannels -notcontains $channel) {
            Track-UnknownChannel $channel $name $message
            Debug-Drop "channel-$channel-not-allowed" $text
            return
        }
    }

    if ([string]::IsNullOrWhiteSpace($message)) { Debug-Drop "empty-after-clean" $text; return }

    $logLine = "$(Get-Date -Format 'u') [$name]: $message"
    try { Add-Content -Path $logPath -Value $logLine -Encoding UTF8 } catch {}
    Write-Host $logLine

    Enqueue-Message $message
    Drain-Queue
}

# -------- Startup Ping --------
$startupMessage = "Voice audio working"
try { Add-Content -Path $logPath -Value "$(Get-Date -Format 'u') [System]: $startupMessage" -Encoding UTF8 } catch {}
Write-Host "$(Get-Date -Format 'u') [System]: $startupMessage"
Enqueue-Message $startupMessage
Drain-Queue

# -------- Tail File --------
if (Test-Path $pathFile) {
    Get-Content -Path $pathFile -Wait -Tail 0 -Encoding UTF8 | ForEach-Object {
        if ($_ -ne $null -and $_.Length -gt 0) {
            Invoke-TTS -text $_
        }
    }
} else {
    Write-Host "Chat log file not found: $pathFile"
    exit 1
}
