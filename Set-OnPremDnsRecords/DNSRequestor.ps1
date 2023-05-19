#region Script Settings
#<ScriptSettings xmlns="http://tempuri.org/ScriptSettings.xsd">
#  <ScriptPackager>
#    <process>powershell.exe</process>
#    <arguments />
#    <extractdir>%TEMP%</extractdir>
#    <files />
#    <usedefaulticon>true</usedefaulticon>
#    <showinsystray>false</showinsystray>
#    <altcreds>false</altcreds>
#    <efs>true</efs>
#    <ntfs>true</ntfs>
#    <local>false</local>
#    <abortonfail>true</abortonfail>
#    <product />
#    <version>1.0.0.1</version>
#    <versionstring />
#    <comments />
#    <company />
#    <includeinterpreter>false</includeinterpreter>
#    <forcecomregistration>false</forcecomregistration>
#    <consolemode>false</consolemode>
#    <EnableChangelog>false</EnableChangelog>
#    <AutoBackup>false</AutoBackup>
#    <snapinforce>false</snapinforce>
#    <snapinshowprogress>false</snapinshowprogress>
#    <snapinautoadd>2</snapinautoadd>
#    <snapinpermanentpath />
#    <cpumode>1</cpumode>
#    <hidepsconsole>false</hidepsconsole>
#  </ScriptPackager>
#</ScriptSettings>
#endregion

#region ScriptForm Designer

#region Constructor

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

#endregion

# Set Static Variables
$SubscriptionID = '708e166e-08d1-40b0-afb1-2b1b7f15e57f'
$AutomationAccountName = 'azautomation-eastus2'
$RunbookResourceGroupName = 'automation-rg'
$RunbookName = 'Set-OnPremDnsRecords'
$defaultZoneName = 'wcurtis.net'
$defaultDNSServerFQDN = 'wcurtisnetdc.wcurtis.net'

# Set Preferences
$ErrorActionPreference = 'Stop'

#region Post-Constructor Custom Code

#endregion

