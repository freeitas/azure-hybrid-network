<#
.SYNOPSIS
  Configures RRAS on the simulated on-premises firewall as the site-to-site VPN endpoint.
.NOTES
  Runs as SYSTEM through an Azure Run Command, and is safe to run repeatedly.
#>
param(
    [Parameter(Mandatory)][string]$AzureGatewayIp,
    [Parameter(Mandatory)][string]$SharedKey,
    # CIDR list of the networks reached through Azure. Commas, semicolons or spaces separate
    # them, because Run Command may split an unquoted comma list into a PowerShell array.
    [Parameter(Mandatory)][string]$RemotePrefixes
)

$ErrorActionPreference = 'Stop'
$interfaceName = 'azure-s2s'

Install-WindowsFeature -Name RemoteAccess, Routing, RSAT-RemoteAccess-PowerShell -IncludeManagementTools | Out-Null

if ((Get-RemoteAccess).VpnS2SStatus -ne 'Installed') {
    Install-RemoteAccess -VpnType VpnS2S
}

# Recreate the interface so a changed key or gateway IP always takes effect.
if (Get-VpnS2SInterface -Name $interfaceName -ErrorAction SilentlyContinue) {
    Remove-VpnS2SInterface -Name $interfaceName -Force
}

$subnets = $RemotePrefixes -split '[,;\s]+' | Where-Object { $_ } | ForEach-Object { "${_}:100" }

Add-VpnS2SInterface `
    -Name $interfaceName `
    -Protocol IKEv2 `
    -Destination $AzureGatewayIp `
    -AuthenticationMethod PSKOnly `
    -ResponderAuthenticationMethod PSKOnly `
    -SharedSecret $SharedKey `
    -NumberOfTries 3 `
    -IPv4Subnet $subnets `
    -Persistent

Set-VpnS2SInterface -Name $interfaceName -InitiateConfigPayload $false -Force
Set-Service -Name RemoteAccess -StartupType Automatic
Restart-Service -Name RemoteAccess

# The Azure side may not be ready yet. The interface is persistent and keeps retrying.
try {
    Connect-VpnS2SInterface -Name $interfaceName
}
catch {
    Write-Warning "The tunnel is not up yet: $_"
}

Write-Output 'RRAS site-to-site configuration complete.'
