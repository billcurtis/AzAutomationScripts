param(

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,
    [Parameter(Mandatory = $true)]
    [string]$StorageResourceGroupName,
    [Parameter(Mandatory = $true)]
    [string]$keyVaultName,
    [Parameter(Mandatory = $true)]
    [string]$keyName
 
)
 
# import modules
Import-Module Az.KeyVault
Import-Module Az.Storage
 
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
 
Write-Verbose 'Getting Runas Connection'
$connection = Get-AutomationConnection -Name AzureRunAsConnection 
 
Write-Verbose 'Connecting to Azure'
$params = @{
 
    Tenant                = $connection.TenantID
    ApplicationID         = $connection.ApplicationID
    CertificateThumbprint = $connection.CertificateThumbprint
 
}
 
Connect-AzAccount @params -ServicePrincipal
 
Write-Verbose 'Processing Parameters'
 
$params = @{
 
    Name              = $StorageAccountName
    ResourceGroupName = $StorageResourceGroupName
 
}
 
$storageAccount = Get-AzStorageAccount @params
$keyVault = Get-AzKeyVault -Name $keyVaultName
$expiryDate = [System.DateTime]::Now.AddMonths(3)
 
 
Write-Verbose "Creating new Azure KeyVault Key for vault $($keyVault.VaultName)"
 
$params = @{
 
    VaultName   = $keyVault.VaultName
    Name        = $keyName
    Destination = 'Software'
    Expires     = $expiryDate
 
}
 
Add-AzKeyVaultKey @params | Out-Null
 
$params = @{
 
    ResourceGroupName = $storageAccount.ResourceGroupName
    AccountName       = $storageAccount.StorageAccountName
    Keyname           = $keyName
    KeyVaultUri       = $keyVault.VaultUri
 
 
}
 
Write-Verbose "Applying key to Storage Account $($storageAccount.StorageAccountName)"
Set-AzStorageAccount  @params -KeyvaultEncryption | Out-Null