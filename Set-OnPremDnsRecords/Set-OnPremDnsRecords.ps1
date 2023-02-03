<#
    .DESCRIPTION
       
        Runbook is designed to create A and CNAME records in a Active Directory Domain Services (ADDS) DNS environment.  
        
        This runbook will allow Azure RBAC controls to be used to create a self-service DNS environment for users.
        Users will be able to create, delete, and read  DNS records in the production environment that are tied
        to a single ADDS service account.  

    .INPUTS

        RECORDTYPE - Can either be CNAME or A

        RECORDDATA - String data that hosts the data for a DNS record.  IPv4 Address for A. Domain Name for CNAME.

        DNSRECORDNAME - The name of the DNS (CNAME, A) record being created

        ZONENAME - The DNS zone name. (ex. contoso.com)

        DNSSERVERNAME - The name of the Windows DNS server where this script will execute on (ex. dnsserver1.contoso.com)

        ACTION - The action to take.

            Create - Create the record

            Delete - Delete the record

            Read   - Reads ALL records that have the ACL for the Service Acount in the record and returns them in JSON format.


    .OUTPUTS 

        If the Read ACTION is specified, a JSON file will be dumped for the Zone with all A and CNAME records corresponding
            with the hard-coded service account name.


    .NOTES
    
        1. The Az module needs to be installed on the runbook worker.
        2. The DNS server (DNSSERVERNAME) MUST have the DNSServer PowerShell module installed.
        3. Azure Automation will require a Credential for the Service Account to be put in the Azure Automation key vault (Credentials)
        4. The Service Account must have Full Control permissions on the Zone it will be updating. This service account will not be visible
            to the user.
        

#>
param (

    [ValidateSet('A', 'CNAME', 'PTR',"")]
    [string]$RecordType,

    [string]$RecordData,

    [string]$DnsRecordName,

    [Parameter(Mandatory)]
    [string]$ZoneName,

    [Parameter(Mandatory)]
    [string]$DNSServerName,

    [Parameter(Mandatory)]
    [ValidateSet('Create', 'Delete', 'Read')]
    [string]$Action      
 
)

# static strings

$serviceAccountName = 'DevGroup01' # account name. NOT in contoso\sa format, but just sa
$SubscriptionID = 'xxxxxxxx-xxxx-xxxxx-xxxxx-xxxxxxxxxxxx' # Subscription ID


# import required modules

$VerbosePreference = "SilentlyContinue"
Import-Module Az.Accounts

# preferences

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Azure Connection Configuration

Write-Verbose -Message "Connecting to Azure with Az Identity"
Connect-AzAccount -Identity -SubscriptionID $SubscriptionID | Out-Null
$azContextSubID = (Get-AzContext).Subscription 
Write-Verbose -Message "Subscription $azContextSubID is in context."

# Get the credentials for the service account that will connect to the DNS server and create/delete DNS records.

$creds = Get-AutomationPSCredential -Name $serviceAccountName
Write-Verbose -Message "Destination Service Principal Credentials: $creds"

# list all inputs for runbook logging

Write-Verbose -Message `
    "DNS Record Name = $dnsrecordname, Zone Name = $zoneName, DNS Server FQDN = $DNSServerName, Service Account Name = $serviceAccountName, RecordData = $RecordData, Action = $Action" `
    -Verbose 

# perform a invoke command to run this script on the specified DNS server under the service account credentials

