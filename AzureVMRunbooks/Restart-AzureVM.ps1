<#
    .DESCRIPTION
       Restarts a Azure Virtual Machine

    .INPUTS

        ResourceGroupName - Resource Group name of the resource.

        VMName - Name of the resource.


    .NOTES
    
        Outputs whether or not the VM Start was successful.

#>

param (

    [string]$ResourceGroupName,
    [string]$VMName

)


# Import Modules

Import-Module Az.Compute
Import-Module Az.Accounts

# Preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"


$connectionName = "AzureRunAsConnection"
try {
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
    | Out-Null
}
catch {
    if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    }
    else {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Inputs
Write-Verbose "Inputs are ResourceGroupName = $ResourceGroupName, VMName = $VMName "


try {

    # Restart Virtual Machine

    $params = @{

        ResourceGroupName = $ResourceGroupName
        Name              = $VMName

    }

    $output = Restart-AzVM @params  

    $output.Status

}

catch {

    Write-Verbose "Exception thrown: $($_.Exception.Message)"
    Write-Output "Failed"

}

 