  

Configuration OracleClientInstallation {

    param
    (
        # Target nodes to apply the configuration.
        [Parameter()]
        [String]
        $NodeName,
        [Parameter()]
        [String]
        $dataDrive
    )


    #Requires -module @{ModuleName = 'PSDesiredStateConfiguration'; ModuleVersion = '1.1'}
    #Requires -module @{ModuleName = 'xPSDesiredStateConfiguration'; ModuleVersion = '1.1'}

    # Import DSC Modules

    #Import-DscResource -ModuleName @{ModuleName = 'PSDesiredStateConfiguration'; ModuleVersion = '1.1' }
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName 'PSDscResources'

    #Hardcoded Strings - need to paramaterize some of these.
    $architectures = @("86", "64")
    #$dataDrive = "C:"
    #$nodename = "localhost"
    $storageaccountpathx64 = "https://wcurtisdemo.blob.core.windows.net/dscflats/WINDOWS.X64_193000_client.zip?sp=r&st=2023-12-28T15:31:06Z&se=2025-12-28T23:31:06Z&spr=https&sv=2022-11-02&sr=b&sig=n%2Bvz6L1Mzbs825jkhOCLnv4LkUroR%2Fn937nn19pRruA%3D"
    $storageaccountpathx86 = "https://wcurtisdemo.blob.core.windows.net/dscflats/WINDOWS.X86_193000_client.zip?sp=r&st=2023-12-28T15:32:31Z&se=2025-12-28T23:32:31Z&spr=https&sv=2022-11-02&sr=b&sig=tISMZXtvDuvkx72C0WCP1rqx1peFbxiN%2FBopkC5gDIA%3D"
    $tempdir = "$datadrive\Temp"
    #$nodename = "dsc-workbench"


    <# Remove Oracle junction points in order to allow for testing Configuration file.
        You could mess up production if you leave this in place.

    Node $nodename { 

        File "RemoveOracleSyswowJunction" {

            Type            = 'Directory'
            DestinationPath = "C:\windows\SysWOW64\oracle"
            Ensure          = "Absent"  
            Force = $true
        }

        File "RemoveOracleSys32Junction" {

            Type            = 'Directory'
            DestinationPath = "C:\windows\system32\oracle"
            Ensure          = "Absent"  
            Force = $true
        }

    }

    #>
 
    # Install Oracle Clients

    foreach ($arch in $architectures) {

        # Setup the correct paths for the appropriate architecture
   

        Node $nodename { 

            File "SetupTempDir$arch" {

                Type            = 'Directory'
                DestinationPath = $tempdir
                Ensure          = "Present"  
            
            }

            File "SetupExtractDir$arch" {

                Type            = 'Directory'
                DestinationPath = "$tempdir\OracleClient\Extracted(x$arch)"
                Ensure          = "Present"  
                DependsOn = "[File]SetupTempDir$arch"

            }

               
            xRemoteFile "FileDownload$arch" {
                URI = (Get-Variable -Name "storageaccountpathx$($arch)" -ValueOnly)
                DestinationPath = "C:\Temp\WINDOWS.X$($arch)_193000_client.zip"
                MatchSource = $false
                DependsOn = "[File]SetupTempDir$arch"

            }

            Archive "UnzipFile$arch" {

                Ensure = "Present"
                Path = "C:\Temp\WINDOWS.X$($arch)_193000_client.zip"
                Destination = "$tempdir\OracleClient\Extracted(x$arch)"
                DependsOn = "[xRemoteFile]FileDownload$arch"

            }

            Script "OracleClientSetup$arch" {
                SetScript = {
                    $setupArgs = @(
                        "-silent",
                        "-nowait",
                        "-ignoreSysPrereqs",
                        "-ignorePrereqFailure",
                        "-waitForCompletion",
                        "-force",
                        "ORACLE_HOME=C:\Oracle$($Using:arch)\Product\19.0.0\Client$($Using:arch)",
                        "ORACLE_BASE=C:\Oracle$($Using:arch)",
                        "oracle.install.IsBuiltInAccount=true",
                        "oracle.install.client.installType=InstantClient"
                    )

                    Write-Verbose "The architecture is $using:arch"
                    Write-Verbose "The temp directory is $using:tempdir"
                    Write-Verbose "The DataDrive is $using:dataDrive"

                    $arch = $using:arch
                    $tempdir = $using:tempdir
                    $dataDrive = $using:datadrive
 

                    if ($arch -eq "86") {
                        Write-Verbose "Starting install of the x86 Oracle Client"  
                        Start-Process -FilePath "$($tempdir)\OracleClient\Extracted(x$($arch))\Client32\setup.exe" -ArgumentList $setupArgs -Wait 
                        New-Item -ItemType Junction -Path "C:\Windows\syswow64\oracle" -Target "$($dataDrive)\Oracle86\Product\19.0.0\Client86" -Force
                        # Directory Junction is if we need to have the folder name Oracle32 as well. 
                        New-Item -ItemType Junction -Path "$($dataDrive)\Oracle32" -Target "$($dataDrive)\Oracle86"

                    }
                    if ($arch -eq "64") {
                        Write-Verbose "Starting install of the x64 Oracle Client"   
                        Start-Process -FilePath "$($tempdir)\OracleClient\Extracted(x$($arch))\Client\setup.exe" -ArgumentList $setupArgs -Wait 
                        New-Item -ItemType Junction -Path "C:\Windows\system32\oracle" -Target "$($dataDrive)\Oracle64\Product\19.0.0\Client64" -Force
                    }

                }
                TestScript = {
                    
                    $directories = @( "Oracle32", "Oracle64")
                    $systemdirectories = @("C:\windows\system32\oracle", "C:\Windows\SysWOW64\oracle" )
                    $32bitLogPath = "C:\Program Files (x86)\Oracle\Inventory\logs"
                    $64bitLogPath = "C:\Program Files\Oracle\Inventory\logs"

                    # test install directories

                    foreach ($directory in $directories) {

                        $pathTest = Test-Path -Path "$Using:dataDrive\$directory"

                        if (!$pathTest) {
                        
                            Write-Verbose "Not all install directories were found."                         
                            return $false             
                   
                        }                            

                    }

                    # test for system junction points

                    foreach ($systemdirectory in $systemdirectories) {

                        $pathTest = Test-Path -Path $systemdirectory
                       
                        if (!$pathTest) {
                        
                            Write-Verbose "Junction Points were not found."                         
                            return $false 
                        
                        }                        

                    }

                    # test for log file directories

                    $pathtest = test-path -path $64bitLogPath\installActions*

                    if (!$pathTest) {
                        
                        Write-Verbose "64-bit installation log file not found!"                         
                        return $false 
                        
                    } 

                    $pathtest = test-path -path $32bitLogPath\installActions*
                    
                    if (!$pathTest) {
                        
                        Write-Verbose "32-bit installation log file not found!"                         
                        return $false 
                        
                    } 
                        
                    # test log files for successful 32-bit installation

                    $logfiletest = $false
                    $logfilepaths = Resolve-Path -Path $32bitLogPath\installActions*

                    foreach ($logfilepath in $logfilepaths) {

                        $content = Get-Content $logfilepath.Path
                        $testcontent = $content -match "Exit Status is 0"

                        if ($testcontent) { $logfiletest = $true }
                   
                    }

                    if (!$logfiletest) {
                        
                        Write-Verbose "Succcesful 32-bit installation result not found!"                         
                        return $false 
                        
                    }

                    # test log files for successful 64-bit installation

                    $logfiletest = $false
                    $logfilepaths = Resolve-Path -Path $64bitLogPath\installActions*

                    foreach ($logfilepath in $logfilepaths) {

                        $content = Get-Content $logfilepath.Path
                        $testcontent = $content -match "Exit Status is 0"

                        if ($testcontent) { $logfiletest = $true }
                   
                    }

                    if (!$logfiletest) {
                        
                        Write-Verbose "Succcesful 64-bit installation result not found!"                         
                        return $false 
                        
                    }        

                    return $true 
                }
                GetScript = {
                    $null
                }
                DependsOn = "[Archive]UnzipFile$arch"
           
            }

        }
        
    }

    # Set Environmental Variables

    node $nodename {

        Environment Env_Variable_ORACLE_HOME
        {
            Ensure = "Present" 
            Path = $false
            Name = "ORACLE_HOME"
            Value = 'C:\Windows\system32\oracle'
    
        }

        Environment Env_Variable_PATH
        {
            Ensure = "Present"
            Path = $true
            Name = "PATH"
            Value = 'C:\Windows\system32\oracle'

        }

    }

}


OracleClientInstallation -ConfigurationData $configData


    

    
 
 
 
 
 
 
 
 
 
