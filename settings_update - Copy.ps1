<#
    Script: Settings_Automation.ps1
    Author: ChatGPT (GPT-5)
    Purpose: Retrieve, modify, validate, and deploy key Salesforce Org Settings
    Usage:
        .\Settings_Automation.ps1 -OrgAlias MySandbox -WaitTime 30
#>

param(
    [string]$OrgAlias = "MySandbox",
    [int]$WaitTime = 30
)

$manifest = "./manifest/package.xml"
$settingsPath = "force-app/main/default/settings"
$backupFolder = "./backups/$(Get-Date -Format 'yyyyMMdd_HHmm')"

Write-Host "===================================================================" -ForegroundColor Yellow
Write-Host " Salesforce Settings Automation Script - Pre-Configured " -ForegroundColor Cyan
Write-Host "===================================================================" -ForegroundColor Yellow

# ------------------------- STEP 1: Retrieve ----------------------------
Write-Host "`n[STEP 1] Retrieving Settings Metadata from Org ($OrgAlias)..." -ForegroundColor Cyan
sf project retrieve start -x $manifest -o $OrgAlias --wait $WaitTime

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Retrieval failed. Exiting." -ForegroundColor Red
    exit 1
}

# ------------------------- STEP 2: Backup ------------------------------
Write-Host "`n[STEP 2] Backing up retrieved settings..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null
Copy-Item $settingsPath -Destination $backupFolder -Recurse -Force

# ------------------------- STEP 3: Modify Settings ---------------------
Write-Host "`n[STEP 3] Applying configuration changes..." -ForegroundColor Cyan

function Update-XmlValue {
    param(
        [string]$file,
        [string]$pattern,
        [string]$replacement
    )
    if (Test-Path $file) {
        (Get-Content $file) -replace $pattern, $replacement | Set-Content $file
    }
}

# ------------------- Security Settings -------------------
$securityFile = "$settingsPath/Security.settings-meta.xml"
if (Test-Path $securityFile) {
    Write-Host " - Updating Security Settings..."
    Update-XmlValue $securityFile "<sessionTimeout>.*?</sessionTimeout>" "<sessionTimeout>120</sessionTimeout>"
    Update-XmlValue $securityFile "<enableLoginForensics>false</enableLoginForensics>" "<enableLoginForensics>true</enableLoginForensics>"
    Update-XmlValue $securityFile "<minimumPasswordLength>.*?</minimumPasswordLength>" "<minimumPasswordLength>10</minimumPasswordLength>"
    Update-XmlValue $securityFile "<passwordComplexity>.*?</passwordComplexity>" "<passwordComplexity>High</passwordComplexity>"
    Update-XmlValue $securityFile "<lockoutIntervalMinutes>.*?</lockoutIntervalMinutes>" "<lockoutIntervalMinutes>15</lockoutIntervalMinutes>"
}

# ------------------- Apex Settings -------------------
$apexFile = "$settingsPath/Apex.settings-meta.xml"
if (Test-Path $apexFile) {
    Write-Host " - Updating Apex Settings..."
    Update-XmlValue $apexFile "<enableApexAccess>false</enableApexAccess>" "<enableApexAccess>true</enableApexAccess>"
}

# ------------------- Email Administration -------------------
$emailFile = "$settingsPath/EmailAdministration.settings-meta.xml"
if (Test-Path $emailFile) {
    Write-Host " - Updating Email Admin Settings..."
    Update-XmlValue $emailFile "<enableEmailRelay>false</enableEmailRelay>" "<enableEmailRelay>true</enableEmailRelay>"
}

# ------------------- MyDomain Settings -------------------
$myDomainFile = "$settingsPath/MyDomain.settings-meta.xml"
if (Test-Path $myDomainFile) {
    Write-Host " - Updating MyDomain Settings..."
    Update-XmlValue $myDomainFile "<enableDomainDeployment>false</enableDomainDeployment>" "<enableDomainDeployment>true</enableDomainDeployment>"
}

# ------------------- Sharing Settings -------------------
$sharingFile = "$settingsPath/Sharing.settings-meta.xml"
if (Test-Path $sharingFile) {
    Write-Host " - Updating Sharing Settings..."
    Update-XmlValue $sharingFile "<enableManualSharing>false</enableManualSharing>" "<enableManualSharing>true</enableManualSharing>"
}

