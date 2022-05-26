<#
    .DESCRIPTION
       
    This is a sample coordinator runbook that is set to retrieve a specified Azure Automation variable
     generated by the Create-AzDNSbySubnetJSON PowerShell script.

    .INPUTS
    
    All inputs are hardcoded at this time.


    .NOTES
        
    Work in progress.  
    Tailor this runbook for your specific subnet and rename it to something like 
     Set-DNS-<your vNet>-<your subnet> name in Azure Automation.


#>

# Load Modules

    # No module

# Connect to identity

Connect-AzAccount -Identity

# Set Preferences

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Get 