Invoke-Command -ComputerName $DNSServerName -ScriptBlock {

    # preferences

    $ErrorActionPreference = "Stop"
    $VerbosePreference = "Continue"

    # pass through arguments

    $dnsrecordname = $Using:dnsrecordname
    $RecordType = $Using:RecordType
    $zoneName = $Using:ZoneName
    $DNSServerName = $Using:DNSServerName
    $serviceAccountName = $Using:serviceAccountName
    $RecordData = $Using:RecordData
    $Action = $Using:Action

    # import required modules

    $VerbosePreference = "SilentlyContinue"
    Import-Module -Name DnsServer
    Import-Module -Name ActiveDirectory
    $VerbosePreference = "Continue"

    #  functions

    function add-arecord {

        param (
    
            $dnsrecordname,
            $zoneName,
            $dnsServerName,
            $serviceAccountName,
            $RecordData
        )
    
    
        # set preferences 
    
        $ErrorActionPreference = 'Stop'
        $VerbosePreference = 'Continue'
    
    
        # ensure that dns record can be created
    
        $params = @{
    
            dnsrecordname  = $dnsrecordname
            zoneName       = $zoneName
            dnsServerName  = $dnsServerName
            serviceAccount = $serviceAccountName
            RecordData     = $RecordData
    
        }
    
        Write-Output "INFO: Evaluating record name and record data for $dnsrecordname"
    
        $canCreate = evaluate-arecord @params
        
        if ($canCreate -eq "Duplicate") { Write-Output "ERROR: Duplicate Record and IP already found!" ; exit }
        if ($canCreate -eq "DuplicateNameNoPerm") { Write-Output "ERROR: Duplicate Record Name was found without appropriate Service Account ACL!" ; exit }
        if ($canCreate -eq "CanAdd") {

    
            # create dns record
    
            Write-Output "INFO: Creating record name and record data for $dnsrecordname with IP of $RecordData"
    
            $params = @{
    
                Name         = $dnsrecordname
                ZoneName     = $zoneName
                Computername = $dnsServerName
                IPv4Address  = $RecordData
    
            }
    
            # get the newly created dns record and assign a full control acl for the service account.
    
            Add-DnsServerResourceRecordA @params | Out-Null
            $sid = (Get-ADUser -Identity $serviceAccountName).SID 
    
            $params = @{
    
                Name         = $dnsrecordname
                ZoneName     = $zoneName
                Computername = $dnsServerName
    
            }
    
            $dnsrecords = Get-DnsServerResourceRecord @params | Where-Object { $_.RecordData.IPv4Address.IPAddressToString -eq $RecordData }
            
           
            foreach ($dnsrecord in $dnsrecords) {
    
    
                $acl = Get-Acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)”
                $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $SID, "GenericAll", "Allow"
                $acl.AddAccessRule($ace)
                $acl | set-acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)”
    
            }
    
        }
        if (!$canCreate) {
            Write-Error -Message "Record name already exists without the permissons for $serviceAccountName. Record not being created."
    
        }

    
    }

    function add-cnamerecord {

        param (
    
            $dnsrecordname,
            $zoneName,
            $dnsServerName,
            $serviceAccountName,
            $RecordData
        )
    
    
        # set preferences 
    
        $ErrorActionPreference = 'Stop'
        $VerbosePreference = 'Continue'
    
    
        # ensure that dns record can be created
    
        $params = @{
    
            dnsrecordname  = $dnsrecordname
            zoneName       = $zoneName
            dnsServerName  = $dnsServerName
            serviceAccount = $serviceAccountName
            RecordData     = $RecordData
    
        }
    
        Write-Output "INFO: Evaluating record name and record data for $dnsrecordname"
    
        $canCreate = evaluate-cnameRecord @params

        # make this a switch statement when I get some time
        
        if ($canCreate -eq "Duplicate") { Write-Output "ERROR: Duplicate Record and IP already found!" ; exit }
        if ($canCreate -eq "DuplicateNameNoPerm") { Write-Output "ERROR: Record Name was found without appropriate Service Account ACL!" ; exit }
        if ($canCreate -eq "CanAdd") {
    
    
            # create dns record
    
            Write-Output "Creating record name and record data for $dnsrecordname with IP of $RecordData"
    
            $params = @{
    
                Name          = $dnsrecordname
                ZoneName      = $zoneName
                Computername  = $dnsServerName
                HostNameAlias = $RecordData
    
            }
    
            # get the newly created dns record and assign a full control acl for the service account.
    
            Add-DnsServerResourceRecordCName @params | Out-Null
            $sid = (Get-ADUser -Identity $serviceAccountName).SID 
    
            $params = @{
    
                Name         = $dnsrecordname
                ZoneName     = $zoneName
                Computername = $dnsServerName
    
            }
    
            $dnsrecords = Get-DnsServerResourceRecord @params | Where-Object { $_.RecordData.HostNameAlias -match $RecordData }
            
           
            foreach ($dnsrecord in $dnsrecords) {
    
    
                $acl = Get-Acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)”
                $ace = New-Object System.DirectoryServices.ActiveDirectoryAccessRule $SID, "GenericAll", "Allow"
                $acl.AddAccessRule($ace)
                $acl | set-acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)”
    
            }
    
        }
        if (!$canCreate) {
            Write-Error -Message "Record name already exists without the permissons for $serviceAccountName. Record not being created."
    
        }

    }
    
    function evaluate-arecord {
    
        param (
    
            $dnsrecordname,
            $zoneName,
            $dnsServerName,
            $serviceAccountName,
            $RecordData
    
        )
        
        # set preferences 
    
        $ErrorActionPreference = 'Stop'
        $VerbosePreference = 'Continue'
          
        $params = @{
    
            ZoneName     = $zoneName
            Computername = $dnsServerName
    
        }
    
        $dnsrecords = Get-DnsServerResourceRecord @params | Where-Object { $_.Hostname -eq $dnsrecordname }
    
        # return true if nothing returned
        if (!$dnsrecords) { 
            
            Write-Output "INFO: Did not find any existing records on DNS Server that matched:  $dnsrecordname"
            return 'CanAdd'
        
        }
        
        # process records to ensure that the correct acl exists on these records to ensure we do not hijack a name we shouldn't
        foreach ($dnsrecord in $dnsrecords) {
    
            Write-Output "INFO: Processing type $($dnsrecord.RecordType) record with the name of $($dnsrecord.HostName)"
    
            $acl = Get-Acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)” | Where-Object { $_.AccessToString -match $serviceAccountName }
    
            if ($acl) { 
    
                # do not create the record if the record already exists with identical record data.
    
                if ($dnsrecord.RecordData.IPv4Address.IPAddressToString -match $RecordData) {
    
                    return "Duplicate"
    
                }

                return $true
    
            }

            if (!$acl) { return "DuplicateNameNoPerm" }
    
        }   
    
    }

    function evaluate-cnameRecord {
    
        param (
    
            $dnsrecordname,
            $zoneName,
            $dnsServerName,
            $serviceAccountName,
            $RecordData
    
        )
    
    
        # set preferences 
    
        $ErrorActionPreference = 'Stop'
        $VerbosePreference = 'Continue'
    
    
    
        $params = @{
    
            ZoneName     = $zoneName
            Computername = $dnsServerName
    
        }
    
        $dnsrecords = Get-DnsServerResourceRecord @params | Where-Object { $_.Hostname -match $dnsrecordname }
    
        # return true if nothing returned
        if (!$dnsrecords) { 

            return 'CanAdd'
        
        }
    
    
        # process records to ensure that the correct acl exists on these records to ensure we do not hijack a name we shouldn't
        foreach ($dnsrecord in $dnsrecords) {
    
            Write-Output "INFO: Processing type $($dnsrecord.RecordType) record with the name of $($dnsrecord.HostName)"
    
            $acl = Get-Acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)” | Where-Object { $_.AccessToString -match $serviceAccountName }
    
            if ($acl) { 
    
                # do not create the record if the record already exists with identical record data.
    
                if ($dnsrecord.RecordData.HostNameAlias -match $RecordData) {
    
                    return "Duplicate"
    
                }

                return $true
    
            }

            if (!$acl) { return "DuplicateNameNoPerm" }
    
        }   
    
    }

    function get-dnsrecords {

        param (

            $zoneName,
            $dnsServerName,
            $serviceAccountName

        )

        # declare static variables

        $report = @()

        $params = @{

            ZoneName     = $zoneName
            Computername = $dnsServerName

        }

        # get all DNS records

        $dnsrecords = Get-DnsServerResourceRecord  @params

        # cycle through all records and return the ones that have the listed service account in their ACL

        foreach ($dnsrecord in $dnsrecords) {

            $acl = Get-Acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)” | Where-Object { $_.AccessToString -match $serviceAccountName }

            if ($acl) { $report += $dnsrecord }

        }

        return $report | ConvertTo-Json -Depth 100 -Compress

    }

    function remove-record {

        param (
    
            $dnsrecordname,
            $zoneName,
            $dnsServerName,
            $serviceAccountName,
            $RecordType

        )

        # set preferences 

        $ErrorActionPreference = 'Stop'
        $VerbosePreference = 'Continue'

        #$sid = Get-ADUser -Identity $serviceAccountName

        $params = @{

            #Name = $dnsrecordname
            ZoneName     = $zoneName
            Computername = $dnsServerName

        }

        $dnsrecords = Get-DnsServerResourceRecord  @params | Where-Object { $_.hostname -eq $dnsrecordname } 

        if (!$dnsrecords) { Write-Output "The DNS record $dnsrecordname was not found. Gracefully ending runbook execution."; exit }

        foreach ($dnsrecord in $dnsrecords) {

            Write-Output "Processing type $($dnsrecord.RecordType) record with the name of $($dnsrecord.HostName)"

            $acl = Get-Acl -Path “ActiveDirectory:://RootDSE/$($dnsrecord.DistinguishedName)” | Where-Object { $_.AccessToString -match $serviceAccountName }
            if ($acl) {

                Write-Output  "INFO: Removing record type $($dnsrecord.RecordType) with name record with the name of $($dnsrecord.HostName)"

                $params = @{

                    Name         = $dnsrecordname
                    ZoneName     = $zoneName
                    Computername = $dnsServerName
                    Force        = $true
                    RRType       = $dnsrecord.RecordType

                }

                if ($dnsrecord.RecordType -eq "A") { $params += @{RecordData = $dnsrecord.RecordData.IPv4Address } }

            }
            else { Write-Output  "ERROR: ACL did not contain the correct Service Account ($serviceAccountName) ACL for DNSRecord ($dnsrecordname). Deletion did not occur."; return }

            Remove-DnsServerResourceRecord @params

        }

    }

    # main 

    if ($Action -eq 'Create') {
        if ($RecordType) {
    
            switch ($recordtype) {
    
                'A' {
    
                    $param = @{
    
                        dnsrecordname  = $dnsrecordname
                        zoneName       = $zoneName
                        dnsServerName  = $dnsServerName
                        serviceAccount = $serviceAccountName
                        RecordData     = $RecordData
    
                    }
    
                    add-arecord @param    
                }
                'CNAME' {

                    $param = @{
    
                        dnsrecordname  = $dnsrecordname
                        zoneName       = $zoneName
                        dnsServerName  = $dnsServerName
                        serviceAccount = $serviceAccountName
                        RecordData     = $RecordData
    
                    }
    
                    add-cnamerecord @param 

                }
    
            }

        }
    }

    if ($Action -eq 'Read') {

        $params = @{

            zoneName           = $zoneName
            DNSServerName      = $DNSServerName
            serviceAccountName = $serviceAccountName

        }
        
        get-dnsrecords  @params

    }

    if ($Action -eq 'Delete') {

        $params = @{

            dnsrecordname      = $dnsrecordname
            zoneName           = $zoneName
            dnsServerName      = $DNSServerName
            serviceAccountName = $serviceAccountName
            RecordType         = $RecordType

        }

        remove-record @params

    }

} -Credential $creds -Verbose
    