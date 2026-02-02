<#
.SYNOPSIS
    Azure Automation runbook to manage VM creation policies based on approved VM names.
 
.DESCRIPTION
    This runbook:
    1. Connects to Azure using Managed Identity
    2. Scans VMs in specified management groups
    3. Updates an Azure Automation variable with discovered VM names
    4. Creates/updates Azure Policy to restrict VM creation to approved names
 
.NOTES
    Author: Azure Automation
    Date: December 16, 2025
    PowerShell Version: 7.x
   
    Required Azure Automation Variables:
    - ManagementGroupsJson: JSON string containing management group IDs
    - ApprovedVMNamesJson: JSON string containing approved VM names
   
    Required Permissions:
    - Resource Policy Contributor on Management Groups
    - Reader on subscriptions (for VM discovery)
    - Automation Contributor on Automation Account
 
.EXAMPLE
    ManagementGroupsJson format:
    {
        "managementGroups": ["mg-prod", "mg-dev", "mg-test"]
    }
   
    ApprovedVMNamesJson format:
    {
        "approvedVMNames": ["vm-web-001", "vm-app-001", "vm-db-001"]
    }
#>
 
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AutomationAccountName = "<automation-account-name>",
   
    [Parameter(Mandatory = $false)]
    [string]$AutomationAccountResGroupName = "<automation-account-resource-group>",
   
    [Parameter(Mandatory = $false)]
    [string]$PolicyDefinitionName = "Restrict-VM-Creation-by-Name",
   
    [Parameter(Mandatory = $false)]
    [string]$PolicyDisplayName = "Restrict VM Creation to Approved Names",

    [Parameter(Mandatory = $false)]
    [string]$PolicyDescription = "This policy restricts VM creation to only approved VM names discovered in this management group.",
 
    [Parameter(Mandatory = $false)]
    [string]$RunbookSubscriptionID = "<subscription-id>",
 
    [Parameter(Mandatory = $false)]
    [string]$UserManagedID = "<user-managed-identity-client-id>"
)
 
#region Functions
 
function Connect-AzureWithManagedIdentity {
    <#
    .SYNOPSIS
        Connects to Azure using the Automation Account's Managed Identity
    #>
    param (
        $RunbookSubscriptionID,
        $UserManagedID
    )
    try {
        Write-Verbose "Attempting to connect to Azure using Managed Identity..."
               
        # User Assigned Identity Client ID
        $clientID = "4597a6b5-f014-46bb-859b-18782e533fd4"
       
        # Connect using system-assigned managed identity
        $null = Connect-AzAccount -Identity -AccountId $UserManagedID -SubscriptionId $RunbookSubscriptionID -ErrorAction Stop
       
        # Get the current context
        $context = Get-AzContext
       
        Write-Verbose "Successfully connected to Azure"
        Write-Verbose "  Account: $($context.Account.Id)"
        Write-Verbose "  Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
        Write-Verbose "  Tenant: $($context.Tenant.Id)"
       
        return $true
    }
    catch {
        Write-Error "Failed to connect to Azure with Managed Identity: $_"
        throw
    }
}
 
