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
    [string]$AutomationAccountName = "automation-eus2-aa",
    
    [Parameter(Mandatory = $false)]
    [string]$AutomationAccountResGroupName = "automation-eus2-rg",
    
    [Parameter(Mandatory = $false)]
    [string]$PolicyDefinitionName = "Restrict-VM-Creation-by-Name"
)

#region Functions

function Connect-AzureWithManagedIdentity {
    <#
    .SYNOPSIS
        Connects to Azure using the Automation Account's Managed Identity
    #>
    try {
        Write-Verbose "Attempting to connect to Azure using Managed Identity..."
        
        # Connect using system-assigned managed identity
        $null = Connect-AzAccount -Identity -ErrorAction Stop
        
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
        Retrieves all VM names from specified management groups
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$ManagementGroupIds
    )
    
    try {
        $allVMs = @()
        
        foreach ($mgId in $ManagementGroupIds) {
            Write-Verbose "Processing Management Group: $mgId"
            
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
                            $allVMs += $vms | Select-Object -ExpandProperty Name
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
                Write-Verbose "  No subscriptions found in management group: $mgId"
            }
        }
        
        # Get unique VM names
        $uniqueVMNames = $allVMs | Select-Object -Unique | Sort-Object
        
        Write-Verbose "Total unique VMs discovered: $($uniqueVMNames.Count)"
        
        return $uniqueVMNames
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
        
        # Return only the clean array of strings - convert to ensure plain string array
        return [string[]]$updatedVMNames
    }
    catch {
        Write-Error "Failed to update approved VM names variable: $_"
        throw
    }
}

