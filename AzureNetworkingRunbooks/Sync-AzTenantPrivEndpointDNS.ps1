
<#
    .DESCRIPTION
       
        This sample runbook syncs Private Endpoint DNS records from one Azure tenant to 
        another Azure tenant

        This runbook runs in the source tenant.
    
        This runbook is designed to fired from and alert for when the following condition is 
        detected in the Azure Activity Log:

        Whenever the Activity Log has an event with Category='Administrative', Operation
         name='Create or update an private endpoint.', Level='informational', Status='succeeded'

        This runbook will then perform the following actions to replicate the record to another
        Azure tenant:

        1. On Source Tenant: Find the IP address of the NIC resource attached to the Private Endpoint
        2. On Source Tenant: Find the singular Private DNS Zone that contains the collected IP.
        3. On Destination Tenant: Check is made to ensure that IP is not assigned to another 
            DNS Zone or is a duplicate. If not, an A record is created in the corresponding 
            Azure Private DNS Zone.
        
        
    .INPUTS

    WebhookData - This is the Common Alert Schema for the alert.

    .NOTES
    
        1. A service principal must be created on the destination tenant the has rights to the 
            resource group(s) containing the Private DNS Zones where records will be replicated.

        2. Service Principal must be added as an Azure Automation Connection with the ClientID
            being the username and the password being the secret of the SP. The name of this
            connection should be "syncdnszone-sp"

        3. For the runbook variables, create Azure Automation Variables that contain the following
            information: 
                
                a. privDNStargetTenantID = Target tenant ID (GUID)
                b. privDNStargetSubID    = Subscription ID (GUID) of the destination subscription
                   holding the Azure Private DNS Zones that you will be replicating to.
        
        4. Under the "Set Static Variables" section of this script, hardcode the subscriptionID
            that contains the Source Private DNS Zones on the source subscription.

        5. Runbook will FAIL if:

                a. There are multiple Azure Private DNS recordsets with the same IP in the source
                    tenant.
                b. The source tenant does not have a Private DNS Zone with the Private Endpoint 
                    IP in it.
                c. The destination tenant does not have a corresponding Private DNS Zone that 
                    matches the source tenant.
                d. The IP is already assigned in the destination tenant.

        6. When creating the Alert Rule, make sure that the Common Alert Schema is enabled in
            the action group.
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
 
# Get Source Virtual Network ID from webhook data

($WebhookBody | ConvertFrom-Json).data.essentials
 
$scope = ($WebhookBody | ConvertFrom-Json).data.essentials.alertTargetIDs[0]

Write-Verbose -Message $scope

#$scope = "/subscriptions/708e166e-08d1-40b0-afb1-2b1b7f15e57f/resourcegroups/SharedServices-rg/providers/Microsoft.Network/privateEndpoints/TestEndpoint"
$scopeArray = $scope.Split("/")


#Set Static Variables

$automationAccountName = "azautomation-eastus2"
$automationAccountRG = "automation-rg"
$destTenantIDvar = "privDNStargetTenantID"
$destServicePrinIDvar = "syncdnszone-sp"
$srcSubscriptionID = "708e166e-08d1-40b0-afb1-2b1b7f15e57f"
$destSubscriptionIDvar = "privDNStargetSubID"
$ttl = 3600


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

# Parse resource ID and get Private Endpoint ID

Write-Verbose -Message "Looking for Scope: $scope"
$privateEndpoint = Get-AzPrivateEndpoint -Name $scopeArray[8] -ResourceGroupName $scopeArray[4]

$peNICInfoArray = $privateEndpoint.NetworkInterfaces.Id.Split("/")
$aRecordIP = (((Get-AzNetworkInterface -Name $peNICInfoArray[8] -ResourceGroupName $peNICInfoArray[4]).IpConfigurations)).privateIPAddress
Write-Verbose -Message "NIC IP is $aRecordIP"

# Cycle through all LOCAL Azure Private DNS Zones to find IP:

$DNSRecordSet = @()
$azZones = Get-AzPrivateDnsZone

foreach ($azZone in $azZones) {

    $params = @{

        ResourceGroupName = $azZone.ResourceGroupName 
        ZoneName          = $azZone.Name

    }

    $DNSRecordSet += Get-AzPrivateDnsRecordSet @params | Where-Object { $_.Records.Ipv4Address -contains $aRecordIP }

}

# Make sure that we do not have duplicate entries

if ($DNSRecordSet.Count -gt 1) { Write-Error "More than one record set found for IP: $aRecordIP" }

Write-Verbose -Message "ZoneName: $($DNSRecordSet.ZoneName), A Record Name: $($DNSRecordSet.Name), IP Address: $($aRecordIP)"

# Connect to Destination Tenant

Write-Verbose -Message "Connecting to Destination Tenant: $destTenant"

$params = @{

    ServicePrincipal = $true
    Credential       = $spCreds
    Tenant           = $destTenant
    SubscriptionID   = $destSubscriptionID


}

Connect-AzAccount @params | Out-Null


# Cycle through all DESTINATION Azure Private DNS Zones to Source IP (we do not want duplicates):

$destDNSRecordSet = @()
$destAzZones = Get-AzPrivateDnsZone

foreach ($destAzZone in $destAzZones) {

    $params = @{

        ResourceGroupName = $destAzZone.ResourceGroupName 
        ZoneName          = $destAzZone.Name

    }

    $destDNSRecordSet += Get-AzPrivateDnsRecordSet @params | Where-Object { $_.Records.Ipv4Address -contains $aRecordIP }

}

if ($destDNSRecordSet) { 
	
    If ($destDNSRecordSet.Name -eq $DNSRecordSet.Name -and $destDNSRecordSet.ZoneName -match $DNSRecordSet.ZoneName ) {

        Write-Verbose -Message "The record already exists. We are not going to overwrite this record."
        Exit
		
    }
    if ($destDNSRecordSet.Count -ge 1) { 
		
        Write-Output ($destDNSRecordSet | ConvertTo-JSON -Depth 100)
        Write-Error -Message  "More than one record set exists for this IP. We are not going to change anything." 
		
    }	
	
}

# Check if correct Private DNS Zone to exist. (Note: We might want to create logic to actually create the Zone.)

if (!$destDNSRecordSet) {

    $testForZone = Get-AzPrivateDnsZone -Name $DNSRecordSet.ZoneName

    if (!$testForZone) { Write-Error -Message "The zone, $($DNSRecordSet.ZoneName), does not exist. This Azure Private DNS Zone needs to be created at the destination." }

    # Now we get to write the record.

    # Configure resource tagging for record set
    $metadata = @{"SourceTenantPrivateLinkResourceID" = $scope }


    if ($testForZone) {

        $record = @()
        $record += New-AzPrivateDnsRecordConfig -IPv4Address $aRecordIP

        $params = @{

            Name              = $DNSRecordSet.Name
            RecordType        = 'A'
            ResourceGroupName = $testForZone.ResourceGroupName
            TTL               = $ttl
            ZoneName          = $DNSRecordSet.ZoneName
            PrivateDnsRecords = $record
            Metadata          = $metadata

        }

        New-AzPrivateDnsRecordSet @params | Out-Null

    }

}

