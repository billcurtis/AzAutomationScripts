<#
    .DESCRIPTION
       
    Coordinator Runbook for OS Customizations. Basically this runbook is a container
    for running any OS customizations. 

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


# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Write-Verbose -Message "Starting Runbook: Set-OSCustomizations"


# 1. Set the Paging File back to the C: drive

$params = @{

    sourceFilename = $sourceFileName
    sourceFilePath = $sourceFilePath

}

.\Set-VHDPagingFile.ps1  @params

# 2. Get rid of pesky setupComplete.cmd

$params = @{

    sourceFilename = $sourceFileName
    sourceFilePath = $sourceFilePath

}

.\Remove-SetupCompleteCommands.ps1  @params


# End Runbook
Write-Verbose "Set-OSCustomizations runbook has succesfully concluded its run."