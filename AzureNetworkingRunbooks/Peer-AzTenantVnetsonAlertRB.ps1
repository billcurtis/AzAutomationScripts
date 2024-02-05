
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
        4. You must create automation credentials\variables for the SP secret, App ID, and tenant IDs.

#>

[OutputType("PSAzureOperationResponse")]
param
(
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
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
$destVnetIDVariableName = "destVnetID"

# Log into Azure Automation using Identity

Connect-AzAccount -Identity | Out-Null

# Get Variables and Credentials

# Get Source Virtual Network ID from webhook data
$WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)
$srcVnetID = $WebhookBody.Data.Essentials.alertTargetIDs[0]
Write-Output $WebhookBody

# Set Source Az Context
$srcSubscriptionID = $srcVnetID.split("/")[2]
Write-Verbose -Message "SubscriptionID = $srcSubscription"
Set-AzContext -SubscriptionId $srcSubscriptionID

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


# get destination tenant vnet identifier variable value

$params = @{

    AutomationAccountName = $automationAccountName
    Name                  = $destVnetIDVariableName
    ResourceGroupName     = $automationAccountRG

} 

$destVnetID = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Destination VnetiD is: $desVnetID"

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
Import-Module Az.Automation
$VerbosePreference = "SilentlyContinue"

# Get Subscription IDs from vnet resource ids

$srcVnetSubId = (($srcVnetID.split('/'))[2])
Write-Verbose -Message "Source Subscription ID is: $srcVnetSubId"
$destVnetSubId = (($destVnetID.split('/'))[2])

Write-Verbose -Message "Destination Subscription ID is: $destVnetSubId"

# Logon to source with Service Principals

# Connect to destination tenant first 

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

# Set peering name

$peeringName = "$($srcVnetName)_$($destVnetName)"

# Check to see if peering already exists

$sourceResGroupName = (($srcVnetID.split('/'))[4])

$params = @{

    VirtualNetworkName = $srcVnetName
    ResourceGroupName  = $sourceResGroupName

}

$isPeered = Get-AzVirtualNetworkPeering @params | Where-Object { $_.Name -eq $peeringName }


if (!$isPeered) {

    $params = @{

        Name                   = $peeringName
        virtualNetwork         = $srcVnet
        RemoteVirtualNetworkId = $destVnetID
        UseRemoteGateways      = $true
        AllowForwardedTraffic = $true
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
        AllowGatewayTransit    = $true
    
    }

    # Peer the destination

    Add-AzVirtualNetworkPeering @params

}
else {

    Write-Output "The peering already exists"

}
