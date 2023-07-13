<#
    .DESCRIPTION
       
    Removes all SetupComplete commands during Windows Setup from an Azure based VM image so that
    the image can be repurposed for either Hyper-V or VMware images.

    .INPUTS

    SourceFilePath - Path to the VHD image
    SourceFileName - VHD file name 

    .OUTPUTS 

    There is no output for this runbook.

    .NOTES   

#>

param (

    [Parameter(Mandatory = $true)]    
    [string]$sourceFilePath,
    [Parameter(Mandatory = $true)]
    [string]$sourceFileName
    
)

# Import Module 

Import-Module Storage


# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Write-Verbose -Message "Starting Runbook: Remove-SetupCompleteCommands"

$ErrorActionPreference = "Stop"

# Mount the VHD

if (($sourceFilePath.EndsWith('\')) -eq $false) { $sourceFilePath = "$sourceFilePath\" }

Mount-DiskImage -ImagePath ($sourceFilePath + $sourceFileName) | Out-Null

$mountedDrive = (Get-Volume | Where-Object { $_.FileSystemLabel -eq 'Windows' -and $_.DriveLetter -ne 'C' } | Select-Object DriveLetter).DriveLetter

$setupCompleteFilePath = $mountedDrive + ':\Windows\Setup\Scripts\'


try {

    # Remove the setup complete command.
    
    $setupCmdPresent = Get-ChildItem -Path $setupCompleteFilePath | Where-Object { $_.Name -eq 'SetupComplete.cmd' }

    if ($setupCmdPresent) {

        Write-Verbose 'SetupComplete.cmd was found. Deleting.'
        Remove-Item -Path ($setupCompleteFilePath + "SetupComplete.cmd") -Force

    }
    else {

        Write-Verbose 'SetupComplete.cmd was not found.'
        
    }

    # Clean up

    Dismount-DiskImage -ImagePath ($sourceFilePath + $sourceFileName) | Out-Null

}
catch {

    throw $_
    Dismount-DiskImage -ImagePath ($sourceFilePath + $sourceFileName) | Out-Null

}

# End Runbook
Write-Verbose "Remove-SetupCompleteCommands runbook has succesfully concluded its run."