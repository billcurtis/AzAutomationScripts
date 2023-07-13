<#
    .DESCRIPTION
       
    Changes the page file settings for an Windows Image downloaded from Azure.

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

Write-Verbose -Message "Starting Runbook: Set-VHDPagingFile"

$ErrorActionPreference = "Stop"

# Mount the VHD

if (($sourceFilePath.EndsWith('\')) -eq $false) { $sourceFilePath = "$sourceFilePath\" }

Mount-DiskImage -ImagePath ($sourceFilePath + $sourceFileName) | Out-Null

$mountedDrive = (Get-Volume | Where-Object { $_.FileSystemLabel -eq 'Windows' -and $_.DriveLetter -ne 'C' } | Select-Object DriveLetter).DriveLetter

$registeryHive = $mountedDrive + ':\Windows\System32\config\System'

$guid = (New-Guid).Guid

$expression = "reg load HKLM\$guid $registeryHive"

Invoke-Expression -Command $expression

$pfDriveLetter = 'C:'

try {

    # Set Registry Settings

    $params = @{

        Path  = "HKLM:\$guid\ControlSet001\Control\Session Manager\Memory Management"
        Name  = 'ExistingPageFiles'
        Value = "\??\$pfDriveLetter\pagefile.sys"
        Force = $true

    }

    Set-ItemProperty @params | Out-Null


    $params = @{

        Path  = "HKLM:\$guid\ControlSet001\Control\Session Manager\Memory Management"
        Name  = 'PagingFiles'
        Value = "?:\pagefile.sys"
        Force = $true

    }

    Set-ItemProperty @params | Out-Null


    # Clean up

    $expression = "reg unload HKLM\$guid"
    [gc]::collect()
    Invoke-Expression -Command $expression 
    Start-Sleep -Seconds 10
    Dismount-DiskImage -ImagePath ($sourceFilePath + $sourceFileName) | Out-Null


}
catch {

    $expression = "reg unload HKLM\$guid"
    [gc]::collect()
    Invoke-Expression -Command $expression 
    Start-Sleep -Seconds 10
    Dismount-DiskImage -ImagePath ($sourceFilePath + $sourceFileName) | Out-Null
    Write-Error "Failed to set Registry settings."

}


# End Runbook
Write-Verbose "Set-VHDPagingFile runbook has succesfully concluded its run."