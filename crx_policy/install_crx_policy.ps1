$ErrorActionPreference = "Stop"

# --- CONFIG ---
$extId = "edfeiokihfhcjpbdmecodhldjgdffchk"
$crxName = "StreamSniper.crx"
$updateXmlName = "update.xml"
$policyRegPath = "HKLM:\Software\Policies\Google\Chrome\ExtensionInstallForcelist"

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# --- Check for CRX ---
$crxPath = Join-Path $scriptPath $crxName
if (!(Test-Path $crxPath)) {
    Write-Host "[ERROR] CRX file not found. Place $crxName in $scriptPath." -ForegroundColor Red
    exit 1
}

# --- Create update.xml with file:// URL ---
$xmlContent = @"
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='$extId'>
    <updatecheck codebase='file:///$($crxPath.Replace('\', '/'))' version='1.0.0' />
  </app>
</gupdate>
"@

$xmlPath = Join-Path $scriptPath $updateXmlName
$xmlContent | Out-File -FilePath $xmlPath -Encoding UTF8

Write-Host "Created update.xml with file:// URL" -ForegroundColor Yellow

# --- Set Chrome policy ---
Write-Host "Setting Chrome ExtensionInstallForcelist policy..." -ForegroundColor Yellow

# Remove any existing ExtensionInstallForcelist entries for this extension
try {
    $existingEntries = Get-ItemProperty -Path $policyRegPath -ErrorAction SilentlyContinue
    if ($existingEntries) {
        foreach ($prop in $existingEntries.PSObject.Properties) {
            if ($prop.Value -like "*$extId*") {
                Remove-ItemProperty -Path $policyRegPath -Name $prop.Name -Force -ErrorAction SilentlyContinue
                Write-Host "  Removed existing policy entry: $($prop.Name)" -ForegroundColor DarkGray
            }
        }
    }
} catch {}

# Set the ExtensionInstallForcelist policy
New-Item -Path $policyRegPath -Force | Out-Null
Set-ItemProperty -Path $policyRegPath -Name "1" -Value "$extId;file:///$($xmlPath.Replace('\', '/'))"

# Also set the extension settings to allow installation
$extensionSettingsPath = "HKLM:\Software\Policies\Google\Chrome\ExtensionSettings"

# Remove existing settings for this extension
if (Test-Path "$extensionSettingsPath\$extId") {
    Remove-Item -Path "$extensionSettingsPath\$extId" -Force -ErrorAction SilentlyContinue
    Write-Host "  Removed existing extension settings" -ForegroundColor DarkGray
}

New-Item -Path "$extensionSettingsPath\$extId" -Force | Out-Null
Set-ItemProperty -Path "$extensionSettingsPath\$extId" -Name "installation_mode" -Value "force_installed"
Set-ItemProperty -Path "$extensionSettingsPath\$extId" -Name "update_url" -Value "file:///$($xmlPath.Replace('\', '/'))"

Write-Host "Policy set. Chrome will force-install the extension from local file." -ForegroundColor Green
Write-Host "Please close and reopen Chrome to install the extension."

exit 0
