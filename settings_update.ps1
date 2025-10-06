# -------------------------------
# PowerShell Script: Update Security Settings & Deploy (Namespace-Aware, Safe + Backup + Change Detection)
# -------------------------------

# -------------------------------
# Config
# -------------------------------
$securityFile = "force-app/main/default/settings/Security.settings-meta.xml"
$settingsPath = "force-app/main/default/settings"
$orgAlias = "projectdemosfdc"
$logDir = "deployment_logs"
$packageXml = "./manifest/package.xml"
$waitTime = 30  # Deployment wait time in minutes
$testLevel = "RunLocalTests"  # Options: NoTestRun, RunSpecifiedTests, RunLocalTests, RunAllTestsInOrg

# Ensure log directory exists
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile = "$logDir\deploy_$timestamp.log"

# -------------------------------
# 0️⃣ Backup Retrieved Settings
# -------------------------------
$backupFolder = "./backups/$(Get-Date -Format 'yyyyMMdd_HHmm')"
Write-Host "`n[STEP 1] Backing up retrieved settings..."
New-Item -ItemType Directory -Force -Path $backupFolder | Out-Null
Copy-Item $settingsPath -Destination $backupFolder -Recurse -Force
Write-Host "Backup completed: $backupFolder"

# Optional individual XML backup for rollback
$backupFile = "$securityFile.bak_$timestamp"
Copy-Item -Path $securityFile -Destination $backupFile
Write-Host "Security.settings-meta.xml backup created: $backupFile"

# -------------------------------
# 1️⃣ Load XML and Prepare Namespace
# -------------------------------
[xml]$xml = Get-Content $securityFile
$originalXmlContent = $xml.OuterXml

$nsMgr = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
$nsMgr.AddNamespace("ns", $xml.DocumentElement.NamespaceURI)

# -------------------------------
# 2️⃣ Update Security Settings (Namespace-Aware)
# -------------------------------
try {
    $xml.SelectSingleNode("//ns:canUsersGrantLoginAccess", $nsMgr).InnerText = "false"
    $xml.SelectSingleNode("//ns:enableAdminLoginAsAnyUser", $nsMgr).InnerText = "true"
    $xml.SelectSingleNode("//ns:enableAuditFieldsInactiveOwner", $nsMgr).InnerText = "false"
    $xml.SelectSingleNode("//ns:skipSFAWhenMFADirectUILogin", $nsMgr).InnerText = "false"
} catch {
    Write-Host "Failed to update XML: $_"
    exit 1
}

# -------------------------------
# 3️⃣ Detect if Changes Were Made
# -------------------------------
$updatedXmlContent = $xml.OuterXml
if ($originalXmlContent -eq $updatedXmlContent) {
    Write-Host "No changes detected in Security.settings-meta.xml. Skipping deployment."
    exit 0
}

# Save the updated XML
$xml.Save($securityFile)
Write-Host "Security settings updated successfully. Changes detected, proceeding to deployment."

# -------------------------------
# 4️⃣ Validate Updated Values
# -------------------------------
Write-Host "Validating updated values..."
$validationPassed = $true

if ($xml.SelectSingleNode("//ns:canUsersGrantLoginAccess", $nsMgr).InnerText -ne "false") { $validationPassed = $false }
if ($xml.SelectSingleNode("//ns:enableAdminLoginAsAnyUser", $nsMgr).InnerText -ne "true") { $validationPassed = $false }
if ($xml.SelectSingleNode("//ns:enableAuditFieldsInactiveOwner", $nsMgr).InnerText -ne "false") { $validationPassed = $false }
if ($xml.SelectSingleNode("//ns:skipSFAWhenMFADirectUILogin", $nsMgr).InnerText -ne "false") { $validationPassed = $false }

if (-not $validationPassed) {
    Write-Host "Validation failed. Restoring backup..."
    Copy-Item -Path $backupFile -Destination $securityFile -Force
    exit 1
} else {
    Write-Host "Validation passed."
}

# -------------------------------
# 5️⃣ Deploy to Salesforce Org using sf CLI manifest (UTF-8 safe + JSON pretty print)
# -------------------------------
Write-Host "Deploying using sf CLI manifest to org: $orgAlias ..."

# Ensure PowerShell is UTF-8
chcp 65001 | Out-Null

$deployCommand = "sf deploy metadata --manifest $packageXml --target-org $orgAlias --test-level $testLevel --wait $waitTime --json"

try {
    # Invoke deployment and capture JSON
    $deployJson = Invoke-Expression $deployCommand 2>&1 | ConvertFrom-Json
    # Pretty print JSON to log file
    $deployJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $logFile -Encoding utf8
    Write-Host "Deployment completed. Log saved: $logFile"
} catch {
    Write-Host "Deployment failed: $_"
    exit 1
}
