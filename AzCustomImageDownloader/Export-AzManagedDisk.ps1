<#
    .DESCRIPTION
       
        Downloads the provided managed disk locally to a path on the runbook worker.

    .INPUTS

        DiskName - Name of the disk created by the Create-AzManagedDiskfromImage runbook.

        targetResourceGroupName - The resource group in when the DiskName resource exists.

        $downloadPath - Path where the disk will be copied.


    .OUTPUTS 

        There are no outputs.


    .NOTES
    
        1. The Az module needs to be installed on the runbook worker.
        2. AzCopy needs to be installed.
        

#>

param (

    [Parameter(Mandatory = $true)]    
    [string]$DiskName,
    [Parameter(Mandatory = $true)]    
    [string]$targetResourceGroupName,
    [Parameter(Mandatory = $true)]    
    [string]$downloadPath 

)

# Import Required Modules

Import-Module Az.Compute

# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"


Write-Verbose -Message "Starting Runbook: Export-AzManagedDisk"

# Azure Connection Configuration

Write-Verbose -Message "Connecting to Azure through Managed Identity"
Connect-AzAccount -Identity | Out-Null

# Inputs
Write-Verbose -Message  "Inputs are:  $targetResourceGroupName, $DiskName, $downloadPath"

# Check to see if AzCopy is available

Write-Verbose -Message "Checking AzCopy availablity..."

if (!(Get-Command "azcopy.exe" -ErrorAction SilentlyContinue)) { 
    Write-Error "Unable to find AzCopy.exe in your PATH. Please make sure AzCopy has been installed."
}
else {

    Write-Verbose -Message "AzCopy was found in path. Yay!"
}

# Check to see if download path exists

if (($downloadPath.EndsWith('\')) -eq $false) { $downloadPath = "$downloadPath\" }
New-Item -Path $downloadPath -ItemType Directory -Force | Out-Null

# Grant Disk Access

Write-Verbose -Message "Granting Disk Access for: $DiskName"

$params = @{
    
    DiskName          = $DiskName           
    ResourceGroupName = $targetResourceGroupName
    DurationInSecond  = 7200
    Access            = 'Read'
 
}

$disk2Copy = Grant-AzDiskAccess @params

# Peform the Download

$downloadString = "$downloadPath$DiskName.vhd"
azcopy copy $disk2copy.AccessSAS $downloadString  --blob-type PageBlob --force-if-read-only

# End Runbook

Write-Verbose "Export-AzManagedDisk runbook has succesfully concluded its run."