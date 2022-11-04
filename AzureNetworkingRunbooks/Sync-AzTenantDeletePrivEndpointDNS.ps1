
<#
    .DESCRIPTION
       
        This sample runbook deletes a Private Endpoint DNS records from the destination tenant 
        when Private Endpoint is deleted on the source tenant.

        This runbook runs in the source tenant.
    
        This runbook is designed to fired from and alert for when the following condition is 
        detected in the Azure Activity Log:

        Whenever the Activity Log has an event with Category='Administrative', Operation
         name='Create or update an private endpoint.', Level='informational', Status='succeeded'

        This runbook will then perform the following actions to replicate the record to another
        Azure tenant:

        1. On Source Tenant: Start this runbook.
        3. On Destination Tenant, this runbook will take the deleted PE's ResourceID from the 
            Common Alert Schema and search for the Azure Private DNS Zone record sets with that
            ResourceID in the metadata and will then delete those record(s).
        
        
    .INPUTS

    WebhookData - This is the Common Alert Schema for the alert.

    .NOTES
    
        1. A service principal must be created on the destination tenant the has rights to the 
            resource group(s) containing the Private DNS Zones where records will be replicated.

        
#>

[OutputType("PSAzureOperationResponse")]
param
(
    [Parameter (Mandatory = $false)]
    $WebhookData
)


# Set Preferences

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'SilentlyContinue'

# Import Modules

Import-Module Az.PrivateDns
Import-Module Az.Accounts
Import-Module Az.Network
Import-Module Az.Automation

# Set Preferences

$VerbosePreference = 'Continue'

# Structure Webhook Input Data

If ($WebhookData.WebhookName) {
    Write-Verbose -Message "Triggered on WebHookName"
    $WebhookBody = $WebhookData.RequestBody
}
ElseIf ($WebhookData) {
    Write-Verbose -Message "Triggered on JSON"
    $WebhookJSON = ConvertFrom-Json -InputObject $WebhookData
    $WebhookBody = $WebhookJSON.RequestBody
}
Else {
    Write-Error -Message 'Runbook was not started from Webhook' -ErrorAction stop
}
 
# Get Deleted Private Endpoint ID from webhook data

($WebhookBody | ConvertFrom-Json).data.essentials 
$scope = ($WebhookBody | ConvertFrom-Json).data.essentials.alertTargetIDs[0]

Write-Verbose $scope

#Set Static Variables

$automationAccountName = "azautomation-eastus2"
$automationAccountRG = "automation-rg"
$destTenantIDvar = "privDNStargetTenantID"
$destServicePrinIDvar = "syncdnszone-sp"
$srcSubscriptionID = "708e166e-08d1-40b0-afb1-2b1b7f15e57f"
$destSubscriptionIDvar = "privDNStargetSubID"


# Log into Azure Automation using Identity

Write-Verbose -Message "Connecting to Azure with Az Identity"
Connect-AzAccount -Identity -SubscriptionID $srcSubscriptionID | Out-Null
$azContextSubID = (Get-AzContext).Subscription
Write-Verbose -Message "Subscription $azContextSubID is in context."


# get destination subscription variable value

$params = @{

    Name                  = $destSubscriptionIDvar
    ResourceGroupName     = $automationAccountRG
    AutomationAccountName = $automationAccountName

} 

$destSubscriptionID = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Source Tenant is: $destTenant"


# get destination tenant variable value

$params = @{

    Name                  = $destTenantIDvar
    ResourceGroupName     = $automationAccountRG
    AutomationAccountName = $automationAccountName

} 

$destTenant = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Source Tenant is: $destTenant"

# get dest service principal 

$spCreds = Get-AutomationPSCredential -Name $destServicePrinIDvar
Write-Verbose -Message "Destination Service Principal Credentials: $spCreds"

# Connect to Destination Tenant

Write-Verbose -Message "Connecting to Destination Tenant: $destTenant"

$params = @{

    ServicePrincipal = $true
    Credential       = $spCreds
    Tenant           = $destTenant
    SubscriptionID   = $destSubscriptionID
    
}

Connect-AzAccount @params | Out-Null

# Cycle through all DNS Recordsets to find metadata with the resource id of the deleted endpoint

$DNSrecordSets = Get-AzPrivateDnsZone | Get-AzPrivateDnsRecordSet

foreach ($DNSrecordSet in $DNSrecordSets) {

    if ($DNSrecordSet.Metadata) {

        if ($DNSrecordSet.Metadata.ContainsValue($scope)) {

            Write-Verbose -Message "Deleting Recordset: $($DNSRecordSet.Id)"
            Remove-AzPrivateDnsRecordSet -RecordSet $DNSrecordSet

        }
		else { Write-Verbose -Message "Recordset was not found: $($DNSRecordSet.Id)"}

    }

}