function Get-VMsFromManagementGroups {
    <#
    .SYNOPSIS
        Retrieves all VM names from specified management groups, organized by management group
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$ManagementGroupIds
    )
   
    try {
        # Hashtable to store VMs per management group
        $vmsByManagementGroup = @{}
        $allVMs = @()
       
        foreach ($mgId in $ManagementGroupIds) {
            Write-Verbose "Processing Management Group: $mgId"
            $mgVMs = @()
           
            # Get all subscriptions under this management group
            $subscriptions = Get-AzManagementGroupSubscription -GroupId $mgId -ErrorAction SilentlyContinue
           
            if ($subscriptions) {
                Write-Verbose "  Found $($subscriptions.Count) subscription(s) in management group"
               
                foreach ($sub in $subscriptions) {
                    # Extract subscription ID from the full resource ID path
                    $subId = if ($sub.Id -match '/subscriptions/([^/]+)') {
                        $matches[1]
                    } else {
                        $sub.Id
                    }
                   
                    Write-Verbose "    Scanning subscription: $($sub.DisplayName) ($subId)"
                   
                    # Set context to subscription
                    try {
                        $null = Set-AzContext -SubscriptionId $subId -ErrorAction Stop
                       
                        # Get all VMs in subscription
                        $vms = Get-AzVM -ErrorAction Stop
                       
                        if ($vms) {
                            Write-Verbose "      Found $($vms.Count) VM(s)"
                            $vmNames = $vms | Select-Object -ExpandProperty Name
                            $mgVMs += $vmNames
                            $allVMs += $vmNames
                        }
                        else {
                            Write-Verbose "      No VMs found"
                        }
                    }
                    catch {
                        Write-Warning "      Failed to retrieve VMs from subscription: $_"
                    }
                }
            }
            else {
                Write-Verbose "No subscriptions found in management group: $mgId"
            }
           
            # Store unique VMs for this management group
            $vmsByManagementGroup[$mgId] = @($mgVMs | Select-Object -Unique | Sort-Object)
            Write-Verbose "  VMs in $mgId`: $($vmsByManagementGroup[$mgId].Count)"
        }
       
        # Get unique VM names across all management groups
        $uniqueVMNames = $allVMs | Select-Object -Unique | Sort-Object
       
        Write-Verbose "Total unique VMs discovered: $($uniqueVMNames.Count)"
       
        # Return both the per-MG breakdown and the total list
        return @{
            ByManagementGroup = $vmsByManagementGroup
            AllVMs = @($uniqueVMNames)
        }
    }
    catch {
        Write-Error "Failed to retrieve VMs from management groups: $_"
        throw
    }
}
 
