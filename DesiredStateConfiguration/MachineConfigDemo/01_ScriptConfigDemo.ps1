  

Configuration InstallBatchFile {

    #Requires -module @{ModuleName = 'PSDesiredStateConfiguration'; ModuleVersion = '1.1'}
    #Requires -module @{ModuleName = 'xPSDesiredStateConfiguration'; ModuleVersion = '1.1'}

    # Import DSC Modules

    #Import-DscResource -ModuleName @{ModuleName = 'PSDesiredStateConfiguration'; ModuleVersion = '1.1' }
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName 'PSDscResources'

    # Set variablese
    $storageaccountpath = "https://wcurtisdemo.blob.core.windows.net/dscflats/batch.zip?sp=r&st=2023-12-28T15:32:31Z&se=2025-12-28T23:32:31Z&spr=https&sv=2022-11-02&sr=b&sig=tISMZXtvDuvkx72C0WCP1rqx1peFbxiN%2FBopkC5gDIA%3D"
    $tempdir = "C:\Temp"


        # Setup the folders   

            File "SetupTempDir" {

                Type            = 'Directory'
                DestinationPath = $tempdir
                Ensure          = "Present"  
            
            }

              
            xRemoteFile "FileDownload" {
                URI = $storageaccountpath
                DestinationPath = $tempdir
                MatchSource = $false
                DependsOn = "[File]SetupTempDir"

            }

            Script "BatchFileInstall" {
                SetScript = {
                    $setupArgs = @(
                        "-silent",
                        "-nowait"
                )


                   
                    $tempdir = $using:tempdir                  
 


                        Write-Verbose "Starting install of the Batch File"  
                        Start-Process -FilePath "$($tempdir)\batchfile.bat" -ArgumentList $setupArgs -Wait 
              
                }
                TestScript = {
                    
                    $directories = @( "BatchCreated")
                    $32bitLogPath = "C:\Program Files (x86)\Oracle\Inventory\logs"

                    # test install directories

                    foreach ($directory in $directories) {

                        $pathTest = Test-Path -Path "$Using:dataDrive\$directory"

                        if (!$pathTest) {
                        
                            Write-Verbose "Not all install directories were found."                         
                            return $false             
                   
                        }                            

                    }


                    # test for log file directories

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

                    return $true 
                }
                GetScript = {
                    $null
                }
                DependsOn = "[Script]BatchFileInstall"
           
            }

        
        

        Environment Env_Variable_ORACLE_HOME
        {
            Ensure = "Present" 
            Path = $false
            Name = "ORACLE_HOME"
            Value = 'C:\Windows\system32\oracle'
    
        }
   

}


InstallbatchFile 


Rename-Item -path .\TimeZoneCustom\localhost.mof -NewName ScritpConfigDemo.mof