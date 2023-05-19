 
<#

v1.0

    .DESCRIPTION
       
    Runbook will join a Azure File Share to a ADDS Domain.

    .INPUTS
       
    StorageSubscriptionId - Azure Subscription ID of where the storage account to join to the domain resides.
    
    StorageAccountName - Name of the storage account to join to the domain.

    $StorageResourceGroupName - The resource group name where the storage account resides.

    .NOTES
        
    Pre-reqs:

    1. Service Principal with the following minimum rights over the subscription (Reader, Storage Account Contributor)

    2. Automation Managed Identity needs to be enabled and have owner of the Automation Resource Group, Key Vault 
       Secrets User for the Key Vault containing the domain join password, and Read for the subscription.

    3. The following Azure Automation variables (all strings) needs to be created and populated:
        a. domainUserName = The domain user account that the script will use to join SA to the domain.
        b. KeyVaultName = The name of the KV hosting the domain join password
        c. KeyVaultSecretName = Then name of the secret holding the domain join password to retrieve from the KV.
        d. OuDistinguishedName = # AD OU where the Azure FS will create a computer account
        e. Service Principal that was created in Step 1.

    4. A Windows Hybrid worker to run the runbook on.   The following PowerShell modules need to be installed:
        a. Az
        b. ActiveDirectory
        c. AzFilesHybrid

    5. Note: The domain account that will be used to join the Storage Account to the domain MUST have create object rights in ADDS.

    6. Storage SPN Credential - The Client ID and secret of the SPN needs to be stored in the Azure Automation Accounts credential section.

    7. Before running this runbook, make sure that you replace set the "# Static Variables" section to conform to your environment.
#>

param (

    [string]$StorageSubscriptionId,
    [string]$StorageAccountName,
    [string]$StorageResourceGroupName

)


# Static Variables

$AutomationAccountName = "automation01-aa"   # Automation Account Name
$domainUserNameVariableName = "domainUserName"  # Domain username (contoso\domainjoiner) that will be joining the account
$keyVaultNameVariableName = "keyVaultName" # Key vault name that you will be using
$keyVaultSecretVariableName = "keyVaultSecretName"  # Name of secret to retrieve
$ouDistinguishedVariableName = "OuDistinguishedName"  # AD OU where the Azure FS will create a computer account
$storageSPNCredentialName = "join-storageaccounts-sp"  # Name of a SPN that has Contributor access to the RG of the Azure FS

# Import Modules
Import-Module az.automation
Import-Module az.accounts
Import-Module az.keyvault

# Set Preferences

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

# Log in to Azure and get access token

$runbookContext = (Connect-AzAccount -Identity).Context
Set-AzContext -SubscriptionID $runbookContext.Subscription | Out-Null
$azContext = Get-AzContext


# Get Azure Automation Account's resource group name

$automationAccountRG = (Get-AzAutomationAccount | Where-Object { $_.AutomationAccountName -match $AutomationAccountName }).ResourceGroupName

# Get variable values

#### get domain user name variable value
$params = @{

    AutomationAccountName = $automationAccountName
    Name                  = $domainUserNameVariableName
    ResourceGroupName     = $automationAccountRG
} 

$domainUserName = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Domain User Name: $domainUserName"

#### get KV identity variable value
$params.Name = $keyVaultNameVariableName
$keyVaultName = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Key Vault Name: $keyVaultName"

#### get KV vault secret name 
$params.Name = $keyVaultSecretVariableName
$keyVaultSecretName = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "Key Vault Secret Name: $keyVaultSecretName"

#### get OU distinguished name
$params.Name = $ouDistinguishedVariableName
$ouDistinguishedName = (Get-AzAutomationVariable @params).value
Write-Verbose -Message "OU Distinguished Name: $ouDistinguishedName"

# get azure automation credential for the SPN that has access to the storage account
$spnCred = Get-AutomationPSCredential -Name $storageSPNCredentialName


# Get the KV Secret for the domain join account
$kvSecret = Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultSecretName -AsPlainText
$kvSecret = ConvertTo-SecureString $kvSecret -AsPlainText -Force

# Create PowerShell Credential
[pscredential]$creds = New-Object System.Management.Automation.PSCredential ($domainUserName, $kvSecret)

# Open a local session with the domain creds and join the storage account to azure
$VerbosePreference = 'SilentlyContinue'
$sessionConfigName = (New-Guid).Guid

$params = @{

    Name                                = $sessionConfigName
    RunAsCredential                     = $creds
    MaximumReceivedDataSizePerCommandMB = 1000
    MaximumReceivedObjectSizeMB         = 1000
}
           
Register-PSSessionConfiguration @params


Invoke-Command -ComputerName localhost -ConfigurationName $sessionConfigName -Credential $creds -ScriptBlock { 

    # Import Modules
    Import-Module -Name AzFilesHybrid
    Import-Module -Name ActiveDirectory

    # Preferences
    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"

    # Connect using service principal

    $params = @{

        ServicePrincipal = $true
        Credential       = $using:spnCred
        TenantID         = $using:azContext.Tenant.Id
    }

    Connect-AzAccount @params | Out-Null
    Set-AzContext -SubscriptionID $Using:StorageSubscriptionId | Out-Null

    # Join the Storage Account to the Domain

    $params = @{

        ResourceGroupName                   = $Using:StorageResourceGroupName
        StorageAccountName                  = $Using:StorageAccountName
        SamAccountName                      = $Using:StorageAccountName
        DomainAccountType                   = 'ComputerAccount'
        OrganizationalUnitDistinguishedName = $Using:OuDistinguishedName
        EncryptionType                      = "AES256"
        Verbose                             = $true

    }

    Write-Verbose -Message "Joining $($Using:StorageAccountName) to the domain"
    Join-AzStorageAccount @params -Confirm:$false


}
$VerbosePreference = 'SilentlyContinue'
Unregister-PSSessionConfiguration $sessionConfigName





 




 