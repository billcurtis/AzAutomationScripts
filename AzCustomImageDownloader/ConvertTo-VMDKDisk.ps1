<#
    .DESCRIPTION
       
        Converts a specified VHD file into a VMDK file.

    .INPUTS

        sourceResourceGroupName - Resource Group Name that the Azure Compute Image is located in.

        GalleryName - The Azure Compute Gallery Name that the source image is located in.

        GalleryImageDefinitionName - The name of the image to create a managed disk from.


    .OUTPUTS 

        There is no output for this runbook.


    .NOTES
    
        StarWind V2V Convertor needs to be installed on the runbook worker to the default installation
        path.
        The VHD must have been already downloaded to this 
        Command line reference: https://www.starwindsoftware.com/v2v-help/CommandLineInterface.html

#>

param (

    [Parameter(Mandatory = $true)]    
    [string]$sourceFilePath,
    [Parameter(Mandatory = $true)]
    [string]$SourceFileName
)


# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

Write-Verbose -Message "Starting Runbook: ConvertTo-VMDKDisk"

# Azure Connection Configuration

Write-Verbose -Message "Connecting to Azure through Managed Identity"

# Ensure that Starwind V2V Converter is installed

$isStarWind = Test-Path 'C:\Program Files\StarWind Software\StarWind V2V Converter'

if (!$isStarWind) { Write-Error "Starwind  V2V Convertor is not installed" }

Write-Verbose -Message "Starwind was found to be installed."

# Fixup $sourceFilePath variable

if (($sourceFilePath.EndsWith('\')) -eq $false) { $sourceFilePath = "$sourceFilePath\" }

Write-Verbose -Message  "Inputs are: $sourceFilePath, $SourceFileName"

try {

    Write-Verbose -Message 'Attempting to convert $SourceFileName'

    $infilePath = "$sourceFilePath$sourceFileName"
    $outfilepath = $infilePath.Replace('vhd', 'vmdk')

    Write-Verbose -Message "In file path = $infilePath, Out file path = $outfilepath"

    Set-Location -Path 'C:\Program Files\StarWind Software\StarWind V2V Converter'

    $expression = '.\V2V_ConverterConsole.exe convert in_file_name="' + "$infilePath" + '" out_file_name="' + "$outfilepath" + '" out_file_type=ft_vmdk_ws_thick'

    Write-Verbose "Command to run is: $expression"

    $ErrorActionPreference = "Continue"
    Invoke-Expression -Command $expression -ErrorAction SilentlyContinue
    $ErrorActionPreference = "Stop"

}
catch {

    Get-ChildItem -Path $sourceFilePath `
    | Where-Object { $_.Name -match 'VMDK' -and $_.Name -match ($sourceFileName.TrimEnd('.vhd')) } `
    | Remove-Item -Force -Confirm:$False

}

# End Runbook
Write-Verbose "ConvertTo-VMDKDisk runbook has succesfully concluded its run."
