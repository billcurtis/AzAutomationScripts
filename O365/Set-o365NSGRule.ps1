<#

.SYNOPSIS
    This Azure Automation Runbook creates or updates a Network Security Group (NSG) rule in Azure to allow traffic from Office 365 IP addresses.

.DESCRIPTION
    The script connects to Azure using the provided subscription ID and Managed Identity. It retrieves the latest Office 365 IP addresses and creates 
        or updates a NSG rule with the specified parameters.

.EXAMPLE
    .\Set-o365NSGRule.ps1 -nsgName "MyNSG" -ResourceGroupName "MyResourceGroup" -InboundRuleName "AllowOffice365" -ruleAccess "Allow" -ruleProtocol "Tcp" 
        -rulePriority 1000 -ruleSourcePortRange "*" -ruleDestinationPortRange "*" -ruleDestinationAddressPrefix "*" -subscriptionId "12345678-1234-1234-1234-1234567890AB"

.PARAMETER nsgName
    The name of the Network Security Group (NSG) to be updated.

.PARAMETER ResourceGroupName
    The name of the resource group where the NSG is located.

.PARAMETER InboundRuleName
    The name of the NSG rule to be created or updated.

.PARAMETER ruleAccess
    The access type for the NSG rule (Allow or Deny).   

.PARAMETER ruleProtocol
    The protocol for the NSG rule (Tcp, Udp, or *).

.PARAMETER ruleDirection
    The direction of the NSG rule (Inbound or Outbound). Default is Inbound.

.PARAMETER rulePriority
    The priority of the NSG rule (1-4096). Lower numbers have higher priority.

.PARAMETER ruleSourcePortRange
    The source port range for the NSG rule. Default is "*".

.PARAMETER ruleDestinationPortRange
    The destination port range for the NSG rule. Default is "*".

.PARAMETER ruleDestinationAddressPrefix
    The destination address prefix for the NSG rule. Default is "*".

.PARAMETER subscriptionId
    The ID of the Azure subscription that the Azure Automation Account resides.


.NOTES
    This script requires the Az module to be installed. You can install it by running 'Install-Module -Name Az' if it's not already installed.
    Make sure you have the necessary permissions to create or update NSG rules in Azure.

#>

param (

    [Parameter(Mandatory = $true)]
    $nsgName,

    [Parameter(Mandatory = $true)]
    $ResourceGroupName,

    [Parameter(Mandatory = $true)]
    $InboundRuleName,

    [Parameter(Mandatory = $true)]
    $ruleAccess,

    [Parameter(Mandatory = $true)]
    $ruleProtocol,

    [Parameter(Mandatory = $true)]
    $ruleDirection = "Inbound",

    [Parameter(Mandatory = $true)]
    $rulePriority,

    [Parameter(Mandatory = $true)]
    $ruleSourcePortRange = "*",

    [Parameter(Mandatory = $true)]  
    $ruleDestinationPortRange = "*",

    [Parameter(Mandatory = $true)]
    $ruleDestinationAddressPrefix = "*",

    [Parameter(Mandatory = $true)]
    $subscriptionId
)

# Connect to Az Account
Connect-AzAccount -SubscriptionId $subscriptionId -Identity

# Static Strings
$serviceRoot = "https://endpoints.office.com"
$clientRequestId = [guid]::NewGuid()
 

#Import Azure modules
Import-Module Az.Accounts
Import-Module Az.Network
Import-Module Az.Resources


# set preferences
$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"

# Function to get the latest version of the  endpoints data
function Get-EndpointsData {
    $uri = "$serviceRoot/endpoints/worldwide?clientRequestId=$clientRequestId"
    $response = Invoke-RestMethod -Uri $uri -Method Get
    return $response
}

try {

    $endPointsData = (Get-EndpointsData).ips | Select-Object -Unique

    # Get the list of all IP addresses from the endpoints data IPv6 and IPv4
 
    $IPv4Addresses = $endPointsData | Where-Object { $_ -match '\b((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\/([0-9]|[1-2][0-9]|3[0-2])\b' } 
    # $IPV6Addresses = $endPointsData | Where-Object { $_ -match '(?:[A-Fa-f0-9]{1,4}:){7}[A-Fa-f0-9]{1,4}\/(12[0-8]|1[01][0-9]|[1-9]?[0-9])|(?:[A-Fa-f0-9]{1,4}:){1,7}:\/(12[0-8]|1[01][0-9]|[1-9]?[0-9])|(?:[A-Fa-f0-9]{1,4}:){1,6}:[A-Fa-f0-9]{1,4}\/(12[0-8]|1[01][0-9]|[1-9]?[0-9])'} 
 

    # Create a list of IP addresses to be added to the NSG rule
    $ipList = [System.Collections.Generic.List[string]]::new()
    $IPv4Addresses | ForEach-Object { $ipList.Add($_) }

    # Get the existing NSG rule or create a new one if it doesn't exist

    Write-Verbose -Message "Checking for existing NSG rule: $InboundRuleName"
    $nsg = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $ResourceGroupName
    $rule = Get-AzNetworkSecurityRuleConfig -NetworkSecurityGroup $nsg | Where-Object { $_.Name -eq $InboundRuleName }
    if ($rule) {

        Write-Verbose -Message "Updating existing NSG rule: $InboundRuleName"
        $nsg.SecurityRules.Remove($rule)
        $rule.SourceAddressPrefix = $ipList
        Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg
    }
    else {

        Write-Verbose -Message "Creating new NSG rule as it does not exist: $InboundRuleName"

        $params = @{
            Name                     = $InboundRuleName   
            Access                   = $ruleAccess 
            Protocol                 = $ruleProtocol
            Direction                = $ruleDirection
            Priority                 = $rulePriority
            SourceAddressPrefix      = $ipList  
            SourcePortRange          = $ruleSourcePortRange
            DestinationAddressPrefix = $ruleDestinationAddressPrefix
            DestinationPortRange     = $ruleDestinationPortRange 
        }

        $rule = New-AzNetworkSecurityRuleConfig @params          
        $nsg.SecurityRules.Add($rule)
        Set-AzNetworkSecurityGroup -NetworkSecurityGroup $nsg -Verbose

    }
}
catch {
    Write-Error -Message $_.Exception
    Write-Verbose -Message "An error occurred: $($_.Exception.Message)"
    throw $_.Exception  
}

$VerbosePreference = "SilentlyContinue"
 