<#
.SYNOPSIS
  Installs IIS, restricts it to our Front Door profile, and optionally deploys an app package.
.NOTES
  Runs as SYSTEM through an Azure Run Command, and is safe to run repeatedly.
  Every download must match a SHA-256 hash, so a changed file stops the deployment.
#>
param(
    [Parameter(Mandatory)][string]$FrontDoorId,
    [Parameter(Mandatory)][string]$UrlRewriteMsiUrl,
    [Parameter(Mandatory)][string]$UrlRewriteMsiSha256,
    # First three octets of the P2S pool, for example 172.16.201.
    [Parameter(Mandatory)][string]$AdminPoolPrefix,
    [string]$AppPackageUrl,
    [string]$AppPackageSha256,
    [string]$InstallPath = 'C:\inetpub\wwwroot'
)

$ErrorActionPreference = 'Stop'

# SYSTEM and Administrators only, so nothing can swap a file between the hash check and its use.
$workDir = Join-Path $env:ProgramData "lab-bootstrap-$([guid]::NewGuid())"
New-Item -ItemType Directory -Path $workDir | Out-Null
icacls $workDir /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' | Out-Null

function Get-VerifiedFile {
    param([string]$Url, [string]$ExpectedSha256, [string]$FileName)

    $path = Join-Path $workDir $FileName
    Invoke-WebRequest -Uri $Url -OutFile $path -UseBasicParsing
    $actual = (Get-FileHash -Path $path -Algorithm SHA256).Hash
    if ($actual -ne $ExpectedSha256) {
        Remove-Item -Path $path -Force
        throw "SHA-256 mismatch for $FileName. Expected $ExpectedSha256, got $actual."
    }
    return $path
}

Install-WindowsFeature -Name Web-Server, Web-WebSockets, Web-Stat-Compression, Web-Dyn-Compression -IncludeManagementTools | Out-Null

$msi = Get-VerifiedFile -Url $UrlRewriteMsiUrl -ExpectedSha256 $UrlRewriteMsiSha256 -FileName 'urlrewrite.msi'
$install = Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i', "`"$msi`"", '/qn', '/norestart' -Wait -PassThru
# 3010 means success with a restart required.
if ($install.ExitCode -notin 0, 3010) {
    throw "URL Rewrite installation failed with exit code $($install.ExitCode)."
}

Import-Module WebAdministration

# The AzureFrontDoor.Backend service tag covers every Front Door customer, so also
# require our profile's ID. Only loopback, the P2S pool and on-premises skip the check;
# web app integration subnets do not, so a compromised app can't reach IIS directly.
$psPath = 'MACHINE/WEBROOT/APPHOST'
$rules = 'system.webServer/rewrite/globalRules'
$ruleName = 'RequireOurFrontDoor'
$rule = "$rules/rule[@name='$ruleName']"

$existing = Get-WebConfigurationProperty -PSPath $psPath -Filter $rules -Name '.' |
    Select-Object -ExpandProperty Collection |
    Where-Object { $_.name -eq $ruleName }
if ($existing) {
    Remove-WebConfigurationProperty -PSPath $psPath -Filter $rules -Name '.' -AtElement @{ name = $ruleName }
}

Add-WebConfigurationProperty -PSPath $psPath -Filter $rules -Name '.' -Value @{ name = $ruleName; stopProcessing = 'True' }
Set-WebConfigurationProperty -PSPath $psPath -Filter "$rule/match" -Name 'url' -Value '.*'
Add-WebConfigurationProperty -PSPath $psPath -Filter "$rule/conditions" -Name '.' -Value @{
    input   = '{HTTP_X_AZURE_FDID}'
    pattern = '^' + $FrontDoorId + '$'
    negate  = 'True'
}
Add-WebConfigurationProperty -PSPath $psPath -Filter "$rule/conditions" -Name '.' -Value @{
    input   = '{REMOTE_ADDR}'
    pattern = '^(127\.|::1$|192\.168\.|' + [regex]::Escape("$AdminPoolPrefix.") + ')'
    negate  = 'True'
}
Set-WebConfigurationProperty -PSPath $psPath -Filter "$rule/action" -Name 'type' -Value 'CustomResponse'
Set-WebConfigurationProperty -PSPath $psPath -Filter "$rule/action" -Name 'statusCode' -Value 403
Set-WebConfigurationProperty -PSPath $psPath -Filter "$rule/action" -Name 'statusReason' -Value 'Forbidden'
Set-WebConfigurationProperty -PSPath $psPath -Filter "$rule/action" -Name 'statusDescription' -Value 'Direct access is not allowed.'

if ($AppPackageUrl) {
    if (-not $AppPackageSha256) {
        throw 'AppPackageSha256 is required when AppPackageUrl is set.'
    }
    $package = Get-VerifiedFile -Url $AppPackageUrl -ExpectedSha256 $AppPackageSha256 -FileName 'app-package.zip'
    Expand-Archive -Path $package -DestinationPath $InstallPath -Force
}

Remove-Item -Path $workDir -Recurse -Force
iisreset /restart | Out-Null
Write-Output 'IIS bootstrap complete.'
