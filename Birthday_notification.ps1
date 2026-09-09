# ==========================================
# Birthday Notification Automation
# Gmail + Slack
# ==========================================

# ------------------------------------------
# 1. Gmail SMTP Configuration
# ------------------------------------------
$smtpServer = "://gmail.com"
$smtpPort   = 587

$from = "cpandey1993@gmail.com"
$to   = "cpandey1993@gmail.com"

# Gmail App Password from Pipeline Secret
$appPassword = $env:GMAIL_APP_PASSWORD

if ([string]::IsNullOrWhiteSpace($appPassword)) {
    throw "GMAIL_APP_PASSWORD is not configured."
}

$securePassword = ConvertTo-SecureString $appPassword -AsPlainText -Force
$cred = New-Object System.Management.Automation.PSCredential($from, $securePassword)

# ------------------------------------------
# 2. Slack Webhook (यहाँ आपका URL पूरी तरह हार्डकोडेड है)
# ------------------------------------------
$webhook = "https://slack.com"

if ([string]::IsNullOrWhiteSpace($webhook)) {
    throw "Slack webhook is not configured."
}

# ------------------------------------------
# 3. Birthday CSV
# ------------------------------------------
$csvPath = Join-Path $env:System_DefaultWorkingDirectory "scripts\birthdays.csv"

Write-Output "=========================================="
Write-Output "Birthday Notification Started"
Write-Output "=========================================="
Write-Output "CSV Path: $csvPath"

if (-not (Test-Path $csvPath)) {
    throw "Birthday CSV file not found: $csvPath"
}

$birthdays = Import-Csv $csvPath

# ------------------------------------------
# 4. Current Date
# ------------------------------------------
$currentDate = (Get-Date).Date
Write-Output "Today's Date: $($currentDate.ToString('dd MMM yyyy'))"

# ------------------------------------------
# 5. Find Today's Birthdays
# ------------------------------------------
$todayBirthdays = @(
    $birthdays | Where-Object {
        if ([string]::IsNullOrWhiteSpace($_.Birthday)) {
            return $false
        }
        try {
            $birthday = Get-Date $_.Birthday
        }
        catch {
            return $false
        }
        return ($birthday.Day -eq $currentDate.Day -and $birthday.Month -eq $currentDate.Month)
    }
)

Write-Output "Today's Birthdays Found: $($todayBirthdays.Count)"

# ------------------------------------------
# 6. Stop if No Birthday
# ------------------------------------------
if ($todayBirthdays.Count -eq 0) {
    Write-Output "No birthdays today."
    Write-Output "No email or Slack notification required."
    exit 0
}

# ------------------------------------------
# 7. Unicode Emojis
# ------------------------------------------
$cake     = [char]::ConvertFromUtf32(0x1F382) # 🎂
$party    = [char]::ConvertFromUtf32(0x1F389) # 🎉
$sparkles = [char]::ConvertFromUtf32(0x2728)  # ✨
$pray     = [char]::ConvertFromUtf32(0x1F64F) # 🙏
$confetti = [char]::ConvertFromUtf32(0x1F38A) # 🎊

# ------------------------------------------
# 8. Build Slack Message
# ------------------------------------------
$msg = "$cake Birthday Celebrations Today! $cake`n`n"
foreach ($b in $todayBirthdays) {
    $dateFull = (Get-Date $b.Birthday).ToString("dd MMM yyyy")
    $msg += "$sparkles $dateFull -> $($b.Name) $party Happy Birthday! $cake`n"
    $msg += "$pray God bless you! $confetti Many happy returns of the day! $confetti`n`n"
}

# ------------------------------------------
# 9. Send Gmail Notification
# ------------------------------------------
foreach ($b in $todayBirthdays) {
    $dateFull = (Get-Date $b.Birthday).ToString("dd MMM yyyy")
    $subject = "Birthday Reminder: $($b.Name)"

    $body = @"
<html>
<head><meta charset="UTF-8"></head>
<body>
<h2>$cake Birthday Reminder $cake</h2>
<p>Today is <strong>$($b.Name)'s Birthday!</strong> $party</p>
<p>$sparkles Birthday: <strong>$dateFull</strong></p>
<p>$confetti <strong>Happy Birthday!</strong> $confetti</p>
</body>
</html>
"@

    try {
        Send-MailMessage `
            -SmtpServer $smtpServer `
            -Port $smtpPort `
            -From $from `
            -To $to `
            -Subject $subject `
            -Body $body `
            -BodyAsHtml `
            -Credential $cred `
            -UseSsl `
            -Encoding utf8
        Write-Output "Email successfully sent for $($b.Name)"
    }
    catch {
        Write-Warning "Failed to send email for $($b.Name): $_"
    }
}

# ------------------------------------------
# 10. Send Slack Notification (यह रहा स्लैक पर डिलीवर करने का फंक्शन)
# ------------------------------------------
Write-Output "Sending notification to Slack..."
try {
    $jsonPayload = @{ text = $msg } | ConvertTo-Json -EnforceArray
    $response = Invoke-RestMethod `
        -Uri $webhook `
        -Method Post `
        -Body $jsonPayload `
        -ContentType "application/json; charset=utf-8"
    Write-Output "Slack notification status: $response"
}
catch {
    Write-Warning "Failed to send Slack notification: $_"
}
