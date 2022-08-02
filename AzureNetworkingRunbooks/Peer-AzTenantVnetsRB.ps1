
<#
    .DESCRIPTION
       
		This is the runbook version

        Peers vnets that exist in other tenants using a single multi-tenant service principal.


    .INPUTS

       srcVnetID -  '/subscriptions/{subscriptionID}/resourceGroups/{resource group}/providers/Microsoft.Network/virtualNetworks/{vnet name}'

       destVnetID -  '/subscriptions/{subscriptionID}/resourceGroups/{resource group}/providers/Microsoft.Network/virtualNetworks/{vnet name}'

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

# Set Preferences

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Set variables

$automationAccountRG = "vNetDemo"
$automationAccountName = "automation"
$destTenantVariableName = "destTenant"
$srcTenantVariableName = "srcTenant"
$vnetPeeringSPCred = "vNetPeeringSP"

# Log into Azure Automation using Identity

Connect-AzAccount -Identity 

# Get Variables and Credentials

# get destination tenant variable value

$params = @{

    AutomationAccountName = $automationAccountName
    Name                  = $srcTenantVariableName
    ResourceGroupName     = $automationAccountRG

} 

$srcTenant = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Source Tenant is: $srcTenant"

# get destination tenant variable value

$params = @{

    AutomationAccountName = $automationAccountName
    Name                  = $destTenantVariableName
    ResourceGroupName     = $automationAccountRG

} 

$destTenant = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Destination Tenant is: $destTenant"

# get service principal for vnet peering

$params = @{

    AutomationAccountName = $automationAccountName
    Name                  = $vnetPeeringSP
    ResourceGroupName     = $automationAccountRG

} 

$spCreds = Get-AutomationPSCredential -Name $vnetPeeringSPCred

Write-Verbose -Message "Service Principal Credentials: $spCreds"

# Import Modules

$VerbosePreference = "SilentlyContinue"
Import-Module Az.Network
Import-Module Az.Accounts
$VerbosePreference = "SilentlyContinue"

# Get Subscription IDs from vnet resource ids

$srcVnetSubId = (($srcVnetID.split('/'))[2])
Write-Verbose -Message "Source Subscription ID is: $srcVnetSubId"
$destVnetSubId = (($destVnetID.split('/'))[2])
Write-Verbose -Message "Destination Subscription ID is: $destVnetSubId"



# Logon to source with Service Principals

# Connect to destination tenant first to cache secret

Write-Verbose -Message "Connecting to Destination Tenant: $destTenant"
Connect-AzAccount -ServicePrincipal -Credential $spCreds -Tenant $destTenant | Out-Null

# Connect to source tenant

Write-Verbose -Message "Connecting to Source Tenant: $srcTenant"
Connect-AzAccount -ServicePrincipal -Credential $spCreds -Tenant $srcTenant | Out-Null

# Set context to the correct subscription

Set-AzContext -Subscription $srcVnetSubId | Out-Null

# Add the peering

Write-Verbose -Message "Adding the peering"
$srcVnetName = (($srcVnetID.split('/'))[8])
Write-Verbose -Message "Source Virtual Network Name is: $srcVnetName"
$srcVnet = Get-AzVirtualNetwork -Name $srcVnetName
$destVnetName = (($destVnetID.split('/'))[8])


$params = @{

    Name                   = "$($srcVnetName)_$($destVnetName)"
    virtualNetwork         = $srcVnet
    RemoteVirtualNetworkId = $destVnetID
    AllowGatewayTransit    = $true

}

Add-AzVirtualNetworkPeering @params

# Logon to destination

Connect-AzAccount -ServicePrincipal -Credential $spcreds -Tenant $destTenant | Out-Null

# Set context to the correct subscription

Set-AzContext -Subscription $destVnetSubId | Out-Null


$destVnet = Get-AzVirtualNetwork -Name $destVnetName

$params = @{

    Name                   = "$($destVnetName)_$($srcVnetName)"
    virtualNetwork         = $destVnet
    RemoteVirtualNetworkId = $srcVnetID
    
}

# Peer the destination

Add-AzVirtualNetworkPeering @params


