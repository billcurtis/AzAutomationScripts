# This is the sample coordinator runbook to create the disk image

# Just set the 6 variables and the image will be created on the runbook worker that you specify. 

# Set Variables - Should put this in Variables in the Automation account.

$SourceResourceGroupName = 'ImageCreation-rg'
$TargetResourceGroupName = 'ImageCreation-rg'
$GalleryName = 'MyIBSIG'
$GalleryImageDefinitionName = 'win10SessionHost'
$downloadPath = 'E:\Downloads'
$sourceFilePath = 'E:\Downloads'


# 1. Get the latest version of the  source image

$params = @{

    SourceResourceGroupName    = $SourceResourceGroupName
    GalleryName                = $GalleryName
    GalleryImageDefinitionName = $GalleryImageDefinitionName

}


$latestImage = (.\Get-LatestAzCustomImage.ps1 @params) | ConvertFrom-Json

# 2. Create a managed disk from latest image

$params = @{

    SourceRGLocation           = $latestImage.Location
    SourceResourceGroupName    = $SourceResourceGroupName
    TargetResourceGroupName    = $TargetResourceGroupName
    GalleryName                = $GalleryName
    GalleryImageDefinitionName = $GalleryImageDefinitionName
    imageVersionNumber         = $latestImage.Name


}

$managedDisk = (.\Create-AzManagedDiskFromImage.ps1 @params) | ConvertFrom-Json

# 3. Export the just created managed disk

$params = @{

    DiskName                = $managedDisk.Name
    TargetResourceGroupName = $TargetResourceGroupName
    downloadPath            = $downloadPath

}

.\Export-AzManagedDisk.ps1 @params

# 4. Get rid of the managed disk as we no longer need it.

$params = @{

    DiskName                = $managedDisk.Name
    TargetResourceGroupName = $TargetResourceGroupName

}

.\Remove-AzManagedDisk.ps1 @params

# 5. Convert downloaded disk to a VMDK file.

$sourceFileName = "$($managedDisk.Name).vhd"

$params = @{

    sourceFilename = $sourceFileName
    sourceFilePath = $sourceFilePath

}

.\ConvertTo-VMDKDisk.ps1 @params

	 