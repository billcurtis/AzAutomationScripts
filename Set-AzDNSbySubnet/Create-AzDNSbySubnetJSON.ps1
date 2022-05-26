
# Enter Variables Here

$subscriptionId = ""      #Example: f9567f40-d8d2-4d55-8391-fc45e85380c4
$virtualNetworkId = ""    #Example: /subscriptions/f9567f40-d8d2-4d55-8391-fc45e85380c4/resourceGroups/myResourceGroup/providers/Microsoft.Network/virtualNetworks/MyVnet
$subnetName = ""          #Example: subnet1
$targetDNSAddresses = ""  #Example : 192.168.0.1,192.168.1.1

# Convert $targetDNSAddresses
$targetDNSIPs = $targetDNSAddresses.Split(",")

# Create Object
$obj = [PSCustomObject]@{

    subscriptionId     = $subscriptionId
    virtualNetworkId   = $virtualNetworkId
    subnetName         = $subnetName
    targetDNSAddresses = $targetDNSIPs
}

# Convert Object to JSON (Compressed)

$obj | ConvertTo-Json -Depth 8 -Compress

# Enter JSON output into Azure Automation Variable (Manually)