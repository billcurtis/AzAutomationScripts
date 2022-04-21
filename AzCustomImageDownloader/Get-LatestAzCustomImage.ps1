<#
    .DESCRIPTION
       
        Gets the latest custom image metadata from the specified Azure Compute Gallery.

    .INPUTS

        sourceResourceGroupName - Resource Group Name that the Azure Compute Image is located in.

        GalleryName - The Azure Compute Gallery Name that the source image is located in.

        GalleryImageDefinitionName - The name of the image to create a managed disk from.


    .OUTPUTS 

        Ouputs the customer image latest version metadata in JSON format.


    .NOTES
    
        The Az module needs to be installed on the runbook worker.

#>

param (

    [Parameter(Mandatory = $true)]    
    [string]$sourceResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$GalleryName,
    [Parameter(Mandatory = $true)]
    [string]$GalleryImageDefinitionName

)

# Import Required Modules

Import-Module Az.Compute

# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Write-Verbose -Message "Starting Runbook: Get-LatestAzCustomImage"

# Azure Connection Configuration

Write-Verbose -Message "Connecting to Azure through Managed Identity"
Connect-AzAccount -Identity | Out-Null

# Inputs
Write-Verbose -Message  "Inputs are:  $sourceResourceGroupName, $GalleryName, $GalleryImageDefinitionName"

# Get the latest GalleryImage

Write-Verbose -Message "Getting the latest image version for $GalleryImageDefinitionName"

$params = @{

    GalleryImageDefinitionName = $GalleryImageDefinitionName
    GalleryName                = $GalleryName
    ResourceGroupName          = $sourceResourceGroupName
 
}
  
$sourceImgVer = Get-AzGalleryImageVersion @params | Select-Object -Last 1 

# Write Output as Json

Write-Verbose -Message "Writing disk information output to JSON"
$sourceImgVer | ConvertTo-Json -Depth 100 -Compress

# End Runbook
Write-Verbose "Get-LatestAzCustomImage runbook has succesfully concluded its run."
