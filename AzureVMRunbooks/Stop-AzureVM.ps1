<#
    .DESCRIPTION
       Stops a Azure Virtual Machine


    .INPUTS

        ResourceGroupName - Resource Group name of the resource.

        VMName - Name of the resource.

    .NOTES
    
        Outputs whether or not the VM Start was successful.

#>

param (

[string]$ResourceGroupName,
[string]$VMName,
[string]$subscriptionID
)


# Import Modules

Import-Module Az.Compute
Import-Module Az.Accounts

# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"



# Connect to Azure 
Connect-AzAccount -Identity -Subscription $subscriptionID



# Inputs
Write-Verbose "Inputs are ResourceGroupName = $ResourceGroupName, VMName = $VMName"


try {

    # Stop Virtual Machine

    $params = @{

        ResourceGroupName = $ResourceGroupName
        Name              = $VMName

    }

    $output = Stop-AzVM @params  -Force

    $output.Status

}

catch {

    Write-Verbose "Exception thrown: $($_.Exception.Message)"
    Write-Output "Failed"

}

 