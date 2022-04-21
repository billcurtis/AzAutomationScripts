<#
    .DESCRIPTION
       
        Revokes access and removes the managed disk created in Create-AzManagedDiskfromImage runbook.

    .INPUTS

        DiskName - Name of the disk created by the Create-AzManagedDiskfromImage runbook.

        targetResourceGroupName - The resource group in when the DiskName resource exists.
    

    .OUTPUTS 

        There are no outputs.


    .NOTES
    
        1. The Az module needs to be installed on the runbook worker.
        

#>

param (

    [Parameter(Mandatory = $true)]    
    [string]$DiskName,
    [Parameter(Mandatory = $true)]    
    [string]$targetResourceGroupName

)

# Import Required Modules

Import-Module Az.Compute

# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"


Write-Verbose -Message "Starting Runbook: Remove-AzManagedDisk"

# Azure Connection Configuration

Write-Verbose -Message "Connecting to Azure through Managed Identity"
Connect-AzAccount -Identity | Out-Null

# Inputs
Write-Verbose -Message  "Inputs are:  $targetResourceGroupName, $DiskName"

# Get
$disk = $null
$disk = Get-AzResource | Where-Object { $_.Name -eq $DiskName -and $_.ResourceGroupName -match $targetResourceGroupName }

if (!$disk) { Write-Verbose -Message "No disk found to delete." }
else {

    Write-Verbose -Message "Revoking disk access for $DiskName"

    $params = @{

        ResourceGroupName = $targetResourceGroupName
        DiskName          = $DiskName

    }

    Revoke-AzDiskAccess @params

    Write-Verbose -Message "Removing Disk: $DiskName"

    $params = @{

        ResourceGroupName = $targetResourceGroupName
        DiskName          = $DiskName
        Force             = $true

    }

    Remove-AzDisk @params

} 

# End Runbook

Write-Verbose "Remove-AzManagedDisk runbook has succesfully concluded its run."