<#
.DESCRIPTION
    This runbook changes the SKU of a virtual machine to an available SKU from a preferred list when an alert is triggered indicating that the VM cannot be started due to capacity constraints.

.INPUTS
    WebhookData - The webhook payload that is passed to the runbook via the Azure Monitor alert common schema.

.OUTPUTS
    PSAzureOperationResponse - The response from the Update-AzVM cmdlet.

.NOTES
    File Name      : Update-VMSkuOnAlert-RB.ps1
    Author         : Bill Curtis
    Date Created   : 09/12/2025
    Prerequisite   : Azure PowerShell module
    Purpose        : To change the SKU of a virtual machine when an alert is triggered.

    This is an Azure Automation Runbook version of the Update-VMSKUonAlert.ps1 script.

    static variables to set:
    $automationAccountRG = "automation-eus2-rg" # resource group of the automation account
    $automationAccountName = "automation-eus2-aa" # name of the automation account  
    The automation account must have a variable named "PreferredVMSKUs" that contains a JSON array of preferred VM SKUs, for example:
    
    [
        "Standard_D2s_v3",
        "Standard_D4s_v3",
        "Standard_D8s_v3"
    ]

    * Requires the Azure PowerShell module to be imported into the Automation Account.
    * The Automation Account must be assigned a Managed Identity with the following roles:
        - Reader role on the subscription
        - Virtual Machine Contributor role on the resource group(s) containing the virtual machines to be managed.
    * The alert that triggers this runbook must be configured to use the "Azure Monitor alert common schema" for the webhook payload.
    * Requires the Az.Compute module to be imported into the Automation Account.
    * Requires PowerShell 7.2 or later in the Automation Account.

#> 


[OutputType("PSAzureOperationResponse")]
param
(
    [Parameter (Mandatory = $false)]
    $WebhookData
)
 
# functions

function Get-AvailableSKU {
    param (
        [string[]]$preferredVMSKUs,
        [string]$Location,
        [string]$vmZone
    )

    foreach ($sku in $preferredVMSKUs) {
        $availability = Get-AzComputeResourceSku -Location $Location  | Where-Object { $_.Name -eq $sku }   

        if ($availability) {

            if ($availability.Restrictions.Restrictioninfo.Zones -notcontains $vmZone) {
                        
                return $sku            
            }
            else { Write-Verbose -Message "No Data" }  
        
        }

    }
}

# set preferences

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# set static variables
$automationAccountRG = "automation-eus2-rg" # resource group of the automation account
$automationAccountName = "automation-eus2-aa" # name of the automation account

# convert webhook data to json 
$reqbody = $WebhookData.RequestBody | ConvertFrom-Json

 
# Log into Azure Automation using Identity

Connect-AzAccount -Identity | Out-Null
 
# get preferred SKUs
Write-output "Retrieving preferred VM SKUs"

$params = @{
    
    ResourceGroupName     = $automationAccountRG
    AutomationAccountName = $automationAccountName
    Name                  = "PreferredVMSKUs"
}

$preferredVMSKUs = (Get-AzAutomationVariable  @params).Value | ConvertFrom-Json

Write-Output "Preferred VM SKUs: $preferredVMSKUs"

# get vminfo
$vmInfo = Get-AzVM -ResourceId $reqbody.data.essentials.alertTargetIDs[0]
$vmSize = ($vmInfo.HardwareProfile).VmSize
$vmZone = ($vmInfo).Zones
Write-Verbose -Message "VMname = $($vmInfo.Name), SKU = $vmSize, Availability Zone = $vmZone"

# see if av zone is blank. if so, we cannot complete the sku change
if (!$vmZone) {

    Write-Output "Virtual Machine $($vmInfo.Name)is not set to an Availability Zone. Cannot change SKU."
    exit

}

# see if VM is currently running, If so, we need to exit the runbook
if ($vmInfo.ProvisioningState -eq "Succeeded" -and $vmInfo.PowerState -eq "VM running") {

    Write-Output "Virtual Machine $($vmInfo.Name) is currently running. We don't need the SKU change."
    exit

}


# Get Available SKUs
$params = @{

    preferredVMSKUs = $preferredVMSKUs
    location        = $vmInfo.Location
    vmZone          = $vmZone

}

$newSKU = Get-AvailableSKU @params

if (!$newSKU) {

    Write-Output "No available SKUs found in preferred list. Cannot change SKU."
    exit

}

Write-Output "Changing VM SKU on $($vmInfo.Name) from $vmSize to $newSKU"

# update VM SKU
$vmInfo.HardwareProfile.VmSize = $newSKU
$params = @{
    ResourceGroupName = $vmInfo.ResourceGroupName
    VM                = $vmInfo
    ErrorAction       = 'Stop'
}
Update-AzVM @params

# start virtual machine
$params = @{
    ResourceGroupName = $vmInfo.ResourceGroupName
    Name              = $vmInfo.Name
    ErrorAction       = 'Stop'
}
Start-AzVM @params