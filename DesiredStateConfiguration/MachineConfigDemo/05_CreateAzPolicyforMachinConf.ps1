
$uri = "https://testblobwcurtis.blob.core.windows.net/machineconfiguration/TimeZoneCustom.zip?sp=r&st=2025-02-18T15:30:59Z&se=2026-02-18T23:30:59Z&spr=https&sv=2022-11-02&sr=b&sig=DVAvuhq72Yx1AM5vdjjj72lDoSsoWXLwC2BYVL4Doh0%3D"
$contentHash = "D48FC785C2913ADE9CA3A963BE8FCE00D33C3C9018FA13D284E28A1D158087B8"
$contentType = "Custom"
$contentVersion = "1.0.0"
$name = "TimeZoneEast"
$guid = (New-Guid).Guid

$json = @"
'metadata': {
    "category": 'Guest Configuration',
    'guestConfiguration': {
        'name': '$name',
        'version': '$contentVersion',
        'contentType': '$contentType',
        'contentUri': '$uri',
        'contentHash': '$contentHash',
        'configurationParameter': {}
    }
}
"@


$json | Out-File -FilePath .\TimeZoneCustom_DeployIfNotExists.json -Force -Confirm:$false

$PolicyConfig      = @{
    PolicyId      = "$guid"
    DisplayName   = 'TimeZoneEast'
    ContentUri    = $uri
    Description   = 'DeployTimeZoneEast'
    Path          = 'C:\Users\wcurtis\OneDrive\Repos\AzAutomationScripts\DesiredStateConfiguration\MachineConfigDemo\'
    Platform      = 'Windows'
    PolicyVersion = "$contentversion"
    Mode          = 'ApplyAndAutoCorrect'
  }


  New-GuestConfigurationPolicy @PolicyConfig