#------------- Original Author: Strawberry --------------
param (
    [string]$lang = "en" #default is english
)

Add-Type -AssemblyName "System.Web"

$logFilePath = ".\translated_messages"

function TranslateAndLog {
    param (
        [string]$lang,
        [string]$text
    )
    $fields = $text -split "\|\|\|\|"
	$prefix = ($fields[1..2] -join ";;;") + ";;;" 
    $message = $fields[3]
    $encodedMessage = $message
	function translateThisGoogle {
		param (
			[string]$translate,
			[string]$text
		)
		$Uri = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=$translate&dt=t&q=$text"
		$Response = Invoke-RestMethod -Uri $Uri -Method Get
        if ($Response[2] -eq $translate) {return ""} 
		return $Response[0].SyncRoot | ForEach-Object { $_[0] }
	}

	$translation = translateThisGoogle -translate $lang -text $encodedMessage
    if ($translation -eq "") { return }
    Write-Host $encodedMessage
    Write-Host $translation
	
    
	if ($translation.Trim() -eq ($cleanMessage -replace "\+" , " ").Trim()) {
		return
	}
    # base64 encode 
    $translation = [System.Web.HttpUtility]::UrlDecode($translation)
    $translationBytes = [System.Text.Encoding]::UTF8.GetBytes($translation)
    $translation = [Convert]::ToBase64String($translationBytes)
	$finalMessage = $prefix + $translation  
    
    
	$logEntry = "{ chatMsg = `"$("$finalMessage".Trim())`" }"
    # Write-Host $translation
	try {
		Set-Content -Path $logFilePath -Value $logEntry -ErrorAction Stop
	} catch {
		Write-Host "Error writing to log file: $_" -ForegroundColor Red
		exit 1
	}
}

function ProcessChatLog {
    if (Test-Path $logFilePath) { Remove-Item $logFilePath }
    $pathFile = '.\to_be_translated.lua'
    if (Test-Path $pathFile) {
        Get-Content -Path $pathFile -Wait -Tail 0 -Encoding UTF8 | ForEach-Object {
            # Write-Host $_
            if ($_ -ne "" -and $_ -ne "{" -and $_ -ne "}") {
                TranslateAndLog -lang $lang -text (Get-Content -Path $pathFile -Encoding UTF8)[1]
            }
        }
    } else {
        Write-Host "Chat log file not found: $pathFile"
        exit 2
    }
}

try {
    ProcessChatLog
} catch {
    Write-Host "Unexpected error: $_" -ForegroundColor Red
    exit 3
}