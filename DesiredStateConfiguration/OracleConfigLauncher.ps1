Set-Location "C:\dscscripts"
. C:\dscscripts\OracleClientConfig.ps1
#OracleClientInstallation
Start-DscConfiguration -Path "c:\dscscripts\OracleClientInstallation" -Wait -Verbose -Force -ErrorAction stop
