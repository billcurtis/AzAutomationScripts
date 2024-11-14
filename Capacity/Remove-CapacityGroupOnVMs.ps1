<#
.DESCRIPTION 
This Azure Automation Runbook removes VMs from all capacity reservation groups in a resource group based on the VM's deallocated state, 
subscription ID, and resource group name which are entered in the static variables section.

.INPUTS
    SubscriptionID, ResourceGroupName, and tenantID are static variables in the runbook.

.OUTPUTS
    None

.NOTES
 The script is intended to be run in an Azure Automation account. The automation account's Managed Identity must have the 
 necessary RBAC permissions (VM Contributor) to exceute the script. The script uses the Az.Compute module.
 Run this script on a schedule to remove VMs from capacity reservation groups that are deallocated. Eventually all VMs 
 will be removed from the capacity reservation group.
#>

# static variables
$subscriptionId = "c7f13507-5347-4fa3-9fa2-f6ea98f582ea"
$resourceGroupName = "vcme-msn-dra-rg"
$tenantId = "d1ee1acd-bc7a-4bc4-a787-938c49a83906"

# import the Az module
$VerbosePreference = "SilentlyContinue"
Import-Module Az.Compute

# preferences
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# connect to Azure using the managed identity of the automation account
Connect-AzAccount -Identity -Subscription $subscriptionId -Tenant $tenantId

try {
    
    # get the list of VMs in the resource group that are deallocated
    # using graph query to get the VMs due to possibly thousands of VMs in the resource group

    $query = @"
Resources
| where type == "microsoft.compute/virtualmachines"
| where isnotnull(properties.capacityReservation.capacityReservationGroup)
| where PowerState = properties.extended.instanceView.powerState.code == "PowerState/deallocated" 
| where subscriptionId == "$subscriptionID"
| where ResourceGroup = resourceGroup == "$resourceGroupName"
| project 
    VMName = name,
    ResourceGroup = resourceGroup
"@
 
    $vms = Search-AzGraph -Query $query

    Write-Verbose -Message "Found $($vms.Count) VMs in the resource group that are deallocated."

    # remove vms from capacity reservation group
    foreach ($vm in $vms) {
        
        $vm | Write-Output
        Write-Verbose -Message "Removing VM $($vm.VMName) from capacity reservation group."

        $params = @{

            ResourceGroupName = $vm.ResourceGroup
            VMName            = $vm.VMName

        }

        $virtMachine = Get-AzVM @params

        $params = @{

            ResourceGroupName        = $vm.ResourceGroup
            VM                       = $virtMachine
            CapacityReservationGroup = $null
            AsJob                    = $true

        }

        Update-AzVM @params
 
    }
    
}
catch {

    Write-Error -Message $_.Exception.Message

}
finally {

    Write-Verbose -Message "Script completed."
    Write-Verbose -Message "Removed $($vms.Count) VMs from capacity reservation group."
    $VerbosePreference = "SilentlyContinue"
    $ErrorActionPreference = "Continue"

}