#region Form Creation
#Warning: It is recommended that changes inside this region be handled using the ScriptForm Designer.
#When working with the ScriptForm designer this region and any changes within may be overwritten.
#~~< MainForm >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$MainForm = New-Object System.Windows.Forms.Form
$MainForm.ClientSize = New-Object System.Drawing.Size(551, 536)
$MainForm.Font = New-Object System.Drawing.Font("Segoe UI", 11.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$MainForm.Text = "DNS Requestor"
#~~< ButtonExecuteRunbook >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ButtonExecuteRunbook = New-Object System.Windows.Forms.Button
$ButtonExecuteRunbook.AccessibleDescription = "Executes Runbook in Azure to create/delete/update DNS records"
$ButtonExecuteRunbook.Enabled = $false
$ButtonExecuteRunbook.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$ButtonExecuteRunbook.Location = New-Object System.Drawing.Point(374, 345)
$ButtonExecuteRunbook.Size = New-Object System.Drawing.Size(131, 23)
$ButtonExecuteRunbook.TabIndex = 11
$ButtonExecuteRunbook.Text = "Execute Runbook"
$ButtonExecuteRunbook.UseVisualStyleBackColor = $true
$ButtonExecuteRunbook.add_Click({ ButtonExecuteRunbookClick($ButtonExecuteRunbook) })
#~~< RichTextBoxStatus >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$RichTextBoxStatus = New-Object System.Windows.Forms.RichTextBox
$RichTextBoxStatus.Location = New-Object System.Drawing.Point(23, 390)
$RichTextBoxStatus.Size = New-Object System.Drawing.Size(502, 134)
$RichTextBoxStatus.TabIndex = 10
$RichTextBoxStatus.Text = ""
#~~< TextBoxRecordName >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$TextBoxRecordName = New-Object System.Windows.Forms.TextBox
$TextBoxRecordName.Enabled = $false
$TextBoxRecordName.Location = New-Object System.Drawing.Point(137, 194)
$TextBoxRecordName.Size = New-Object System.Drawing.Size(213, 27)
$TextBoxRecordName.TabIndex = 6
$TextBoxRecordName.Text = ""
$TextBoxRecordName.add_TextChanged({ TextBoxRecordNameTextChanged($TextBoxRecordName) })
#~~< LabelRecordName >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$LabelRecordName = New-Object System.Windows.Forms.Label
$LabelRecordName.Font = New-Object System.Drawing.Font("Tahoma", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$LabelRecordName.Location = New-Object System.Drawing.Point(23, 194)
$LabelRecordName.Size = New-Object System.Drawing.Size(84, 27)
$LabelRecordName.TabIndex = 0
$LabelRecordName.Text = "Record Name"
#~~< TextBoxDNSFQDN >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$TextBoxDNSFQDN = New-Object System.Windows.Forms.TextBox
$TextBoxDNSFQDN.Enabled = $false
$TextBoxDNSFQDN.Location = New-Object System.Drawing.Point(137, 304)
$TextBoxDNSFQDN.Size = New-Object System.Drawing.Size(213, 27)
$TextBoxDNSFQDN.TabIndex = 9
$TextBoxDNSFQDN.Text = $defaultDNSServerFQDN
$TextBoxDNSFQDN.add_TextChanged({ TextBoxDNSFQDNTextChanged($TextBoxDNSFQDN) })
#~~< LabelDNSFQDN >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$LabelDNSFQDN = New-Object System.Windows.Forms.Label
$LabelDNSFQDN.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$LabelDNSFQDN.Location = New-Object System.Drawing.Point(23, 304)
$LabelDNSFQDN.Size = New-Object System.Drawing.Size(100, 27)
$LabelDNSFQDN.TabIndex = 0
$LabelDNSFQDN.Text = "DNS Server FQDN"
#~~< TextBoxZoneName >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$TextBoxZoneName = New-Object System.Windows.Forms.TextBox
$TextBoxZoneName.Enabled = $false
$TextBoxZoneName.Location = New-Object System.Drawing.Point(137, 265)
$TextBoxZoneName.Size = New-Object System.Drawing.Size(213, 27)
$TextBoxZoneName.TabIndex = 8
$TextBoxZoneName.Text = $defaultZoneName
$TextBoxZoneName.add_TextChanged({ TextBoxZoneNameTextChanged($TextBoxZoneName) })

#~~< LabelZoneName >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$LabelZoneName = New-Object System.Windows.Forms.Label
$LabelZoneName.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$LabelZoneName.Location = New-Object System.Drawing.Point(23, 265)
$LabelZoneName.Size = New-Object System.Drawing.Size(73, 27)
$LabelZoneName.TabIndex = 0
$LabelZoneName.Text = "Zone Name"
#~~< TextBoxRecordData >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$TextBoxRecordData = New-Object System.Windows.Forms.TextBox
$TextBoxRecordData.Enabled = $false
$TextBoxRecordData.Location = New-Object System.Drawing.Point(137, 229)
$TextBoxRecordData.Size = New-Object System.Drawing.Size(213, 27)
$TextBoxRecordData.TabIndex = 7
$TextBoxRecordData.Text = ""
$TextBoxRecordData.add_TextChanged({ TextBoxRecordDataTextChanged($TextBoxRecordData) })
#~~< LabelRecordData >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$LabelRecordData = New-Object System.Windows.Forms.Label
$LabelRecordData.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$LabelRecordData.Location = New-Object System.Drawing.Point(23, 229)
$LabelRecordData.Size = New-Object System.Drawing.Size(73, 27)
$LabelRecordData.TabIndex = 0
$LabelRecordData.Text = "Record Data"
#~~< LabelRecordType >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$LabelRecordType = New-Object System.Windows.Forms.Label
$LabelRecordType.Font = New-Object System.Drawing.Font("Tahoma", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$LabelRecordType.Location = New-Object System.Drawing.Point(23, 161)
$LabelRecordType.Size = New-Object System.Drawing.Size(108, 23)
$LabelRecordType.TabIndex = 0
$LabelRecordType.Text = "Record Type"
#~~< ComboBoxRecordType >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ComboBoxRecordType = New-Object System.Windows.Forms.ComboBox
$ComboBoxRecordType.Enabled = $false
$ComboBoxRecordType.FormattingEnabled = $true
$ComboBoxRecordType.Location = New-Object System.Drawing.Point(137, 158)
$ComboBoxRecordType.SelectedIndex = -1
$ComboBoxRecordType.Size = New-Object System.Drawing.Size(213, 28)
$ComboBoxRecordType.TabIndex = 5
$ComboBoxRecordType.Text = ""
$ComboBoxRecordType.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
$ComboBoxRecordType.add_SelectedIndexChanged({ ComboBoxRecordTypeSelectedIndexChanged($ComboBoxRecordType) })
#~~< RadioButtonDelete >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$RadioButtonDelete = New-Object System.Windows.Forms.RadioButton
$RadioButtonDelete.Enabled = $false
$RadioButtonDelete.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$RadioButtonDelete.Location = New-Object System.Drawing.Point(202, 91)
$RadioButtonDelete.Size = New-Object System.Drawing.Size(104, 24)
$RadioButtonDelete.TabIndex = 4
$RadioButtonDelete.TabStop = $true
$RadioButtonDelete.Text = "Delete"
$RadioButtonDelete.UseVisualStyleBackColor = $true
$RadioButtonDelete.Checked = $false
$RadioButtonDelete.add_CheckedChanged({ RadioButtonDeleteCheckedChanged($RadioButtonDelete) })
#~~< RadioButtonRead >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$RadioButtonRead = New-Object System.Windows.Forms.RadioButton
$RadioButtonRead.Enabled = $false
$RadioButtonRead.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$RadioButtonRead.Location = New-Object System.Drawing.Point(137, 91)
$RadioButtonRead.Size = New-Object System.Drawing.Size(104, 24)
$RadioButtonRead.TabIndex = 3
$RadioButtonRead.TabStop = $true
$RadioButtonRead.Text = "Read"
$RadioButtonRead.UseVisualStyleBackColor = $true
$RadioButtonRead.Checked = $false
$RadioButtonRead.add_CheckedChanged({ RadioButtonReadCheckedChanged($RadioButtonRead) })
#~~< RadioButtonCreate >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$RadioButtonCreate = New-Object System.Windows.Forms.RadioButton
$RadioButtonCreate.AccessibleDescription = "Creates a CNAME, A, or PTR record"
$RadioButtonCreate.Enabled = $false
$RadioButtonCreate.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$RadioButtonCreate.Location = New-Object System.Drawing.Point(67, 91)
$RadioButtonCreate.Size = New-Object System.Drawing.Size(104, 24)
$RadioButtonCreate.TabIndex = 2
$RadioButtonCreate.TabStop = $true
$RadioButtonCreate.Text = "Create"
$RadioButtonCreate.Checked = $false
$RadioButtonCreate.UseVisualStyleBackColor = $true
$RadioButtonCreate.add_CheckedChanged({ RadioButtonCreateCheckedChanged($RadioButtonCreate) })
#~~< LabelAction >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$LabelAction = New-Object System.Windows.Forms.Label
$LabelAction.AccessibleDescription = "Select one of the following 3 options."
$LabelAction.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$LabelAction.Location = New-Object System.Drawing.Point(12, 67)
$LabelAction.Size = New-Object System.Drawing.Size(118, 30)
$LabelAction.TabIndex = 0
$LabelAction.Text = "Select Action"
#~~< LabelIsAzConnected >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$LabelIsAzConnected = New-Object System.Windows.Forms.Label
$LabelIsAzConnected.Font = New-Object System.Drawing.Font("Tahoma", 8.25, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$LabelIsAzConnected.Location = New-Object System.Drawing.Point(137, 13)
$LabelIsAzConnected.Size = New-Object System.Drawing.Size(402, 28)
$LabelIsAzConnected.TabIndex = 0
$LabelIsAzConnected.Text = "Not Connected  to Azure"
$LabelIsAzConnected.ForeColor = [System.Drawing.Color]::Red
#~~< ButtonAzureConnect >~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
$ButtonAzureConnect = New-Object System.Windows.Forms.Button
$ButtonAzureConnect.AccessibleDescription = "Click here to connect to Azure."
$ButtonAzureConnect.Font = New-Object System.Drawing.Font("Segoe UI", 8.25, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Point, ([System.Byte](0)))
$ButtonAzureConnect.Location = New-Object System.Drawing.Point(12, 12)
$ButtonAzureConnect.Size = New-Object System.Drawing.Size(118, 29)
$ButtonAzureConnect.TabIndex = 1
$ButtonAzureConnect.Text = "Connect to Azure"
$ButtonAzureConnect.UseVisualStyleBackColor = $true
$ButtonAzureConnect.add_Click({ ButtonAzureConnectClick -SubscriptionID $SubscriptionID })
$MainForm.Controls.Add($ButtonExecuteRunbook)
$MainForm.Controls.Add($RichTextBoxStatus)
$MainForm.Controls.Add($TextBoxRecordName)
$MainForm.Controls.Add($LabelRecordName)
$MainForm.Controls.Add($TextBoxDNSFQDN)
$MainForm.Controls.Add($LabelDNSFQDN)
$MainForm.Controls.Add($TextBoxZoneName)
$MainForm.Controls.Add($LabelZoneName)
$MainForm.Controls.Add($TextBoxRecordData)
$MainForm.Controls.Add($LabelRecordData)
$MainForm.Controls.Add($LabelRecordType)
$MainForm.Controls.Add($ComboBoxRecordType)
$MainForm.Controls.Add($RadioButtonDelete)
$MainForm.Controls.Add($RadioButtonRead)
$MainForm.Controls.Add($RadioButtonCreate)
$MainForm.Controls.Add($LabelAction)
$MainForm.Controls.Add($LabelIsAzConnected)
$MainForm.Controls.Add($ButtonAzureConnect)

#endregion

#region Custom Code

#endregion

#region Event Loop

function Main {
	[System.Windows.Forms.Application]::EnableVisualStyles()
	$MainForm.ShowDialog()
}

#endregion

#endregion

#region Event Handlers

function RadioButtonCreateCheckedChanged( $object ) {

	

	if ($RadioButtonCreate.Checked -eq $true) {


		reset-FormData

		$ComboBoxRecordType.Enabled = $true
		$ComboBoxRecordType.Items.Clear()
		$ComboBoxRecordType.Items.Add('A')
		$ComboBoxRecordType.Items.Add('CNAME')
		$ComboBoxRecordType.Items.Add('PTR')
		


	}



}

function ButtonExecuteRunbookClick( $object ) {

	
}

function TextBoxRecordNameTextChanged( $object ) {

}

function TextBoxDNSFQDNTextChanged( $object ) {

}

function TextBoxZoneNameTextChanged( $object ) {

}

function TextBoxRecordDataTextChanged( $object ) {

}

function ComboBoxRecordTypeSelectedIndexChanged( $object ) {

	
	if ($RadioButtonCreate.Checked -eq $true) {
	
	switch ($ComboBoxRecordType.SelectedItem) {
	
		'A' {

			reset-FormData
			$TextBoxRecordName.Enabled = $true
			$TextBoxRecordData.Enabled  = $true
			$LabelRecordData.Enabled = $true
			$LabelRecordData.Text = 'IPv4 Address'
			$TextBoxZoneName.Enabled = $true
			$TextBoxDNSFQDN.Enabled = $true
			$ButtonExecuteRunbook.Enabled = $true
		

		}

		'CNAME' {

			reset-FormData
			$TextBoxRecordName.Enabled = $true
			$TextBoxRecordData.Enabled  = $true
			$LabelRecordData.Enabled = $true
			$LabelRecordData.Text = 'Host Name Alias'
			$TextBoxZoneName.Enabled = $true
			$TextBoxDNSFQDN.Enabled = $true
			$ButtonExecuteRunbook.Enabled = $true
		}


		'PTR' {

			reset-FormData
			$TextBoxRecordName.Enabled = $true
			$TextBoxRecordData.Enabled  = $true
			$LabelRecordData.Text = 'Ptr Domain Name'
			$LabelRecordData.Enabled = $true
			$TextBoxZoneName.Enabled = $true
			$TextBoxZoneName.Text = ''
			$TextBoxDNSFQDN.Enabled = $true
			$ButtonExecuteRunbook.Enabled = $true

		}

	}

}

if ($RadioButtonDelete.Checked -eq $true) {


	reset-FormData

	$ComboBoxRecordType.Enabled = $true
	$TextBoxRecordData.Enabled = $false
	$LabelRecordData.Enabled = $false
	$TextBoxRecordName.Enabled = $true
	$TextBoxZoneName.Enabled = $true
	$TextBoxDNSFQDN.Enabled = $true	
    

}


if ($RadioButtonRead.Checked -eq $true) {

	reset-FormData

	$ComboBoxRecordType.Enabled = $false
	$ComboBoxRecordType.Text = ''
	$TextBoxRecordName.Enabled = $false
	$TextBoxRecordData.Enabled = $false
	$TextBoxZoneName.Enabled = $true
	$TextBoxDNSFQDN.Enabled = $true	


}

	$RichTextBoxStatus.AppendText("`n")
	$RichTextBoxStatus.AppendText($ComboBoxRecordType.SelectedItem)

}

function RadioButtonDeleteCheckedChanged( $object ) {

reset-FormData
$ComboBoxRecordType.Enabled = $true
$ComboBoxRecordType.Items.Add('A')
$ComboBoxRecordType.Items.Add('CNAME')
$ComboBoxRecordType.Items.Add('PTR')

	switch ($ComboBoxRecordType.SelectedItem) {
	
		'A' {

			reset-FormData
			$ComboBoxRecordType.Enabled = $true
			$TextBoxRecordName.Enabled = $true
			$TextBoxRecordData.Enabled = $false
			$LabelRecordData.Enabled = $false
			$TextBoxRecordData.Text = ''
			$TextBoxZoneName.Enabled = $true
			$TextBoxDNSFQDN.Enabled = $true
			$LabelRecordData.Text = 'IPv4 Address'
			$ButtonExecuteRunbook.Enabled = $true

		}

		'CNAME' {

			reset-FormData
			$TextBoxRecordName.Enabled = $true
			$TextBoxRecordData.Enabled = $true
			$TextBoxZoneName.Enabled = $true
			$TextBoxDNSFQDN.Enabled = $true
			$ButtonExecuteRunbook.Enabled = $true
		}


		'PTR' {

			reset-FormData
			$TextBoxRecordName.Enabled = $true
			$TextBoxRecordData.Enabled = $true
			$TextBoxZoneName.Enabled = $true
			$TextBoxZoneName.Text = ''
			$TextBoxDNSFQDN.Enabled = $true
			$ButtonExecuteRunbook.Enabled = $true

		}

	}


}

function RadioButtonReadCheckedChanged( $object ) {

reset-FormData

$ComboBoxRecordType.Enabled = $false
$ComboBoxRecordType.Items.Clear()
$TextBoxRecordName.Enabled = $false
$TextBoxRecordData.Enabled = $false
$TextBoxZoneName.Enabled = $true
$TextBoxDNSFQDN.Enabled = $true	



}

function ButtonAzureConnectClick {

	param (
		$SubscriptionID
	)

	# Connect to Azure Account

	$LabelIsAzConnected.ForeColor = [System.Drawing.Color]::Black
	$LabelIsAzConnected.Text = "Connecting to Azure. Please wait..."
	Connect-AzAccount
	Select-AzSubscription -SubscriptionId $SubscriptionID
	$azContext = Get-AzContext
	$azUser = $azContext.ExtendedProperties.Account
	$LabelIsAzConnected.Text = "Connected to Azure"
	$LabelIsAzConnected.ForeColor = [System.Drawing.Color]::Green
	

	if ($azContext.Subscription.Id -eq $SubscriptionID) {

		# Enable Radio Buttons
		$RadioButtonRead.Enabled = $true
		$RadioButtonDelete.Enabled = $true
		$RadioButtonCreate.Enabled = $true

		# Disable Connect Button
		$ButtonAzureConnect.Enabled = $false
		$ButtonAzureConnect.Text = "Connected"
	}

}

function reset-FormData {

	$TextBoxRecordName.Enabled = $false
	$TextBoxRecordName.ResetText()
	$TextBoxRecordData.ResetText()
	$TextBoxZoneName.Text = $defaultZoneName
	$TextBoxDNSFQDN.Text = $defaultDNSServerFQDN

	$TextBoxRecordData.Enabled = $false
	$TextBoxZoneName.Enabled = $false
	$TextBoxDNSFQDN.Enabled = $false
	$LabelRecordData.Text = 'RecordData'
	$ComboBoxRecordType.Text = ''
	

}

Main # This call must remain below all other event functions

#endregion
