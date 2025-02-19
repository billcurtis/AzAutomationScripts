# Create a package that will audit and apply the configuration (Set)
$params = @{
    Name          = 'TimeZoneCustom'
    Configuration = '.\TimeZoneCustom\TimeZoneCustom.mof'
    Type          = 'AuditAndSet'
    Force         = $true
}
New-GuestConfigurationPackage @params