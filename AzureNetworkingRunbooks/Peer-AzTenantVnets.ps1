
<#
    .DESCRIPTION

       Standalone version. 

       Peers vnets that exist in other tenants using a single multi-tenant service principal.


    .INPUTS

       srcVnetID -  '/subscriptions/{subscriptionID}/resourceGroups/{resource group}/providers/Microsoft.Network/virtualNetworks/{vnet name}'

       destVnetID -  '/subscriptions/{subscriptionID}/resourceGroups/{resource group}/providers/Microsoft.Network/virtualNetworks/{vnet name}'



    .EXAMPLE

        Peer-AzTenantVnets -srcVnetID  '/subscriptions/{subscriptionID}/resourceGroups/{resource group}/providers/Microsoft.Network/virtualNetworks/{vnet name}' 
            -destVnetID  '/subscriptions/{subscriptionID}/resourceGroups/{resource group}/providers/Microsoft.Network/virtualNetworks/{vnet name}'


    .NOTES
    
        1. A multi-tenant service principal must be created in one of the sites.
        2. In the other site, admin consent will need to be set on the service principal that was
            created. 
            Example: https://login.microsoftonline.com/common/adminconsent?client_id={client id of SP}
        3. The multi-tenant service principal must have Network Contributor rights to perform 
            the necessary operations in both subscription either for the targeted subscription/
            resource group/vnet resource. 
        4. You must hardcode the SP secret, App ID, and tenant IDs in the script.  For more security
            use the runbook version of this script.

#>

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $srcVnetID,
    [Parameter()]
    [string]
    $destVnetID
)

# Static variables

# Service Principal information.
$secret = "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"          
$appID = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Source and destingation Tenant IDs 
$srcTenant = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$destTenant = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# Set Preferences

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Import Modules

$VerbosePreference = "SilentlyContinue"
Import-Module Az.Network
Import-Module Az.Accounts
$VerbosePreference = "SilentlyContinue"

# Logon to Tenant01 with defined Service Principal

$sSecret = $secret | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $appID, $sSecret

# Connect to destination tenant first - don't know why this is necessary, but it is.
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $destTenant

# Connect to source tenant
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $srcTenant

# Add the peering on Tenant01

$srcVnetName = (($srcVnetID.split('/'))[8])
$srcVnet = Get-AzVirtualNetwork -Name $srcVnetName
$destVnetName = (($destVnetID.split('/'))[8])

$params = @{

    Name                   = "$($srcVnetName)_$($destVnetName)"
    virtualNetwork         = $srcVnet
    RemoteVirtualNetworkId = $destVnetID

}

Add-AzVirtualNetworkPeering @params

# Logon to Tenant02 with defined Service Principal

Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $destTenant

# Add the peering on Tenant01

$destVnet = Get-AzVirtualNetwork -Name $destVnetName

$params = @{

    Name                   = "$($destVnetName)_$($srcVnetName)"
    virtualNetwork         = $destVnet
    RemoteVirtualNetworkId = $srcVnetID
    
}
    
Add-AzVirtualNetworkPeering @params
    