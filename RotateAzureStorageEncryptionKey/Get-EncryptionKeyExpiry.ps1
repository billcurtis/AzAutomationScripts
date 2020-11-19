param(

    [Parameter(Mandatory=$true)]
    [string]$KeyName,
    [Parameter(Mandatory=$true)]
    [string]$keyVaultName
 
 )
 
 
 # import modules
 Import-Module Az.KeyVault
 Import-Module Az.Storage
 Import-Module Az.Resources
 
 
 $ErrorActionPreference = "Stop"
 $VerbosePreference = "Continue"
 
 Write-Verbose 'Getting Runas Connection'
 $connection = Get-AutomationConnection -Name AzureRunAsConnection 
 
 
 Write-Verbose 'Connecting to Azure'
 $params = @{
 
 Tenant = $connection.TenantID
 ApplicationID = $connection.ApplicationID
 CertificateThumbprint = $connection.CertificateThumbprint
 
 }
 
 Connect-AzAccount @params -ServicePrincipal
 
 
 Write-Verbose 'Processing Parameters'
 $keyVault = Get-AzKeyVault -Name wcurtis-kv
 $expiryDate = (Get-AzKeyVaultKey -VaultName $keyVault.VaultName -Name $keyName).Expires 
 $dateplus30 = [System.DateTime]::Now.AddMonths(1)
 $report = @()
 #$runasExpiration = (Get-AzADAppCredential -ApplicationId ($connection.ApplicationID)).EndDate
 
 #if ($runasExpiration -lt $dateplus30) { $runasExpiration = $true }
 if ($expiryDate -lt $dateplus30) { $keyExpiration = $true }
 
 
 
 Write-Verbose 'Outputing Report'
 
 $report += [pscustomobject]@{
 
 AzAutomateGoingtoExpire = $null
 AzKeyVaultKeyGoingtoExpire = $keyExpiration
 
 }
 
 $report | ConvertTo-Json -Depth 8 -Compress
 
 
 