
<#  
    
    .DESCRIPTION
       Backs up Azure Private DNS Zone files to a specified storage account.  This runbook will cycle through all Azure Private DNS
        Zones and export their records to text files which will be stored in a individual blob for each zone.


    .INPUTS

        stgacctName - Storage Account name of where to save the Zone files.

        container - Name of the container where to save the blobs.

        localAcctName - Azure Credential that has local admin rights on the Hybrid runbook worker.


    .NOTES
    
        1. A hybrid runbook worker has to have both the AZ PowerShell cmdlets and Azure CLI installed.
        2. The hybrid runbook worker VM will require that a System Assigned managed identity be assigned.
        3. The storage account that the Private DNS Zones will go to, will require permissions for the hybrid
           runbook worker's managed identity.
        4. There is no cleanup done of older records.  This will have to be a manual process.

#>
param (

    [Parameter(Mandatory = $true)]
    [string]$stgacctName,
    [Parameter(Mandatory = $true)]
    [string]$container,
    [Parameter(Mandatory = $true)]
    [string]$localAcctName
    
)
    
# Log in with Azure PowerShell as we need to get the Azure Automation credential that will run the Invoke-Command

Add-AzAccount -identity  
    
$localCred = Get-AutomationPSCredential -Name $localAcctName


# Run a Invoke-Command so we are out of the automation sandbox

Invoke-Command -ComputerName localhost -Credential $localCred -ScriptBlock {

    try {
    
        $stgacctName = $Using:stgacctName
        $container = $Using:container
    
        # Set Variables
    
        $ErrorActionPreference = 'Stop'
        $VerbosePreference = 'Continue'
    
        # Logon to Azure using Azure CLI

        Write-Verbose 'Logging into Azure using Azure CLI'
        $expression = "az login --identity"
        $loginStatus = (Invoke-Expression -Command $expression) | ConvertFrom-Json
        Write-Verbose "Tenant ID is $($loginStatus.tenantId)"
    
        # Check and see if we got a result from logging in via the Azure CLI. Throw error if we don't get any Tenant ID
    
        if ($loginStatus.TenantID) {
    
            $date = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd-HHmm")
    
            # Get CLI version for logging purposes
    
            $expression = "az version"
            $cliversion
    
            # Get list of all Private DNS Zones
    
            $expression = "az network private-dns zone list"
            $privateDnsZones = Invoke-Expression -Command $expression | ConvertFrom-Json
    
    
            # Set local location
            Set-Location -Path 'C:\temp'
    
    
            # Go through and backup each DNS Zone
    
            foreach ($privateDnsZone in $privateDnsZones) {
    
                $expression = "az network private-dns zone export --name $($privateDnsZone.Name) --resource-group $($privateDnsZone.resourceGroup)"
                Invoke-Expression -Command $expression | Out-File "./Backup-$($privateDnsZone.Name)-$date.txt"
                Get-Item ./
    
                # Copy backup files over to storage blob. 
                # Have to disable error action prefs due to the az cli warnings being logged as errors.
    
                $ErrorActionPreference = "SilentlyContinue"
    
                $expression = "az storage blob directory upload -c $container --account-name $stgacctName -s ./Backup-$($privateDnsZone.Name)*  -d ./$($privateDnsZone.Name)"
                Write-Verbose "Invoking the following expression:  $expression"
                Invoke-Expression -Command $expression
    
                $ErrorActionPreference = "Stop"
    
            }
    
            # Delete Backup Files - Really don't have to do this as the sandbox will be deleted upon completion of script.
    
            Remove-Item -Path .\Backup* -Recurse
    
        }
        else {
    
            Write-Error 'Please check to ensure that the System Managed Identity is set for the Runbook Worker.'
    
    
        }

    }
    catch {

        throw $_

    }
    
}