function Update-ApprovedVMNamesVariable {
    <#
    .SYNOPSIS
        Updates the Azure Automation variable with approved VM names
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$AutomationAccountName,
       
        [Parameter(Mandatory = $true)]
        [string]$AutomationAccountResGroupName,
       
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$DiscoveredVMNames
    )
   
    try {
        Write-Verbose "Retrieving current approved VM names from Automation variable..."
       
        # Get the current variable value
        $variable = Get-AzAutomationVariable -AutomationAccountName $AutomationAccountName `
            -ResourceGroupName $AutomationAccountResGroupName `
            -Name "ApprovedVMNamesJson" -ErrorAction Stop
 
   
        $currentJson = $variable.Value
        Write-Verbose "Current variable value retrieved"
       
        # Parse current JSON
        $currentData = $currentJson | ConvertFrom-Json
        $currentVMNames = $currentData.approvedVMNames
       
        Write-Verbose "Current approved VM count: $($currentVMNames.Count)"
       
        # Merge with discovered VMs (add new ones)
        $allVMNames = @()
        $allVMNames += $currentVMNames
        $allVMNames += $DiscoveredVMNames
       
        # Get unique names and sort - ensure we have a clean array
        $updatedVMNames = @($allVMNames | Where-Object { $_ } | Select-Object -Unique | Sort-Object)
       
        Write-Verbose "Updated approved VM count: $($updatedVMNames.Count)"
       
        # Calculate new additions
        $newVMs = $DiscoveredVMNames | Where-Object { $_ -notin $currentVMNames }
       
        if ($newVMs) {
            Write-Verbose "New VMs to be added: $($newVMs.Count)"
            foreach ($vm in $newVMs) {
                Write-Verbose "  - $vm"
            }
        }
        else {
            Write-Verbose "No new VMs to add"
        }
       
        # Create updated JSON
        $updatedData = @{
            approvedVMNames = $updatedVMNames
            lastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
       
        $updatedJson = $updatedData | ConvertTo-Json -Depth 10
       
        # Update the variable
 
        $null = Set-AzAutomationVariable -AutomationAccountName $AutomationAccountName `
            -ResourceGroupName $AutomationAccountResGroupName `
            -Name "ApprovedVMNamesJson" `
            -Value $updatedJson `
            -Encrypted $false `
            -ErrorAction Stop
       
        Write-Verbose "Successfully updated ApprovedVMNamesJson variable"
       
        # Identify manually added VMs (in variable but not in discovered list)
        $manuallyAddedVMs = @($currentVMNames | Where-Object { $_ -and ($_ -notin $DiscoveredVMNames) })
       
        if ($manuallyAddedVMs.Count -gt 0) {
            Write-Output "  Manually added VMs detected: $($manuallyAddedVMs.Count)"
            foreach ($vm in $manuallyAddedVMs) {
                Write-Output "    - $vm"
            }
        }
       
        # Return both the updated list and the manually added VMs
        return @{
            AllApprovedVMs = [string[]]$updatedVMNames
            ManuallyAddedVMs = [string[]]$manuallyAddedVMs
        }
    }
    catch {
        Write-Error "Failed to update approved VM names variable: $_"
        throw
    }
}
 
function New-VMCreationPolicyDefinition {
    <#
    .SYNOPSIS
        Creates or updates the VM creation restriction policy for a specific management group
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyDefinitionName,
       
        [Parameter(Mandatory = $true)]
        [array]$ApprovedVMNames,
       
        [Parameter(Mandatory = $true)]
        [string]$ManagementGroupId,
       
        [Parameter(Mandatory = $false)]
        [string]$Description = "This policy restricts VM creation to only approved VM names."
    )
   
    try {
        # Create a unique policy name for this management group
        $mgPolicyName = "$PolicyDefinitionName-$ManagementGroupId"
       
        Write-Verbose "Creating/updating policy definition: $mgPolicyName"
        Write-Verbose "Target Management Group: $ManagementGroupId"
        Write-Verbose "Approved VMs for this policy: $($ApprovedVMNames.Count)"
       
        # Create policy rule
        $policyRule = @{
            if = @{
                allOf = @(
                    @{
                        field = "type"
                        equals = "Microsoft.Compute/virtualMachines"
                    },
                    @{
                        field = "name"
                        notIn = "[parameters('approvedVMNames')]"
                    }
                )
            }
            then = @{
                effect = "deny"
            }
        }
       
        # Create policy parameters with this MG's VMs as default
        $policyParameters = @{
            approvedVMNames = @{
                type = "Array"
                metadata = @{
                    displayName = "Approved VM Names"
                    description = "List of approved virtual machine names for management group: $ManagementGroupId"
                }
                defaultValue = @($ApprovedVMNames)
            }
        }
       
        # Create policy metadata
        $policyMetadata = @{
            version = "1.0.0"
            category = "Compute"
            description = $Description
            managementGroup = $ManagementGroupId
        }
       
        # Build the full description with MG context and VM count
        $fullDescription = "$Description (Management Group: $ManagementGroupId, Approved VMs: $($ApprovedVMNames.Count))"
       
        # Convert to JSON
        $policyRuleJson = $policyRule | ConvertTo-Json -Depth 10
        $policyParametersJson = $policyParameters | ConvertTo-Json -Depth 10
       
        # Check if policy already exists
        $existingPolicy = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupId `
            -Name $mgPolicyName -ErrorAction SilentlyContinue
       
        if ($existingPolicy) {
            Write-Verbose "Policy definition already exists, updating..."
           
            $policy = Set-AzPolicyDefinition -Id $existingPolicy.ResourceId `
                -DisplayName "Restrict VM Creation - $ManagementGroupId" `
                -Description $fullDescription `
                -Policy $policyRuleJson `
                -Parameter $policyParametersJson `
                -Metadata ($policyMetadata | ConvertTo-Json -Depth 10) `
                -ErrorAction Stop
           
            Write-Verbose "Successfully updated policy definition"
        }
        else {
            Write-Verbose "Creating new policy definition..."
           
            $policy = New-AzPolicyDefinition -Name $mgPolicyName `
                -DisplayName "Restrict VM Creation - $ManagementGroupId" `
                -Description $fullDescription `
                -Policy $policyRuleJson `
                -Parameter $policyParametersJson `
                -Metadata ($policyMetadata | ConvertTo-Json -Depth 10) `
                -ManagementGroupName $ManagementGroupId `
                -ErrorAction Stop
           
            Write-Verbose "Successfully created policy definition"
        }
       
        Write-Verbose "Policy ID: $($policy.ResourceId)"
       
        return $policy
    }
    catch {
        Write-Error "Failed to create/update policy definition: $_"
        throw
    }
}
 
function New-VMCreationPolicyDefinitionAtSubscription {
    <#
    .SYNOPSIS
        Creates or updates the VM creation restriction policy at subscription level
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyDefinitionName,
       
        [Parameter(Mandatory = $true)]
        [array]$ApprovedVMNames
    )
   
    try {
        Write-Verbose "Creating/updating policy definition at subscription level: $PolicyDefinitionName"
       
        # Create policy rule
        $policyRule = @{
            if = @{
                allOf = @(
                    @{
                        field = "type"
                        equals = "Microsoft.Compute/virtualMachines"
                    },
                    @{
                        field = "name"
                        notIn = "[parameters('approvedVMNames')]"
                    }
                )
            }
            then = @{
                effect = "deny"
            }
        }
       
        # Create policy parameters
        $policyParameters = @{
            approvedVMNames = @{
                type = "Array"
                metadata = @{
                    displayName = "Approved VM Names"
                    description = "List of approved virtual machine names that can be created"
                }
                defaultValue = $ApprovedVMNames
            }
        }
       
        # Create policy metadata
        $policyMetadata = @{
            version = "1.0.0"
            category = "Compute"
            description = "Restricts VM creation to only approved VM names"
        }
       
        # Convert to JSON
        $policyRuleJson = $policyRule | ConvertTo-Json -Depth 10
        $policyParametersJson = $policyParameters | ConvertTo-Json -Depth 10
       
        # Check if policy already exists
        $existingPolicy = Get-AzPolicyDefinition -Name $PolicyDefinitionName -ErrorAction SilentlyContinue
       
        if ($existingPolicy) {
            Write-Verbose "Policy definition already exists, updating..."
           
            $policy = Set-AzPolicyDefinition -Id $existingPolicy.ResourceId `
                -DisplayName "Restrict VM Creation to Approved Names" `
                -Description "This policy restricts the creation of Azure VMs to only those with approved names from the centralized list" `
                -Policy $policyRuleJson `
                -Parameter $policyParametersJson `
                -Metadata ($policyMetadata | ConvertTo-Json -Depth 10) `
                -ErrorAction Stop
           
            Write-Verbose "Successfully updated policy definition"
        }
        else {
            Write-Verbose "Creating new policy definition at subscription..."
           
            $policy = New-AzPolicyDefinition -Name $PolicyDefinitionName `
                -DisplayName "Restrict VM Creation to Approved Names" `
                -Description "This policy restricts the creation of Azure VMs to only those with approved names from the centralized list" `
                -Policy $policyRuleJson `
                -Parameter $policyParametersJson `
                -Metadata ($policyMetadata | ConvertTo-Json -Depth 10) `
                -ErrorAction Stop
           
            Write-Verbose "Successfully created policy definition"
        }
       
        Write-Verbose "Policy ID: $($policy.ResourceId)"
        Write-Output "✓ Policy created at subscription level (can still be assigned to management groups)"
       
        return $policy
    }
    catch {
        Write-Error "Failed to create/update policy definition at subscription: $_"
        throw
    }
}
 
function Set-VMCreationPolicyAssignment {
    <#
    .SYNOPSIS
        Creates per-MG policy definitions and assigns them to their respective management groups
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyDefinitionBaseName,
       
        [Parameter(Mandatory = $true)]
        [array]$ManagementGroupIds,
       
        [Parameter(Mandatory = $true)]
        [hashtable]$VMsByManagementGroup,
       
        [Parameter(Mandatory = $false)]
        [string]$PolicyDisplayName = "Restrict VM Creation to Approved Names",
       
        [Parameter(Mandatory = $false)]
        [string]$PolicyDescription = "This policy restricts VM creation to only approved VM names."
    )
   
    try {
        $createdPolicies = @{}
       
        foreach ($mgId in $ManagementGroupIds) {
            Write-Output "  Processing Management Group: $mgId"
           
            # Get VMs specific to this management group
            $mgApprovedVMs = @()
            if ($VMsByManagementGroup.ContainsKey($mgId)) {
                $mgApprovedVMs = @($VMsByManagementGroup[$mgId])
            }
           
            Write-Verbose "  Approved VMs for this MG: $($mgApprovedVMs.Count)"
           
            # Create policy definition specific to this management group
            $policyDefinition = New-VMCreationPolicyDefinition `
                -PolicyDefinitionName $PolicyDefinitionBaseName `
                -ApprovedVMNames $mgApprovedVMs `
                -ManagementGroupId $mgId `
                -Description $PolicyDescription
           
            $createdPolicies[$mgId] = $policyDefinition
           
            # Create a short assignment name (max 24 chars)
            $assignmentName = if ($mgId.Length -le 12) {
                "vm-restrict-$mgId"
            } else {
                "vm-restrict-$($mgId.Substring(0,12))"
            }
           
            $scope = "/providers/Microsoft.Management/managementGroups/$mgId"
           
            # Check if assignment already exists
            $existingAssignment = Get-AzPolicyAssignment -Scope $scope `
                -Name $assignmentName -ErrorAction SilentlyContinue
           
            # Create parameters for assignment (using policy defaults, but can override)
            $policyParameters = @{
                approvedVMNames = @($mgApprovedVMs | ForEach-Object { [string]$_ })
            }
           
            if ($existingAssignment) {
                Write-Verbose "  Policy assignment already exists, updating..."
               
                $assignment = Set-AzPolicyAssignment -Id $existingAssignment.ResourceId `
                    -DisplayName "$PolicyDisplayName - $mgId" `
                    -PolicyParameterObject $policyParameters `
                    -ErrorAction Stop
               
                Write-Verbose "  Successfully updated policy assignment"
            }
            else {
                Write-Verbose "  Creating new policy assignment..."
               
                $assignment = New-AzPolicyAssignment -Name $assignmentName `
                    -DisplayName "$PolicyDisplayName - $mgId" `
                    -Description "Restricts VM creation to approved names for this management group ($($mgApprovedVMs.Count) VMs)" `
                    -Scope $scope `
                    -PolicyDefinition $policyDefinition `
                    -PolicyParameterObject $policyParameters `
                    -ErrorAction Stop
               
                Write-Verbose "  Successfully created policy assignment"
            }
           
            Write-Verbose "  Assignment ID: $($assignment.ResourceId)"
            Write-Output "    ✓ Policy Definition: $($policyDefinition.Name)"
            Write-Output "    ✓ Approved VMs: $($mgApprovedVMs.Count)"
            if ($mgApprovedVMs.Count -gt 0) {
                foreach ($vm in $mgApprovedVMs) {
                    Write-Output "      - $vm"
                }
            }
           
            # Output Policy Definition JSON
            Write-Output ""
            Write-Output "    --- Policy Definition JSON ---"
            $policyDefJson = @{
                Name = $policyDefinition.Name
                ResourceId = $policyDefinition.ResourceId
                DisplayName = $policyDefinition.DisplayName
                Description = $policyDefinition.Description
                PolicyType = $policyDefinition.PolicyType
                Mode = $policyDefinition.Mode
                Metadata = $policyDefinition.Metadata | ConvertFrom-Json -ErrorAction SilentlyContinue
                Parameters = $policyDefinition.Parameter | ConvertFrom-Json -ErrorAction SilentlyContinue
                PolicyRule = $policyDefinition.PolicyRule | ConvertFrom-Json -ErrorAction SilentlyContinue
            } | ConvertTo-Json -Depth 10
            Write-Output $policyDefJson
            Write-Output "    --- End Policy Definition JSON ---"
           
            # Output Policy Assignment JSON
            Write-Output ""
            Write-Output "    --- Policy Assignment JSON ---"
            $assignmentJson = @{
                Name = $assignment.Name
                ResourceId = $assignment.ResourceId
                DisplayName = $assignment.DisplayName
                Description = $assignment.Description
                Scope = $assignment.Scope
                PolicyDefinitionId = $assignment.PolicyDefinitionId
                Parameters = $assignment.Parameters
                EnforcementMode = $assignment.EnforcementMode
            } | ConvertTo-Json -Depth 10
            Write-Output $assignmentJson
            Write-Output "    --- End Policy Assignment JSON ---"
            Write-Output ""
        }
       
        Write-Verbose "Successfully created policies and assignments for all management groups"
        return $createdPolicies
    }
    catch {
        Write-Error "Failed to create policy/assignment: $_"
        throw
    }
}
 
#endregion
 
#region Main Script
 
try {
    Write-Output "====================================="
    Write-Output "VM Creation Policy Management Runbook"
    Write-Output "Started: $(Get-Date)"
    Write-Output "====================================="
    Write-Output ""
   
    # STEP 1: Connect to Azure with Managed Identity
    Write-Output "STEP 1: Connecting to Azure with Managed Identity"
    Write-Output "---------------------------------------------------"
    $connected = Connect-AzureWithManagedIdentity -RunbookSubscriptionID $RunbookSubscriptionID -UserManagedID $UserManagedID
   
    if (-not $connected) {
        throw "Failed to connect to Azure"
    }
   
    Write-Output "✓ Successfully connected to Azure"
    Write-Output ""
   
    # Get automation account context if not provided
    if (-not $AutomationAccountName -or -not $AutomationAccountResGroupName) {
        Write-Verbose "Attempting to detect Automation Account context..."
       
        # Try to get from environment (when running in Azure Automation)
        $AutomationAccountName = Get-AutomationVariable -Name "AutomationAccountName" -ErrorAction SilentlyContinue
        $AutomationAccountResGroupName = Get-AutomationVariable -Name "AutomationAccountResGroupName" -ErrorAction SilentlyContinue
       
        if (-not $AutomationAccountName -or -not $AutomationAccountResGroupName) {
            throw "AutomationAccountName and AutomationAccountResGroupName must be provided as parameters or stored as Automation variables"
        }
    }
   
    Write-Verbose "Using Automation Account: $AutomationAccountName (RG: $AutomationAccountResGroupName)"
   
    # STEP 2: Scan VMs in Management Groups
    Write-Output "STEP 2: Scanning Virtual Machines in Management Groups"
    Write-Output "--------------------------------------------------------"
   
    # Get management groups from variable
    Write-Verbose "Retrieving management groups configuration..."
    $mgVariable = Get-AzAutomationVariable -AutomationAccountName $AutomationAccountName `
        -ResourceGroupName $AutomationAccountResGroupName `
        -Name "ManagementGroupsJson" -ErrorAction Stop
   
    $mgData = $mgVariable.Value | ConvertFrom-Json
    $managementGroups = $mgData.managementGroups
   
    Write-Output "Target Management Groups: $($managementGroups.Count)"
    foreach ($mg in $managementGroups) {
        Write-Output "  - $mg"
    }
    Write-Output ""
   
    # List subscriptions under each management group
    foreach ($mg in $managementGroups) {
        $subs = Get-AzManagementGroupSubscription -GroupId $mg -ErrorAction SilentlyContinue
        if ($subs) {
            Write-Output "  Subscriptions under $mg`:"
            foreach ($sub in $subs) {
                Write-Output "    - $($sub.DisplayName)"
            }
        } else {
            Write-Output "  No subscriptions found under $mg"
        }
    }
    Write-Output ""
   
    $vmDiscoveryResult = Get-VMsFromManagementGroups -ManagementGroupIds $managementGroups
    $discoveredVMs = $vmDiscoveryResult.AllVMs
    $vmsByManagementGroup = $vmDiscoveryResult.ByManagementGroup
   
    Write-Output "✓ VM scan completed"
    Write-Output "  Total VMs discovered: $($discoveredVMs.Count)"
    if ($discoveredVMs.Count -gt 0) {
        Write-Output "  VMs by Management Group:"
        foreach ($mgId in $managementGroups) {
            $mgVMs = $vmsByManagementGroup[$mgId]
            Write-Output "    $mgId`: $($mgVMs.Count) VMs"
            foreach ($vm in $mgVMs) {
                Write-Output "      - $vm"
            }
        }
    }
    Write-Output ""
   
    # STEP 3: Update Approved VM Names Variable
    Write-Output "STEP 3: Updating Approved VM Names Variable"
    Write-Output "--------------------------------------------"
   
    # Restore context to the Automation Account subscription (may have changed during VM scan)
    $null = Set-AzContext -SubscriptionId $RunbookSubscriptionID -ErrorAction Stop
   
    # Ensure we have an array even if no VMs were discovered
    if (-not $discoveredVMs) {
        $discoveredVMs = @()
    }
   
    $approvedVMResult = Update-ApprovedVMNamesVariable `
        -AutomationAccountName $AutomationAccountName `
        -AutomationAccountResGroupName $AutomationAccountResGroupName `
        -DiscoveredVMNames $discoveredVMs
   
    $approvedVMNames = $approvedVMResult.AllApprovedVMs
    $manuallyAddedVMs = $approvedVMResult.ManuallyAddedVMs
   
    Write-Output "✓ Approved VM names variable updated"
    Write-Output "  Total approved VMs: $($approvedVMNames.Count)"
    if ($null -ne $manuallyAddedVMs -and $manuallyAddedVMs.Count -gt 0) {
        Write-Output "  Manually added VMs (will be added to ALL management group policies): $($manuallyAddedVMs.Count)"
    }
    Write-Output ""
   
    # Merge manually added VMs into each management group's VM list
    if ($null -ne $manuallyAddedVMs -and $manuallyAddedVMs.Count -gt 0) {
        Write-Output "Merging manually added VMs into each management group's policy..."
        foreach ($mgId in $managementGroups) {
            $currentMgVMs = @()
            if ($vmsByManagementGroup.ContainsKey($mgId)) {
                $currentMgVMs = @($vmsByManagementGroup[$mgId])
            }
            $mergedVMs = @(($currentMgVMs + $manuallyAddedVMs) | Where-Object { $_ } | Select-Object -Unique | Sort-Object)
            $vmsByManagementGroup[$mgId] = $mergedVMs
            Write-Output "  $mgId`: $($currentMgVMs.Count) discovered + $($manuallyAddedVMs.Count) manual = $($mergedVMs.Count) total"
        }
        Write-Output ""
    }
   
    # STEP 4: Create/Update Azure Policies (one per management group)
    Write-Output "STEP 4: Creating/Updating Azure Policies (per Management Group)"
    Write-Output "----------------------------------------------------------------"
   
    # Create separate policy definitions for each management group
    Write-Output "Creating separate policy definitions for each management group..."
    Write-Output "Each policy will contain the VMs from its management group PLUS any manually added VMs."
    Write-Output ""
   
    $createdPolicies = Set-VMCreationPolicyAssignment `
        -PolicyDefinitionBaseName $PolicyDefinitionName `
        -ManagementGroupIds $managementGroups `
        -VMsByManagementGroup $vmsByManagementGroup `
        -PolicyDisplayName $PolicyDisplayName `
        -PolicyDescription $PolicyDescription
   
    Write-Output ""
    Write-Output "✓ Policy definitions and assignments completed"
    Write-Output "  Policies created: $($createdPolicies.Count)"
    foreach ($mgId in $createdPolicies.Keys) {
        Write-Output "    - $($createdPolicies[$mgId].Name)"
    }
    Write-Output ""
   
    # STEP 5: Summary
    Write-Output "====================================="
    Write-Output "RUNBOOK COMPLETED SUCCESSFULLY"
    Write-Output "====================================="
    Write-Output "Summary:"
    Write-Output "  Management Groups Processed: $($managementGroups.Count)"
    Write-Output "  VMs Discovered: $($discoveredVMs.Count)"
    Write-Output "  Total Approved VMs (all MGs): $($approvedVMNames.Count)"
    Write-Output "  Policy Definitions Created: $($managementGroups.Count) (one per MG)"
    Write-Output "  Policy Assignments: $($managementGroups.Count)"
    Write-Output "  Manually Added VMs: $($manuallyAddedVMs.Count)"
    Write-Output ""
    Write-Output "  Per-Management Group Breakdown (including manually added VMs):"
    foreach ($mgId in $managementGroups) {
        $mgVMs = $vmsByManagementGroup[$mgId]
        Write-Output "    $mgId`: $($mgVMs.Count) VMs in policy"
    }
    Write-Output ""
    Write-Output "Completed: $(Get-Date)"
    Write-Output "====================================="
}
catch {
    Write-Error "Runbook failed: $_"
    Write-Error $_.ScriptStackTrace
    throw
}
 
#endregion