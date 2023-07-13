<#
    .DESCRIPTION
       
        Creates a Managed Disk from the specified Azure Compute Image and then output the managed disk
            information in JSON format.  This script is part of a larger solution to download custom
            Azure image OS Disks and then convert them to VMDK files for local VMware use.

    .INPUTS

        sourceRGLocation - Geographical location that the source image is located in. (EastUS, WestUS, etc.)

        sourceResourceGroupName - Resource Group Name that the Azure Compute Image is located in.

        targetResourceGroupName - The target resource group to create the managed disk.

        GalleryName - The Azure Compute Gallery Name that the source image is located in.

        GalleryImageDefinitionName - The name of the image to create a managed disk from.

        imageVersionNumber - Image version number that the


    .OUTPUTS 

        Ouputs the created managed disk in JSON format.


    .NOTES
    
        The Az module needs to be installed on the runbook worker.

#>

param (

    [Parameter(Mandatory = $true)]
    [string]$sourceRGLocation,
    [Parameter(Mandatory = $true)]    
    [string]$sourceResourceGroupName,
    [Parameter(Mandatory = $true)]    
    [string]$targetResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$GalleryName,
    [Parameter(Mandatory = $true)]
    [string]$GalleryImageDefinitionName,
    [Parameter(Mandatory = $true)]
    [string]$imageVersionNumber

)

# Import Required Modules

Import-Module Az.Compute

# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Azure Connection Configuration

Write-Verbose -Message "Connecting to Azure through Managed Identity"
Connect-AzAccount -Identity | Out-Null

# Inputs
Write-Verbose -Message "Starting Runbook: CreateAzManagedDiskFromImage"
Write-Verbose -Message  "Inputs are: $sourceRGLocation, $sourceResourceGroupName, $targetResourceGroupName, $GalleryName, $imageVersionNumber"

# Get the image infomration of what we are going to create a managed disk from.

Write-Verbose -Message "Getting the image version for $GalleryImageDefinitionName"

$params = @{

    GalleryImageDefinitionName = $GalleryImageDefinitionName
    GalleryName                = $GalleryName
    ResourceGroupName          = $sourceResourceGroupName
    Name                       = $imageVersionNumber
 
}
  
$sourceImgVer = Get-AzGalleryImageVersion @params
 
# Create New Disk Configuration

Write-Verbose -Message "Creating a Disk Configuration for image ID: $($sourceImgVer.Id) "

$params = @{
 
    Location              = $sourceRGLocation
    CreateOption          = 'FromImage'
    GalleryImageReference = @{Id = $sourceImgVer.Id }
    
}
 
$diskConfig = New-AzDiskConfig @params  
  
# Create the disk in the specified resource group.

Write-Verbose -Message "Creating the managed disk $Diskname in resource group $targetResourceGroupName "
$DiskName = "$GalleryImageDefinitionName-$imageVersionNumber"
 
$params = @{
 
    Disk              = $diskConfig
    ResourceGroupName = $targetResourceGroupName
    DiskName          = $DiskName
 
} 
 
$diskinfo = New-AzDisk @params  

# Write Output as Json

Write-Verbose -Message "Writing disk information output to JSON"
$diskinfo | ConvertTo-Json -Depth 100 -Compress

# End Runbook
Write-Verbose "Create-AzManagedDiskFromImage runbook has succesfully concluded its run."