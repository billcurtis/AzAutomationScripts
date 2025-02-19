Configuration TimeZoneCustom {
    Import-DscResource -ModuleName ComputerManagementDSC -Name TimeZone
    TimeZone TimeZoneConfig {
        TimeZone = "Eastern Standard Time"
        IsSingleInstance = 'Yes'
    }

}

TimeZoneCustom

Rename-Item -path .\TimeZoneCustom\localhost.mof -NewName TimeZoneCustom.mof