# ------------------- Platform Encryption -------------------
$platformEncFile = "$settingsPath/PlatformEncryption.settings-meta.xml"
if (Test-Path $platformEncFile) {
    Write-Host " - Updating Platform Encryption Settings..."
    Update-XmlValue $platformEncFile "<enableDeterministicEncryption>false</enableDeterministicEncryption>" "<enableDeterministicEncryption>true</enableDeterministicEncryption>"
}

# ------------------- Content & Chatter Settings -------------------
$contentFile = "$settingsPath/Content.settings-meta.xml"
$chatterFile = "$settingsPath/Chatter.settings-meta.xml"
if (Test-Path $contentFile) { Update-XmlValue $contentFile "<enableContent>true</enableContent>" "<enableContent>true</enableContent>" }
if (Test-Path $chatterFile) { Update-XmlValue $chatterFile "<enableChatter>false</enableChatter>" "<enableChatter>true</enableChatter>" }

# ------------------- RemoteSite Settings -------------------
$remoteFile = "$settingsPath/RemoteSiteSetting.settings-meta.xml"
if (Test-Path $remoteFile) { Write-Host " - Remote Site Settings OK (use package.xml to retrieve all)" }

# ------------------- Connected App Settings -------------------
$connectedAppFile = "$settingsPath/ConnectedApp.settings-meta.xml"
if (Test-Path $connectedAppFile) { Write-Host " - Connected App Settings OK (use package.xml)" }

# ------------------------- STEP 4: Validation --------------------------
Write-Host "`n[STEP 4] Validating modified settings..." -ForegroundColor Cyan

function Validate-XmlValue {
    param(
        [string]$file,
        [string]$pattern,
        [string]$expected
    )
    if (-not (Test-Path $file)) {
        Write-Host " ⚠️  $file not found!" -ForegroundColor Yellow
        return $false
    }
    $content = Get-Content $file -Raw
    if ($content -match $pattern) {
        Write-Host " ✔ Validation Passed for $file → $expected" -ForegroundColor Green
        return $true
    } else {
        Write-Host " ❌ Validation FAILED for $file → Expected: $expected" -ForegroundColor Red
        return $false
    }
}

$validationResults = @()

# Security validations
$validationResults += Validate-XmlValue $securityFile "<sessionTimeout>120</sessionTimeout>" "Session Timeout = 120"
$validationResults += Validate-XmlValue $securityFile "<enableLoginForensics>true</enableLoginForensics>" "Login Forensics Enabled"
$validationResults += Validate-XmlValue $securityFile "<minimumPasswordLength>10</minimumPasswordLength>" "Min Password Length = 10"
$validationResults += Validate-XmlValue $securityFile "<passwordComplexity>High</passwordComplexity>" "Password Complexity High"
$validationResults += Validate-XmlValue $securityFile "<lockoutIntervalMinutes>15</lockoutIntervalMinutes>" "Lockout Interval = 15"

# Apex
$validationResults += Validate-XmlValue $apexFile "<enableApexAccess>true</enableApexAccess>" "Apex Access Enabled"

# Email
$validationResults += Validate-XmlValue $emailFile "<enableEmailRelay>true</enableEmailRelay>" "Email Relay Enabled"

# MyDomain
$validationResults += Validate-XmlValue $myDomainFile "<enableDomainDeployment>true</enableDomainDeployment>" "MyDomain Deployment Enabled"

# Sharing
$validationResults += Validate-XmlValue $sharingFile "<enableManualSharing>true</enableManualSharing>" "Manual Sharing Enabled"

# Platform Encryption
$validationResults += Validate-XmlValue $platformEncFile "<enableDeterministicEncryption>true</enableDeterministicEncryption>" "Deterministic Encryption Enabled"

# Chatter
$validationResults += Validate-XmlValue $chatterFile "<enableChatter>true</enableChatter>" "Chatter Enabled"

# ------------------------- STEP 5: Deploy ------------------------------
if ($validationResults -contains $false) {
    Write-Host "`n❌ Validation failed. Aborting deployment." -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ All validations passed. Proceeding to deployment..." -ForegroundColor Green
}

Write-Host "`n[STEP 5] Deploying to Org ($OrgAlias)..." -ForegroundColor Cyan
sfdx force:source:deploy -x $manifest -u $OrgAlias -l RunLocalTests -w $WaitTime

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Deployment Successful to Org: $OrgAlias" -ForegroundColor Green
} else {
    Write-Host "`n❌ Deployment Failed. Check deployment status." -ForegroundColor Red
}