function New-VMCreationPolicyDefinition {
    <#
    .SYNOPSIS
        Creates or updates the VM creation restriction policy
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyDefinitionName,
        
        [Parameter(Mandatory = $true)]
        [array]$ApprovedVMNames,
        
        [Parameter(Mandatory = $true)]
        [string]$ManagementGroupId
    )
    
    try {
        Write-Verbose "Creating/updating policy definition: $PolicyDefinitionName"
        Write-Verbose "Target Management Group: $ManagementGroupId"
        
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
        $existingPolicy = Get-AzPolicyDefinition -ManagementGroupName $ManagementGroupId `
            -Name $PolicyDefinitionName -ErrorAction SilentlyContinue
        
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
            Write-Verbose "Creating new policy definition..."
            
            $policy = New-AzPolicyDefinition -Name $PolicyDefinitionName `
                -DisplayName "Restrict VM Creation to Approved Names" `
                -Description "This policy restricts the creation of Azure VMs to only those with approved names from the centralized list" `
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
        Assigns the VM creation policy to management groups
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$PolicyDefinitionId,
        
        [Parameter(Mandatory = $true)]
        [array]$ManagementGroupIds,
        
        [Parameter(Mandatory = $true)]
        [array]$ApprovedVMNames
    )
    
    try {
        foreach ($mgId in $ManagementGroupIds) {
            Write-Verbose "Assigning policy to Management Group: $mgId"
            
            # Create a short assignment name (max 24 chars) using hash if needed
            $assignmentName = if ($mgId.Length -le 16) {
                "vm-restrict-$mgId"
            } else {
                # Use first 16 chars of mgId
                "vm-restrict-$($mgId.Substring(0,16))"
            }
            
            $scope = "/providers/Microsoft.Management/managementGroups/$mgId"
            
            # Check if assignment already exists
            $existingAssignment = Get-AzPolicyAssignment -Scope $scope `
                -Name $assignmentName -ErrorAction SilentlyContinue
            
            # Create parameters for assignment - ensure clean string array
            $policyParameters = @{
                approvedVMNames = @($ApprovedVMNames | ForEach-Object { [string]$_ })
            }
            
            if ($existingAssignment) {
                Write-Verbose "  Policy assignment already exists, updating..."
                
                $assignment = Set-AzPolicyAssignment -Id $existingAssignment.ResourceId `
                    -DisplayName "Restrict VM Creation to Approved Names - $mgId" `
                    -PolicyParameterObject $policyParameters `
                    -ErrorAction Stop
                
                Write-Verbose "  Successfully updated policy assignment"
            }
            else {
                Write-Verbose "  Creating new policy assignment..."
                
                # Get the policy definition object
                $policyDef = Get-AzPolicyDefinition -Id $PolicyDefinitionId -ErrorAction Stop
                
                $assignment = New-AzPolicyAssignment -Name $assignmentName `
                    -DisplayName "Restrict VM Creation to Approved Names - $mgId" `
                    -Description "Restricts VM creation to approved names at the management group level" `
                    -Scope $scope `
                    -PolicyDefinition $policyDef `
                    -PolicyParameterObject $policyParameters `
                    -ErrorAction Stop
                
                Write-Verbose "  Successfully created policy assignment"
            }
            
            Write-Verbose "  Assignment ID: $($assignment.ResourceId)"
        }
        
        Write-Verbose "Successfully assigned policy to all management groups"
    }
    catch {
        Write-Error "Failed to assign policy: $_"
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
    $connected = Connect-AzureWithManagedIdentity
    
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
    
    $discoveredVMs = Get-VMsFromManagementGroups -ManagementGroupIds $managementGroups
    
    Write-Output "✓ VM scan completed"
    Write-Output "  Total VMs discovered: $($discoveredVMs.Count)"
    if ($discoveredVMs.Count -gt 0) {
        Write-Output "  Discovered VMs:"
        foreach ($vm in $discoveredVMs) {
            Write-Output "    - $vm"
        }
    }
    Write-Output ""
    
    # STEP 3: Update Approved VM Names Variable
    Write-Output "STEP 3: Updating Approved VM Names Variable"
    Write-Output "--------------------------------------------"
    
    # Ensure we have an array even if no VMs were discovered
    if (-not $discoveredVMs) {
        $discoveredVMs = @()
    }
    
    $approvedVMNames = Update-ApprovedVMNamesVariable `
        -AutomationAccountName $AutomationAccountName `
        -AutomationAccountResGroupName $AutomationAccountResGroupName `
        -DiscoveredVMNames $discoveredVMs
    
    Write-Output "✓ Approved VM names variable updated"
    Write-Output "  Total approved VMs: $($approvedVMNames.Count)"
    Write-Output ""
    
    # STEP 4: Create/Update Azure Policy
    Write-Output "STEP 4: Creating/Updating Azure Policy"
    Write-Output "---------------------------------------"
    
    # Attempt to find where we can create the policy definition
    # First, check if it already exists at management group level
    $primaryMgId = $managementGroups[0]
    $existingPolicy = Get-AzPolicyDefinition -Name $PolicyDefinitionName -ManagementGroupName $primaryMgId -ErrorAction SilentlyContinue
    
    if ($existingPolicy) {
        Write-Verbose "Found existing policy definition at management group level"
        $policyDefinition = $existingPolicy
    } else {
        # Try to create at management group level
        Write-Verbose "Attempting to create policy definition at management group: $primaryMgId"
        
        try {
            $policyDefinition = New-VMCreationPolicyDefinition `
                -PolicyDefinitionName $PolicyDefinitionName `
                -ApprovedVMNames $approvedVMNames `
                -ManagementGroupId $primaryMgId
        }
        catch {
            Write-Warning "Failed to create policy at management group level: $_"
            Write-Output "Attempting to create policy at subscription level instead..."
            
            # Fallback: Create at subscription level where we have Owner rights
            $currentContext = Get-AzContext
            $policyDefinition = New-VMCreationPolicyDefinitionAtSubscription `
                -PolicyDefinitionName $PolicyDefinitionName `
                -ApprovedVMNames $approvedVMNames
        }
    }
    
    Write-Output "✓ Policy definition created/updated"
    Write-Output "  Policy Name: $PolicyDefinitionName"
    Write-Output "  Policy ID: $($policyDefinition.ResourceId)"
    Write-Output ""
    
    # Assign policy to all management groups
    Write-Output "Assigning policy to management groups..."
    
    Set-VMCreationPolicyAssignment `
        -PolicyDefinitionId $policyDefinition.ResourceId `
        -ManagementGroupIds $managementGroups `
        -ApprovedVMNames $approvedVMNames
    
    Write-Output "✓ Policy assignments completed"
    Write-Output ""
    
    # STEP 5: Summary
    Write-Output "====================================="
    Write-Output "RUNBOOK COMPLETED SUCCESSFULLY"
    Write-Output "====================================="
    Write-Output "Summary:"
    Write-Output "  Management Groups Processed: $($managementGroups.Count)"
    Write-Output "  VMs Discovered: $($discoveredVMs.Count)"
    Write-Output "  Total Approved VMs: $($approvedVMNames.Count)"
    Write-Output "  Policy Definition: $PolicyDefinitionName"
    Write-Output "  Policy Assignments: $($managementGroups.Count)"
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
