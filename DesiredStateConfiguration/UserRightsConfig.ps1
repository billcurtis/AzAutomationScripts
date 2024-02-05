Configuration UserRightsConfig {

    param
    (

        # Target nodes to apply the configuration.
        [Parameter()]
        [String]
        $NodeName

    )

    #Requires -module @{ModuleName = 'SecurityPolicyDsc'; ModuleVersion = '2.10.0.0'}

    Import-DscResource -ModuleName SecurityPolicyDsc

    #static variables for testing
    $nodename = 'localhost'

    # Generate roles to be added

    $Environment = $env:COMPUTERNAME.Substring(1, 1)
    if (![string]::IsNullOrEmpty($Environment)) {
        switch ($Environment) {
            'P' { $CurrentEnv = 'PRD' }
            'S' { $CurrentEnv = 'STG' }
            'Q' { $CurrentEnv = 'QAT' }
            'R' { $CurrentEnv = 'RCV' }
            'D' { $CurrentEnv = 'DEV' }
        }
    }

    Write-Verbose "Current Env set to: $CurrentEnv"

    $platform = 'ENG'
    $roles = @('PTLWINSVC')  # Update with your desired roles

    foreach ($role in $roles) {

        $user = "svc$("$($CurrentEnv)$($platform)$($role)","$env:USERDNSDOMAIN" -join '@')".ToLower()
            

        Node $nodename {

     
            UserRightsAssignment "SeServiceLogonRight - $user" {   
                Policy = 'Log_on_as_a_service'
                Identity = $user
                Ensure = 'Present'

            }

            UserRightsAssignment "SeBatchLogonRight - $user" {   
                Policy = 'Log_on_as_a_batch_job'
                Identity = $user
                Ensure = 'Present'

            }

            UserRightsAssignment "SeTcbPrivilege - $user" {   
                Policy = 'Act_as_part_of_the_operating_system'
                Identity = $user
                Ensure = 'Present'

            }


        }


    }
} 
