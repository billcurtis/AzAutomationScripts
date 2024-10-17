$tenantId = ""
$subscriptionId = ""

# Log on with Automation Account Managed Identity
Connect-AzAccount -identity -tenantid $tenantId -SubscriptionId $subscriptionId

##################################################################
# Define Capacity Variables
##################################################################

# Variable Definitions
$resourceGroupName = "CAPACITYGROUP-RG" # Specify your resource group name
$location = "centralIndia" # Specify the location, e.g., "eastus"

$CapacityReservationGroupName = "myCapacityGroup" 
$sku = "Standard_DC4as_v5" # Specify the VM SKU for the capacity reservation
$CapacityReservationName = "Standard_DC4as_v5_Reservation"
$zones = @("1")
$CapacityperZone = 22 # Desired capacity per zone

# How many retry attempts do you want to allow this to run before failing?
$maxAttempts = 3

# set error action preference  
$ErrorActionPreference = "SilentlyContinue"

# Based on the above, at least 1 zone must be trigger the below process. Zone's are ignored for regional reservations.
foreach ($zone in $zones) {
    try {        
        $ZonalReservationName = $CapacityReservationName
               
        # Checks to see what the current capacity of the reservation is specified as: 
        $zoneConsumed = (Get-AzCapacityReservation `
                -ResourceGroupName $resourceGroupName `
                -ReservationGroupName $CapacityReservationGroupName `
                -name $ZonalReservationName `
                -ErrorAction Continue).Sku.Capacity

        Write-Output "Reservations consume are $zoneconsumed"

        # If the Capacity Reservation doesn't have any capacity or doesn't exist, create it with a quantity of 1 to ensure the sku can be created. If this is blocked, will need to look at not using this zone or working with capacity management to obtain availability. 
        if (-not $zoneConsumed) {
            try {
                write-output "Creating capacity reservation for zone $zone with a quantity of 1 to ensure a capacity reservation of this SKU is available."

                # Create regional capacity reservation with quantity of 1.
                try {
                    New-AzCapacityReservation `
                        -ResourceGroupName $resourceGroupName `
                        -ReservationGroupName $CapacityReservationGroupName `
                        -name $CapacityReservationName `
                        -Location $location `
                        -Sku $sku `
                        -CapacityToReserve 1 `
                        -ErrorAction stop
                }
                catch {
                    Write-Output "Failed to create capacity reservation for the region $location. Please review your quota and contact Microsoft Support."
                    Write-Output $_.Exception.Message
                }

            }
            catch {
            }
        }
    }
    catch {
    }

    #Sets naming convention for the reservation name based on the zone number. This is ignored for regional requests. 
    $ZonalReservationName = ($CapacityReservationName + '-z' + $zone)
    $attempt = 0
    $success = $false
    while (-not $success -and $attempt -lt $maxAttempts) {
        try {
            if ($zoneConsumed -eq $CapacityperZone) {
                Write-Output "Zone $zone Capacity matches requested capacity of $CapacityperZone."
                $success = $true
            }
            else {

                #Documents target, current, and gap in capacity from the target number. 
                Write-Output "Zone $zone Capacity doesn't match requested capacity, attempting to modify the target capacity."
                write-Output "Desired capacity: $CapacityperZone"
                write-Output "Current capacity: $zoneConsumed"
                write-Output "Capacity gap: $CapacityGapPerZone"
                $CapacityGapPerZone = $CapacityperZone - $zoneConsumed
    
                # Creates multiple attempts to retry the capacity increase request. Capacity request targets would be: 
                # 1st attempt uses 100% (1.0), 2nd attempt uses .5 (50%), and 3rd attempt uses .25 (25%).
                $percentageToIncrease = switch ($attempt) {
                    1 { 0.5 }
                    2 { 0.25 }
                    default { 1.0 }
                }
                $IncreaseRequest = $zoneConsumed + [math]::Round($CapacityGapPerZone * $percentageToIncrease)           
                write-output "Attempt $attempt, Increasing capacity in region to $IncreaseRequest."
                Update-AzCapacityReservation `
                    -ResourceGroupName $resourceGroupName `
                    -ReservationGroupName $CapacityReservationGroupName `
                    -name $CapacityReservationName `
                    -CapacityToReserve $IncreaseRequest `
                    -ErrorAction stop            

                # When desired capacity is met, the loop will break.
                $zoneConsumed = (Get-AzCapacityReservation -ResourceGroupName $resourceGroupName -ReservationGroupName $CapacityReservationGroupName -Name $ZonalReservationName -ErrorAction SilentlyContinue).Sku.Capacity
                if ($CapacityperZone -eq $zoneConsumed) {
                    Write-Output "Success"
                    break
                }
            }
        }
        catch {
            Write-Output "Attempt $attempt failed, retrying..."
        }
        if ($success) {
            break
        }
        $attempt++

        # If the capacity reservation fails to meet the desired capacity after the max attempts, the script will fail.
        if (-not $success) {
            Write-Output "Failed to adjust capacity for Zone $zone after $maxAttempts attempts."
        }
    }
}