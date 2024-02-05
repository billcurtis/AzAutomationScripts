 
<#

v1.0

    .DESCRIPTION
       
 

    .INPUTS
       
 

    .NOTES
        
 
#>

param (

    [string]$Name,
    [string]$ResourceGroupName,
    [string]$SubscriptionId,
    [string]$AdministratorLoginPassword,
    [string]$AdministratorUserName,
    [string]$BackupRetentionDay,
    [string]$HighAvailability,
    [string]$Iops,
    [string]$Location,
    [string]$PublicAccess,
    [string]$Sku,
    [string]$SkuTier,
    [string]$StorageAutogrow,
    [string]$StorageInMb,
    [string]$Subnet,
    [string]$SubnetPrefix,
    [string]$Vnet,
    [string]$VnetPrefix,
    [string]$Zone

)


# static variables

$AutomationAccountName = "automation01-aa"   # Automation Account Name
$PrivateDNSZoneResourceID = "/subscriptions/3b324982-741d-41c8-bc71-8fed923fdb0e/resourceGroups/shared_services-rg/providers/Microsoft.Network/privateDnsZones/private.mysql.database.azure.com"  # pre-created Private DNS Zone



# static variables for dev
$Name = "wcurtistest"
$ResourceGroupName = 'flexible-rg'
$SubscriptionId = '3b324982-741d-41c8-bc71-8fed923fdb0e'
$AdministratorUserName = 'wcurtis'
$AdministratorLoginPassword = '@rcadeFIre47'
$Location = 'eastus'


# Import Modules
Import-Module Az.MySql
 

# Set Preferences

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Log in to Azure with automation account's identity
$runbookContext = (Connect-AzAccount -Identity).Context

# Set Context to the subscription that will contain the flexible server
Set-AzContext -SubscriptionID $SubscriptionId | Out-Null
$azContext = Get-AzContext

# set the password to be secure - may need to implement some key vault settings
$AdministratorLoginPasswordSecure = $AdministratorLoginPassword | ConvertTo-SecureString -AsPlainText -Force

# set public access to 'None' if not specified
if (!$PublicAccess) { $PublicAccess = 'None' }

# build the splat table

$params = @{

    Name                       = $Name
    ResourceGroupName          = $ResourceGroupName
    SubscriptionId             = $SubscriptionId
    AdministratorLoginPassword = $AdministratorLoginPasswordSecure
    AdministratorUserName      = $AdministratorUserName
    Location                   = $Location
    PublicAccess               = $PublicAccess

}

# if public access is set to 'None' then point to the pre-configured Private DNS Zone
if ($PublicAccess -eq 'None') { $params += @{ PrivateDnsZone = $PrivateDNSZoneResourceID } }

# create the flexible mysql server
$flexServer = New-AzMySqlFlexibleServer @params 