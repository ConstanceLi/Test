# Written By : Dat K AU DUONG
# Date       : 22/07/2011
#            : Default Parameter = Caseid
#            : Eg: webcaseenquiry:-66780
# Updated    : 
#            : Dat, 04/10/2011
#            :     Use Powershell Credential UI Prompt (Commented call to ShowLogin)
#            : Dat, 09/09/2013
#            :     Add Ability to open Filesite Document (webcaseenquiry:docnum=7555901)
#            :     Add Ability to open IRN               (webcaseenquiry:irn=15096/e)
#            : Dat, 16/09/2013
#            :     Modified the code to default to IRN instead of caseid
#            :     Therefore webcaseenquiry:irn= is nolonger needed and removed.
#            : Dat, 27/11/2014
#            :     Modified the code to check the docnum from (archive) if it is not found.
#            :     Modified exec_sql to use slightly better approach
#            :
#            : Dat, 09/08/2016
#            :     Add Ability to open Filesite Workspace (webcaseenquiry:workspace=6335111)
#            : Dat, 15/02/2018
#            :     Added Worksite Server rather than hardcode, based on Environment Variable OFFICE
#powershell -command Set-ExecutionPolicy RemoteSigned
#Install CERTIFICATE
#Remove FROM Trusted/Intranet Zone
#Remove Tick TO automatically locate LOCAL zone
# NOTE:
# Do not use clear-host in the WebcaseEnquiry, Otherwise it won't launch

#region Common Functions: No Change Require
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$office = 'AJPNZL'
$global:userid = ''
$global:password = ''
$global:userinfo = $null
$global:WorksiteServer=''
$global:WorksiteDatabase=''
$global:ie_hwnd = $null

$waspdll = 'C:\ProgramData\WebCaseEnquiry\WASP.dll'

if ((Test-Path $waspdll) -eq $true) {
	Import-Module $waspdll
}

function msgbox ($title, $text, $type = [Windows.Forms.MessageBoxIcon]::None){
	$msg = [Windows.Forms.MessageBox]::Show($text, $title, [Windows.Forms.MessageBoxButtons]::OK, $type )
}

function GetPsx86Path {
	$PsPath = $PSHOME + "\powershell.exe";
	if((Get-Item env:\Processor_Architecture) -ne "x86")
	{
		#This means you're not in a 32-bit PS.
		$PsPath = ($PsPath -replace "system32","syswow64")
	}
	
	return $PsPath
}

#region Show Login Prompt
#This function is used in the Powershell RunSpace
function ShowLogin(){
	#region Create Form
	$objForm = New-Object System.Windows.Forms.Form 
	$objForm.Text = "Login"
	$objForm.Size = New-Object System.Drawing.Size(300,200) 
	$objForm.StartPosition = "CenterScreen"
	#$objForm.Resize
	#endregion

	#region Form Events
	$objForm.KeyPreview = $True
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Enter") 
	    {$uid=$objTextBoxUID.Text; $upwd=$objTextBoxPWD.Text; $objForm.Close()}})
	$objForm.Add_KeyDown({if ($_.KeyCode -eq "Escape") 
	    {$objForm.Close()}})
	#endregion
	
	#region OK Button
	$OKButton = New-Object System.Windows.Forms.Button
	$OKButton.Location = New-Object System.Drawing.Size(75,120)
	$OKButton.Size = New-Object System.Drawing.Size(75,23)
	$OKButton.Text = "OK"
	$OKButton.Add_Click({$uid=$objTextBoxUID.Text; $upwd=$objTextBoxPWD.Text; $objForm.Close()})
	$objForm.Controls.Add($OKButton)
	#endregion

	#region Cancel Button
	$CancelButton = New-Object System.Windows.Forms.Button
	$CancelButton.Location = New-Object System.Drawing.Size(150,120)
	$CancelButton.Size = New-Object System.Drawing.Size(75,23)
	$CancelButton.Text = "Cancel"
	$CancelButton.Add_Click({$objForm.Close()})
	$objForm.Controls.Add($CancelButton)
	#endregion

	#region Label
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(10,20) 
	$objLabel.Size = New-Object System.Drawing.Size(280,20) 
	$objLabel.Text = "Please enter the information in the space below:"
	$objForm.Controls.Add($objLabel) 
	#endregion

	#region UserID
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(10,43) 
	$objLabel.Size = New-Object System.Drawing.Size(100,20) 
	$objLabel.Text = "User ID:"
	$objForm.Controls.Add($objLabel) 

	$objTextBoxUID = New-Object System.Windows.Forms.TextBox 
	$objTextBoxUID.Location = New-Object System.Drawing.Size(130,40) 
	$objTextBoxUID.Size = New-Object System.Drawing.Size(100,20) 
	$objForm.Controls.Add($objTextBoxUID) 
	#endregion

	#region Password
	$objLabel = New-Object System.Windows.Forms.Label
	$objLabel.Location = New-Object System.Drawing.Size(10,73)
	$objLabel.Size = New-Object System.Drawing.Size(100,20) 	
	$objLabel.Text = "Password:"
	$objForm.Controls.Add($objLabel) 

	$objTextBoxPWD = New-Object System.Windows.Forms.TextBox 
	$objTextBoxPWD.Location = New-Object System.Drawing.Size(130,70)
	$objTextBoxPWD.Size = New-Object System.Drawing.Size(100,20) 
	$objTextBoxPWD.PasswordChar = "*"
	$objForm.Controls.Add($objTextBoxPWD)

	$objForm.Topmost = $True
	#endregion

	#region Show Form
	$objForm.Add_Shown({$objForm.Activate()})
	[void] $objForm.ShowDialog()
	#endregion
	
	#region Store UserID/Password into Global Variable
	$global:userid = $uid
	$global:password = $upwd
	#endregion
	
	#region Take user input and store into Single Login UserID/Password
	$global:userinfo.Login.UserID = $global:userid
	$global:userinfo.Login.Password = $global:password
	#endregion
}

#Prefer to use the following instead of the above function
function getlogin()
{
	$credential = $Host.ui.PromptForCredential("Single Login for Inprotech Web","Please Enter Inprotech Login Id and Password","$env:username","")
	if ($credential -ne $null)
	{
		$global:userid = Split-Path $credential.UserName -Leaf
		$global:password = $credential.GetNetworkCredential().Password
		 		 
		$global:userinfo.Login.UserID = $global:userid
		$global:userinfo.Login.Password = $global:password
	}
}
#endregion

function getloginsession()
{	
	startsinglelogin
	if ($global:userinfo.Login.UserID -eq $null -or $global:userinfo.Login.UserID.Length -le 0) 
	{
		#ShowLogin function work in the Powershell RunSpace
		ShowLogin
		#getlogin
	}
	else {
		# Login Session Exist
		$global:userid = $global:userinfo.Login.UserID
		$global:password = $global:userinfo.Login.Password
	}
}

#single Login
function startsinglelogin()
{
	[reflection.assembly]::LoadWithPartialName("'Microsoft.VisualBasic") | out-null

	# | where-object { $_.ProcessName -eq "SingleLogin" }
	$cmdSingleLogin = $null
	$cmdSingleLogin = Get-Process "SingleLogin" -ErrorAction SilentlyContinue
	if ($cmdSingleLogin -eq $null) {
		$singlelogin_exe = "C:\ProgramData\WebCaseEnquiry\SingleLogin.exe"
		if ((Test-Path ($singlelogin_exe -f '') -eq $true)) {
			& ($singlelogin_exe -f '')
		} else {
			if ((Test-Path ($singlelogin_exe -f ' (x86)') -eq $true)) {
				& ($singlelogin_exe -f ' (x86)')
			}
		}
	
		# & "C:\Program Files\WebCaseEnquiry\SingleLogin.exe"
		do {
			$cmdSingleLogin = Get-Process "SingleLogin" -ErrorAction SilentlyContinue 
			Start-Sleep -Seconds 1
		} while ($cmdSingleLogin -eq $null)
	}

	$global:userinfo = [Microsoft.VisualBasic.Interaction]::GetObject("", "SingleLogin.InfoStore")
}

function exec_sql(){
	param(
		 [Parameter(Mandatory=$true)][string]$sql
		,[Parameter(Mandatory=$false)][string]$server = 'KELSEY'
		,[Parameter(Mandatory=$false)][alias("database")][string]$databasename = 'INPRO'
		,[Parameter(Mandatory=$false)][switch]$selectdata = $true
		,[Parameter(Mandatory=$false)][alias("userid")][string]$uid = ''
		,[Parameter(Mandatory=$false)][alias("password")][string]$pwd = ''
		,[Parameter(Mandatory=$false)][alias("caller")][string]$ApplicationName = 'WebcaseEnquiry'
		,[Parameter(Mandatory=$false)][alias("taskname")][string]$sql_taskname = ''
	)
	[System.Diagnostics.Debug]::WriteLine("Execute Query:" + $sql_taskname)
	

	$sqlConnection = new-object System.Data.SqlClient.SqlConnection
	if ($uid.Trim().Length -gt 0) {
		$sqlConnection.ConnectionString = "server=$server;database=$databasename;User ID=$uid;Password=$pwd;Application Name=$ApplicationName;"
	} else {
		$sqlConnection.ConnectionString = "Data Source=$server;Initial Catalog=$databasename;Integrated Security=SSPI;Application Name=$ApplicationName"
	}
	$sqlConnection.Open()
	
	$sqlCommand = new-object System.Data.SqlClient.SqlCommand 
	$sqlCommand.CommandTimeout = 600 
	$sqlCommand.Connection = $sqlConnection 
	$sqlCommand.CommandText= $sql
	
	if ($selectdata) {
		$sqlDataAdapter = new-object System.Data.SqlClient.SQLDataAdapter($sqlCommand) 
		$sqlDataSet = new-object System.Data.dataset 
		$sqlDataAdapter.fill($sqlDataSet) | out-null # move data into dataset
		$result = $sqlDataSet.Tables[0].select()
	} else {
		$result = $sqlCommand.ExecuteNonQuery()
	}
	
	$sqlConnection.Close()
	
	return $result
}
#endregion

function InitializeWorksiteDetails()
{
	$global:WorksiteServer = "Galloway"
	$global:WorksiteDatabase = "Wellington"
}

function LoginToInprotechWeb(){
	param($ie)	
	$login_success = $true
	$inproweb_url = 'http://inpro/cpainpro/'
		
	#$ie.ToolBar = 1
	$ie.StatusBar = 0
	$ie.navigate($inproweb_url)
	#$ie.maximize = $true
$sw = @'
[DllImport("user32.dll")]
public static extern int ShowWindow(int hwnd, int nCmdShow);
'@

	$type = Add-Type -Name ShowWindow2 -MemberDefinition $sw -Language CSharpVersion3 -Namespace Utils -PassThru

	# 3 = maximize 
	$type::ShowWindow($ie.hwnd, 3) | Out-Null

	$ie.visible = $true
	while($ie.ReadyState -ne 4 -or $doc -eq $null){ 
		Start-Sleep 1
		$doc = $ie.document
	}
	#$ie | get-member | more

	$uid = $null
	IF ($doc -ne $null) {
		[System.Diagnostics.Debug]::WriteLine("OpenCase: Looking for SigninButton")
		$login=$doc.getElementByID("signInButton")
		$bodytext = $($doc.Body.InnerText)
		while($bodytext.Contains("Logout") -eq $false -and ($login -eq $null -or $ie.ReadyState -ne 4)){ 
			Start-Sleep 1
			$doc = $ie.document			
			$login=$doc.getElementByID("signInButton")
			$bodytext = $($doc.Body.InnerText)
		}
		
		$uid = $doc.getElementByID("ctl00_ContentPlaceHolder_txtUserLoginId")
		$pwd = $doc.getElementByID("ctl00_ContentPlaceHolder_txtPassword")	
	}
	
	if ($uid -ne $null) {
		$uid.value = $global:userinfo.Login.UserID
		$pwd.value = $global:userinfo.Login.Password
	}

	[System.Diagnostics.Debug]::WriteLine("OpenCase: Attempt to login")
	IF ($login -ne $null) {
		[System.Diagnostics.Debug]::WriteLine("OpenCase: I am Clicking on Login Button")
		$login.click()
	}
	
	[System.Diagnostics.Debug]::WriteLine("OpenCase: Wait for Login to be complete")
	while($ie.ReadyState -ne 4 -or $doc -eq $null){ 
		Start-Sleep 1
		$doc = $ie.document
	}
	
	while(($doc -ne $null -and $doc.innerText -ne $null -and $doc.innerText.Contains("Welcome") -eq $false) -and ($doc -ne $null -and $doc.innerText.Contains("Login Failed - please retry.") -eq $false)){ 
		Start-Sleep 1
		$doc = $ie.document
	}
	
	[System.Diagnostics.Debug]::WriteLine("OpenCase: Doc InnerText")
	if ($doc -eq $null -or ($doc -ne $null -and $doc.innerText -ne $null -and $doc.innerText.Contains("Login Failed - please retry."))) {
		$login_success = $false
	}
	[System.Diagnostics.Debug]::WriteLine("OpenCase: Login Success")
	return $login_success
}

#function LoginToInprotechWeb(){
#	param($ie)
#	
#	$login_success = $true
#		
#	$ie.ToolBar = 1
#	$ie.StatusBar = 0
#	$ie.navigate("http://inpro/cpainpro/")
#	#$ie.maximize = $true
#$sw = @'
#[DllImport("user32.dll")]
#public static extern int ShowWindow(int hwnd, int nCmdShow);
#'@
#
#	$type = Add-Type -Name ShowWindow2 -MemberDefinition $sw -Language CSharpVersion3 -Namespace Utils -PassThru
#
#	# 3 = maximize 
#	$type::ShowWindow($ie.hwnd, 3) | Out-Null
#
#	$ie.visible = $true
#	while($ie.ReadyState -ne 4 -or $doc -eq $null){ 
#		Start-Sleep 1
#		$doc = $ie.document
#	}
#	#$ie | get-member | more
#
#	$uid = $null
#	IF ($doc -ne $null) {
#		$login=$doc.getElementByID("signInButton")
#		$uid = $doc.getElementByID("ctl00_ContentPlaceHolder_txtUserLoginId")
#		$pwd = $doc.getElementByID("ctl00_ContentPlaceHolder_txtPassword")	
#	}
#
#	$uid.value = $global:userinfo.Login.UserID
#	$pwd.value = $global:userinfo.Login.Password
#
#
#	IF ($login -ne $null) {
#		$login.click()
#	}
#	
#	while($ie.ReadyState -ne 4 -or $doc -eq $null){ 
#		Start-Sleep 1
#		$doc = $ie.document
#	}
#	
#	if ($doc.innerText.Contains("Login Failed - please retry.")) {
#		$login_success = $false
#	}
#	
#	return $login_success
#}

function main(){
	param($ie)
	
	#Has user login (if not show login prompt)
	getloginsession

	if ($ie -eq $null) {	
		$ie = new-object -com "InternetExplorer.Application"
		$global:ie_hwnd = $ie.hwnd
		
		$oShell = new-object -com "Shell.Application"
		$oShell.Windows | % {
			If ($_.hwnd -eq $global:ie_hwnd) {
				$ie = $_
			}
		}
	}
	
	if ((LoginToInprotechWeb $ie) -eq $false)
	{
		[System.Diagnostics.Debug]::WriteLine("OpenCase: before main|quit")
		$ie.Quit()
		$global:userinfo.Login.UserID = ""
		$global:userinfo.Login.Password = ""
	}
	
	[System.Diagnostics.Debug]::WriteLine("OpenCase: main")
	
	return $ie
}

#$ieSet = (New-Object -ComObject Shell.Application).Windows() | ? {	$_.LocationUrl -like '*inpro*' }
#$ieloggedin = $false
#if ($ieSet -ne $null) {
#	$ieSet | % {
#		$url = $_.LocationUrl
#		$name = $_.LocationName
#		$bodytext = $($_.Document.Body.InnerText)
#	 
#		if ($bodytext -ne $null) {
#			if ($bodytext -match "Please\senter\syour\slogin\sID\sand\spassword") {
#				# Not Loggedin
#			} else {		
#				# Logged In
#				$_.Navigate2("http://inpro/CPAInpro/Desktop/ModuleDefault.aspx?LoadRequest=Case/Case&CaseKey=-66780&AccessMode=0", $navOpenNewForegroundTab)
#			}
#		}
#	}	
#}

function CloseAnExistingInprotechQuery(){
	$ieSet = $null
	try {
		$App = (New-Object -ComObject Shell.Application).Windows()
		Start-Sleep 1
		$ieSet = $App | ? {	$_.LocationUrl -like '*inpro*' }
		$existingquery = $false
		if ($ieSet -ne $null) {
			$existing_ie = $null
			$existing_ie_loggedin = $false
			$ieSet | % {
				$url = $_.LocationUrl
				$name = $_.LocationName
				$bodytext = $($_.Document.Body.InnerText)			
				if ($bodytext -ne $null) {
					if ($url -match '\?CaseKey') {
						$child_window = Set-WindowActive $_.HWND
						Start-Sleep -Seconds 1
						$child_window | Send-Keys "^{F4}"
						
						$existingquery = $true					
					}
				}
			}
		}
	}
	catch [System.Exception] {
		Write-Host $_.Exception.ToString()
	}
	
	$ieSet = $null
	return $existingquery
}

function MinimizeAllExceptIE()
{
	$sig = '[DllImport("user32.dll")] public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);'
	Add-Type -MemberDefinition $sig -name NativeMethods -namespace Win32

	Get-Process | % {
		if ($_.ProcessName -eq 'iexplore') {
			$hwnd = $_.MainWindowHandle
			# 4 = Restore window
			[Win32.NativeMethods]::ShowWindowAsync($hwnd, 1) | Out-Null
			#Start-Sleep 1
		}
#		else {
#			if ($_.ProcessName -notmatch "Receiver|SingleLogin|picaShell|picaTWIHost|RocketDock|mmvdhost|PicaSessionMgr|picaDispMgr|rundll32") {
#				$hwnd = $_.MainWindowHandle
#				# 2 = Minimize window
#				[Win32.NativeMethods]::ShowWindowAsync($hwnd, 2) | Out-Null
#			}
#		}
	}
	
#		"Hide"               {$WinStateInt =  0}
#        "Normal"             {$WinStateInt =  1}
#        "ShowMinimized"      {$WinStateInt =  2}
#        "Maximize"           {$WinStateInt =  3}
#        "ShowNoActivate"     {$WinStateInt =  4}
#        "Show"               {$WinStateInt =  5}
#        "Minimize"           {$WinStateInt =  6}
#        "ShowMinNoActive"    {$WinStateInt =  7}
#        "ShowNA"             {$WinStateInt =  8}
#        "Restore"            {$WinStateInt =  9}
#        "ShowDefault"        {$WinStateInt = 10}
#        "ForceMinimize"      {$WinStateInt = 11}	
}

#Out: IE or NULL
function FindAnExistingInprotechSession(){
	$ieSet = (New-Object -ComObject Shell.Application).Windows() | ? {	$_.LocationUrl -like '*inpro*' }
	if ($ieSet -ne $null) {
		$existing_ie = $null
		$existing_ie_loggedin = $false
		$ieSet | % {
			$url = $_.LocationUrl
			$name = $_.LocationName
			$bodytext = $($_.Document.Body.InnerText)			
			if ($bodytext -ne $null) {
				# Set-WindowActive $_.HWND
				if ($bodytext -match "Please\senter\syour\slogin\sID\sand\spassword") {
					$existing_ie_loggedin = $existing_ie_loggedin -bor $false
					if ($existing_ie_loggedin -eq $false) {
						$existing_ie = $_
					}
				} else {					
					$existing_ie = $_
					$existing_ie_loggedin = $existing_ie_loggedin -bor $true
				}
			}
			return $existing_ie
		}	
	} else {
		return $ieSet
	}
}

#Out: IE or NULL
function FindIE()
{
	$loggedin = $true
	$existingquery = CloseAnExistingInprotechQuery
	if ($existingquery -eq $false) {
		$ie = FindAnExistingInprotechSession
		if ($ie -ne $null) {
			# Already Logged In
			$bodytext = $($ie.Document.Body.InnerText)						
			if ($bodytext -ne $null) {
				# Set-WindowActive $_.HWND
				if ($bodytext -match "Please\senter\syour\slogin\sID\sand\spassword") {
					$loggedin = $false
				}
			}			
		} else {
			$loggedin = $false
		}
		
		if ($loggedin -eq $false) {
			[System.Diagnostics.Debug]::WriteLine("OpenCase: I am here login")
			$ie = main $ie
			if ($ie -eq $null) {
				[System.Diagnostics.Debug]::WriteLine("OpenCase: I null")
			} else {
				[System.Diagnostics.Debug]::WriteLine("OpenCase: I am not null")
			}		
		}
		
		return $ie
	} else {
		return $null
	}
}

function OpenCaseWindow(){
	param($irn)
	
	$navOpenInNewWindow = 1
	$navOpenNewForegroundTab = 65536
	$navOpenInNewTab = 0x10000
	#$caseurl = "http://inpro/CPAInpro/Desktop/ModuleDefault.aspx?LoadRequest=Case/Case&CaseKey={0}&AccessMode=0" -f $caseid
	$caseurl = "http://inpro/CPAInpro/?CaseKey={0}" -f $irn
	$CaseWindowOpened = $false
	#Write-Host $caseurl

	$ie = FindIE
	if ($ie -ne $null) {
		$ie.Navigate2($caseurl,$navOpenNewForegroundTab) # http://inpro/CPAInpro/?CaseKey=15096/e

		Select-Window -Title "Inprotech - Windows*" | Set-WindowActive | Out-Null
		$CaseWindowOpened = $true
	} else {
		$CaseWindowOpened = $false
	}
	
	return $CaseWindowOpened
}

function WebCaseEnquiry(){
	param($irn)
	
	$msgtype = [Windows.Forms.MessageBoxIcon]::Information

	$SuccesfullyOpenCaseWindowOpened = OpenCaseWindow $irn
	if ($SuccesfullyOpenCaseWindowOpened -eq $false) {
		# Attempt 2
		$SuccesfullyOpenCaseWindowOpened = OpenCaseWindow $irn
	}
	
	MinimizeAllExceptIE
}

function createnrl(){
	param($docnum)
	[System.Diagnostics.Debug]::WriteLine("Createnrl Called")
	#$docnum = checkdocnum $docnum
	[System.Diagnostics.Debug]::WriteLine("Docnum: " + $docnum)
	$outfile = ''
	if ($docnum -ne $null -and $docnum.Length -gt 0) {
		$outfile = "c:\log\$docnum.nrl"
		
		# Force the lineResults to Unix format and save to a file
		$streamWriter = New-Object System.IO.StreamWriter($outfile, $false)
		$docver = 1
		$doclatest = "`n[Version]`nLatest=Y"
		if ($docnum.Contains('.')) 
		{
			$docver = $docnum.split('.')[1]
			$docnum = $docnum.split('.')[0]
			$doclatest = ''
		}
		
		[System.Diagnostics.Debug]::WriteLine($global:WorksiteServer + "!nrtdms:0:!session:" + $global:WorksiteServer + ":!database:" + $global:WorksiteDatabase + ":!document:$docnum," + $docver + ":")
		$streamWriter.Write($global:WorksiteServer + "`n!nrtdms:0:!session:" + $global:WorksiteServer + ":!database:" + $global:WorksiteDatabase + ":!document:$docnum," + $docver + ":")
		$streamWriter.Flush()
		$streamWriter.Close()
	}
	
	return $($outfile)
}

function createworkspacenrl(){
    param($itemno)
	[System.Diagnostics.Debug]::WriteLine("Create workspace nrl Called")	
	[System.Diagnostics.Debug]::WriteLine("$itemno")

    $outfile = ''
	if ($itemno -ne $null -and $itemno.Length -gt 0) {
		$outfile = "c:\log\wsopen.nrl"
    
        # Force the lineResults to Unix format and save to a file
		$streamWriter = New-Object System.IO.StreamWriter($outfile, $false)
		$streamWriter.Write($global:WorksiteServer + "`n!nrtdms:0:!session:" + $global:WorksiteServer + ":!database:" + $global:WorksiteServer + ":!page:{0}:" -f $itemno)
		$streamWriter.Flush()
		$streamWriter.Close()
	}
	
	return $($outfile)
}

function createefilenrl(){
    param($itemno)
	[System.Diagnostics.Debug]::WriteLine("Create efile nrl Called")	
	[System.Diagnostics.Debug]::WriteLine("$itemno")

    $outfile = ''
	if ($itemno -ne $null -and $itemno.Length -gt 0) {
		$outfile = "c:\log\wsopen.nrl"
    
        # Force the lineResults to Unix format and save to a file
		$streamWriter = New-Object System.IO.StreamWriter($outfile, $false)
		$streamWriter.Write($global:WorksiteServer + "`n!nrtdms:0:!session:" + $global:WorksiteServer + ":!database:" + $global:WorksiteDatabase + ":!DocumentSearchFolder:{0}:" -f $itemno)
		$streamWriter.Flush()
		$streamWriter.Close()
	}
	
	return $($outfile)
}


function checkdocnum()
{
	param($docnum)

	# [System.Diagnostics.Debug]::WriteLine("Checkdocnum Called")

	# $archivesql = "
	# with tbl as (
		# select distinct docnum, msg_id, t_alias, C_ALIAS
		# from (
			# select docnum, msg_id, t_alias, C_ALIAS
			# from SAFWEB1.[Archive].[dbo].[DuplicateEmailMarkAsDelete_20141124] d1
			# union all
			# select docnum, msg_id, t_alias, C_ALIAS
			# from SAFWEB1.[Archive].[dbo].[DuplicateEmailMarkAsDelete_20141125] d2
			# union all
			# select docnum, msg_id, t_alias, C_ALIAS
			# from SAFWEB1.[Archive].[dbo].[DuplicateEmailMarkAsDelete_20141126] d3
		# ) d1
		# where T_ALIAS = 'MIME'
		# AND C_ALIAS = 'E-MAIL'
	# )

	# SELECT [DOCNUM]=dm.DOCNUM
	# FROM SAFWEB1.SAF.MHGROUP.DOCMASTER dm
	# join tbl d on (d.MSG_ID = dm.MSG_ID and d.t_alias = dm.t_alias and d.c_alias = dm.C_ALIAS)
	# WHERE d.DOCNUM = '{0}'"

	# $livesql = "select distinct dm.docnum from safweb1.saf.mhgroup.docmaster dm where dm.docnum = '{0}'"
	# $archiveupdatesql = "select [docnum]=dm.Old from SAFWEB1.ARCHIVE.dbo.DuplicateEmailUpdate2_20141127_Summary dm where  dm.New = '{0}'"	
	# $result = exec_sql -sql ($livesql -f $docnum) -sql_taskname 'livesql'
	# [System.Diagnostics.Debug]::WriteLine("Looking for $docnum, Found Docnum: " + ($result.docnum -ne $null))
	# #Read-Host -Prompt "Press Enter to continue"

	# if ($result -eq $null) {
		# $result = $null
		# #Remove-Variable result
		# $result = exec_sql -sql ($archivesql -f $docnum) -sql_taskname 'archivesql'
		
		# if ($result.docnum -eq $null) {
			# $result = $null
			# #Remove-Variable result
			# $result = exec_sql -sql ($archiveupdatesql -f $docnum) -sql_taskname 'archiveupdatesql'
			# [System.Diagnostics.Debug]::WriteLine("Looking for $docnum, Found Docnum: " + ($result.docnum -ne $null))
		# }
	# } else {
		# [System.Diagnostics.Debug]::WriteLine("Found Docnum " + $result.docnum.ToString())	
	# }
		
	# return $result.docnum.ToString()
	return $null
}

function opendms_doc() {
	param($docnum)
	if ((Test-Path $docnum)) {
		[System.Diagnostics.Debug]::WriteLine("Launch $docnum")
		Start-Process $docnum
	} else {		
		$outfile = createnrl $docnum
		[System.Diagnostics.Debug]::WriteLine("Created NRL File: " + $outfile)
		if ($outfile.Length -gt 0) {
			Start-Process $outfile
			Start-Sleep -Seconds 3
		}
		#Remove-Item $outfile
	}
}

function WaitAnimationPage()
{
$html = '<!doctype html>
<html>
<head>
	<title>Extracting KEEP ON TOP</title>
<style>
.glyphicon-refresh-animate {
    -animation: spin .9s infinite linear;
    -ms-animation: spin .9s infinite linear;
    -webkit-animation: spinw .9s infinite linear;
    -moz-animation: spinm .9s infinite linear;
}

@keyframes spin {
    from { transform: scale(3) rotate(0deg);}
    to { transform: scale(3) rotate(360deg);}
}

@-webkit-keyframes spinw {
    from { -webkit-transform: rotate(0deg);}
    to { -webkit-transform: rotate(360deg);}
}

@-moz-keyframes spinm {
    from { -moz-transform: rotate(0deg);}
    to { -moz-transform: rotate(360deg);}

}

.container {
	min-width: 300px;	
}

div.Animation {
    width: 200px;
    height: 200px;

    position: absolute;
    top:0;
    bottom: 0;
    left: 0;
    right: 0;

    margin: auto;
}
	</style>


	<!-- Latest compiled and minified CSS -->
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css">

	<!-- Optional theme -->
	<link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap-theme.min.css">

</head>
<body>
<div class="Animation">
	<center>
		<h2>Working... </h2>
	</center>
	<center>
		<span class="glyphicon glyphicon-repeat glyphicon-refresh-animate" style="color:orange"></span>
	</center>
</div>
	<!-- Latest compiled and minified JavaScript -->
	<!-- <script src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/js/bootstrap.min.js"></script>-->
</body>
</html>'

return $html
}

function IEPositionBottomRightHand()
{
	param($ie)
	
	if ($ie -ne $null) {
		$desktopWorkingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea.Height
		$left = $desktopWorkingArea.Right + 780 - 5
		$top = $desktopWorkingArea.Bottom + 640 - 5
		
		$ie.ToolBar = $false	
		$ie.width = 780; 
		$ie.height = 640; 
		$ie.Left = $left
		$ie.top = $top
		$ie.visible = $true
	}
}

function ReAttachIESession()
{
	param($ie)
	
	[System.Diagnostics.Debug]::WriteLine('Looking for IE')
	$ShellWindows = (New-Object -ComObject Shell.Application).Windows() 
	$IEObjs = @()

	Foreach($IEProcess in $ShellWindows) 
	{ 
		$FullName = $IEProcess.FullName 
		If($FullName -ne $NULL) 
		{ 
			$FileName = Split-Path -Path $FullName -Leaf 

			If($FileName.ToLower() -eq "iexplore.exe") 
			{
				$Title = $IEProcess.LocationName
				$URL = $IEProcess.LocationURL
                $IE = $IEProcess
				$IEObj = New-Object -TypeName PSObject -Property @{Title = $Title; URL = $URL; Session = $IEProcess}
				$IEObjs += $IEObj

                [System.Diagnostics.Debug]::WriteLine('Found Session: ' + $URL)
                if ($IEProcess -eq $null) {
                    [System.Diagnostics.Debug]::WriteLine('Not Normal: session is empty')
                }
			} 
		} 
	}

	[System.Diagnostics.Debug]::WriteLine('Identified Internet Explorer Process')
	try {
		if ($IEObjs -ne $null) {
			# Write-Host 'Found IE Session'
			[System.Diagnostics.Debug]::WriteLine('Found IE Session and Attempt to Re-Attach');
			#$ie = $IEObjs.session
            if ($ie -eq $null) { [System.Diagnostics.Debug]::WriteLine('Re-Attach Failed!'); }
			$global:ie_hwnd = $ie.hwnd
		} else {
			# Write-Host 'Create New Session'
			[System.Diagnostics.Debug]::WriteLine('Create New Session');
			$ie = new-object -com "InternetExplorer.Application"
			$global:ie_hwnd = $ie.hwnd
		}
	} catch {
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			[System.Diagnostics.Debug]::WriteLine($ErrorMessage)
	}
	
	return $ie
}

function ConnectIExplorer() {
    param($HWND)

	$objShellApp = New-Object -ComObject Shell.Application 
	try {
	  $EA = $ErrorActionPreference; $ErrorActionPreference = 'Stop'
	  $objNewIE = $objShellApp.Windows() | ?{$_.HWND -eq $HWND}
	  $objNewIE.Visible = $true
	} catch {
	  #it may happen, that the Shell.Application does not find the window in a timely-manner, therefore quick-sleep and try again
	  Write-Host "Waiting for page to be loaded ..." 
	  Start-Sleep -Milliseconds 500
	  try {
		$objNewIE = $objShellApp.Windows() | ?{$_.HWND -eq $HWND}
		$objNewIE.Visible = $true
	  } catch {
		Write-Host "Could not retreive the -com Object InternetExplorer. Aborting." -ForegroundColor Red
		$objNewIE = $null
	  }     
	} finally { 
	  $ErrorActionPreference = $EA
	  $objShellApp = $null
	}
	return $objNewIE
}

function kot()
{
   
	param($irn)
  
	if ($ie -eq $null) {
		$ie = ReAttachIESession $ie
		#[System.Diagnostics.Debug]::WriteLine('IE Session: ' + $global:ie_hwnd);
		
		[System.Diagnostics.Debug]::WriteLine('Position IE to the bottom right hand corner')
		IEPositionBottomRightHand $ie
	}
	


	WaitAnimationPage | Out-File 'c:\log\kot1.html'
   
	$ie.Navigate('c:\log\kot1.html')

	#while($ie.busy) {sleep 1}

<#
$sql_findkot_boc = "
declare @input varchar(30)

select @input = '{0}' -- '623669' --'les laboratories' --'408123' --'844453' --'2817351'
SELECT [EntityCode]='AJPNZL',TYPE = 'PORTFOLIO'
                   , DM.DOCNAME
                   , [DOCNUM] = dm.DOCNUM
                   , DM.VERSION
                   , DM.FILEENTRYWHEN
                   , DM.FILEEDITWHEN
                   , DM.OPERATOR
                   , DM.AUTHOR
                   , [CLIENTNAMECODE] = '' --kot.clientnamecode
                   , [Latest Version] =
                        RANK ()
                        OVER ( /* Group the Docnum */
                              PARTITION BY dm.docnum
                              ORDER BY dm.version DESC)
from Wellington.MHGROUP.PROJECTs WORKSPACE
JOIN Wellington.MHGROUP.PROJECT_items DOCINWORKSPACE ON (DOCINWORKSPACE.PRJ_ID = WORKSPACE.PRJ_ID)
JOIN Wellington.MHGROUP.DOCMASTER dm on (DM.docnum = DOCINWORKSPACE.item_id) 
WHERE 1=1
-- and dm.docnum = '2817351' -- '844453' --'2074935'
and ITEM_ID IS NOT NULL
AND dm.c_alias = 'CLIENT'
AND dm.SUBCLASS_ALIAS = 'SPECIAL_INSTRUCTIONS'
AND (
	workspace.prj_name like '%SI%' or
	workspace.prj_name = 'Documents'
)
and DM.VERSION = (select max(version) from Wellington.MHGROUP.DOCMASTER dm_ver where dm_ver.docnum = dm.docnum)
and 
(
    DM.C1ALIAS = @input
    or exists 
    (
        SELECT NI.NAMECODE
        FROM inpro..CASES C
        LEFT OUTER JOIN inpro..CASENAME CNI ON (CNI.CASEID = C.CASEID AND CNI.NAMETYPE = 'I')
        LEFT OUTER JOIN inpro..CASENAME CNR ON (CNR.CASEID = C.CASEID AND CNR.NAMETYPE = 'R')
        LEFT OUTER JOIN inpro..NAME NI ON (NI.NAMENO = CNI.NAMENO)
        LEFT OUTER JOIN inpro..NAME NR ON (NR.NAMENO = CNR.NAMENO)
        WHERE 1=1
        AND C.IRN = @input
        AND (NI.NAMECODE = DM.C1ALIAS or NR.NAMECODE = DM.C1ALIAS)
    )
    or exists (
        select *
        from inpro..name n
        where 1=1
        and n.name like '%'+ @input + '%'
    )
)
order by FILEEDITWHEN desc
"
#>

$sql_findkot_boc = "exec dbo.ENTITY_KOT 'AJPNZL', '{0}'"
$result = exec_sql -sql ($sql_findkot_boc -f $irn) -sql_taskname 'livesql'
$result_docnum = $result | ? { $_.Type -eq 'CASE' } | % {
$code = '
	<div class="list-group">
		  <a href="webcaseenquiry:docnum={0}.{1}" class="list-group-item info">
			<h4 class="list-group-item-heading">Docnum: {0} v{1}</h4>
			<p class="list-group-item-text">Last Updated: {5}</p>
			<p class="list-group-item-text">{2}</p>
			<p class="list-group-item-text">Author: {3}, Operator: {4}</p>
		  </a>
	</div>
' -f $_.docnum, $_.version, ($_.Type + ' ' + $_.docname), $_.author, $_.operator, $_.FileEditWhen
$code
}	
	if ($result_docnum -ne $null) {		
		$docnum_html = '<div class="panel panel-primary"><div class="panel-heading">CASE</div>' + ($result_docnum -join "`r`n").ToString() + "</div>`r`n"
	}

$result_docnum = $result | ? { $_.Type -eq 'PORTFOLIO' } | % {
$code = '
	<div class="list-group">
		  <a href="webcaseenquiry:docnum={0}.{1}" class="list-group-item info">
			<h4 class="list-group-item-heading">Docnum: {0} v{1}</h4>
			<p class="list-group-item-text">Last Updated: {5}</p>
			<p class="list-group-item-text">{2}</p>
			<p class="list-group-item-text">Author: {3}, Operator: {4}</p>
		  </a>
	</div>
' -f $_.docnum, $_.version, ($_.Type + ' ' + $_.docname), $_.author, $_.operator, $_.FileEditWhen
$code
}	
	if ($result_docnum -ne $null) {
		$docnum_html += '<div class="panel panel-primary"><div class="panel-heading">PORTFOLIO</div>' + ($result_docnum -join "`r`n").ToString() + "</div>`r`n"
	}

	if ($docnum_html -eq $null) {
		#$docnum_html = ("<h2>CAN'T FIND KEEP ON TOP FOR IRN: <font color=""red""><u>{0}</u></font></h2><br/><h4>Note: Document description must contain Word: KOT</h4>" -f $irn)
		$docnum_html = '<div class="panel panel-danger"><div class="panel-heading">CAN''T FIND KEEP ON TOP FOR IRN</div><div class="panel-body"><font color="red"><h2><u>' + $irn + '</u></font></h2><br/><h4>No Special Instructions exist for that Case number</h4>'
	}
	
	$kot_html = Get-Content 'C:\ProgramData\WebCaseEnquiry\kot.html'
	if ((Test-Path 'c:\log\kot1.html') -eq $true) {
		Remove-Item 'c:\log\kot1.html' -Force
	}
	($kot_html -replace '{KOT_DOCNUM}', $docnum_html) -replace '{irn}', $irn | Out-File 'c:\log\kot1.html' -Force

	if ((Test-Path 'c:\log\kot1.html') -eq $true) {

		try {
			[System.Diagnostics.Debug]::WriteLine('Reload KOT: ' + $global:ie_hwnd);
            $ie = ReAttachIESession $ie

            if ($ie -ne $null) {
			    #ConnectIExplorer -HWND $global:ie_hwnd
			    $ie.Navigate('c:\log\kot1.html')
	            IEPositionBottomRightHand $ie

            } else {
                [System.Diagnostics.Debug]::WriteLine('Reload c:\log\kot1.html Aborted!')
            }
		} catch {
			$ErrorMessage = $_.Exception.Message
			$FailedItem = $_.Exception.ItemName
			[System.Diagnostics.Debug]::WriteLine($ErrorMessage)
		}
	}
}

Function maxIE
{
	param($ie)
	$asm = [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")

    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $ie.Width = $screen.width
    $ie.Height =$screen.height
    $ie.Top =  0
    $ie.Left = 0
}

function forms()
{
	param($filename)
	
	if ((Test-Path $filename) -eq $true) {
		Get-Process | ? { $_.Name -eq 'iexplore' } | % {
			while (!$_.HasExited){
				$_.Kill()
				$_.WaitForExit()
			}
		}	
	
		[System.Diagnostics.Debug]::WriteLine('Recordal Form file exists!')
		if ($ie -eq $null) {
			try {
				[System.Diagnostics.Debug]::WriteLine('Create new browser session')
				$ie = new-object -com "InternetExplorer.Application" -ErrorAction SilentlyContinue
				[System.Diagnostics.Debug]::WriteLine('Browser session created!')
			} catch {
				$ErrorMessage = $_.Exception.Message
				$FailedItem = $_.Exception.ItemName
				[System.Diagnostics.Debug]::WriteLine($ErrorMessage)
			}
			# maxIE $ie
			while ($ie -ne $null -and $ie.busy) {
				sleep -milliseconds 10
				[System.Diagnostics.Debug]::WriteLine('forms() - New IE Wake up from waiting...')
			}
			
			$ie.ToolBar = $false
			$ie.visible = $true
		}
		
		[System.Diagnostics.Debug]::WriteLine('Navigate to form')		
		$ie.navigate($filename)
		if ($filename -match 'rollover.html') {
			IEPositionBottomRightHand $ie
		}
		[System.Diagnostics.Debug]::WriteLine('Navigated!')
	}
}

# webcaseenquiry:-66780
if ($args.Count -gt 0) {
	InitializeWorksiteDetails
	$forms_folder = '\\inf-fil01-iph-1\templates\LIVE\PortableApp\Forms'
	$temp_folder = 'c:\log'

	#-116578, 509/RP
	#-66780, 15096/E
	#$userinput = 'webcaseenquiry:1184' 
    $userinput = $args[0]
	$userinput = ($userinput -replace "WebCaseEnquiry:","" ) -replace "webcaseenquiry:",""    
	if ($userinput.ToLower().Contains("docnum=") -or $userinput.ToLower().Contains("workspace=") -or $userinput.ToLower().Contains("efile=")) {
        if ($userinput.ToLower().Contains("docnum=")) {
            $docnum = ($userinput.split('=')[1]).Trim()
            opendms_doc $docnum
        } else {
			if ($userinput.ToLower().Contains("workspace=")) {
	            $itemno = ($userinput.split('=')[1]).Trim()
	            $outfile = createworkspacenrl $itemno
			    [System.Diagnostics.Debug]::WriteLine($outfile)
	            if ($outfile.Length -gt 0) {
	                Start-Process $outfile
	                Start-Sleep -Seconds 3
	            }
			} else {
				$itemno = ($userinput.split('=')[1]).Trim()
	            $outfile = createefilenrl $itemno
			    [System.Diagnostics.Debug]::WriteLine($outfile)
	            if ($outfile.Length -gt 0) {
	                Start-Process $outfile
	                Start-Sleep -Seconds 3
	            }
			}
        }
	} else {		
		if ($userinput -ne $null -and $userinput.Length -gt 0) {
			switch ($userinput.ToLower())
			{
				"recordal" {				
					[System.Diagnostics.Debug]::WriteLine('Recordal Form')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\NewRecordalCase.html"															
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\recordal.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Recordal Form - Created')
					forms 'c:\log\recordal.html'
				}
				"name" {
					[System.Diagnostics.Debug]::WriteLine('Client Name Notification Form')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\NewClientName.html"															
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\newclientname.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Client Name Notification Form - Created')
					forms 'c:\log\newclientname.html'
				}
				"general" {
					[System.Diagnostics.Debug]::WriteLine('Request to Create New General File')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\NewGeneralFile.html"														
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\newgeneralfile.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Request to Create New General File - Created')
					forms 'c:\log\newgeneralfile.html'
				}
				"info" {
					[System.Diagnostics.Debug]::WriteLine('Australian Patent Design Information Sheet Form')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\AUPat-DesInfoSheet.html"															
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\austpatdesinfosheet.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Australian Patent Design Information Sheet Form - Created')
					forms 'c:\log\austpatdesinfosheet.html'
				}
				"comm" {
					[System.Diagnostics.Debug]::WriteLine('Client Communication Requirements Form')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\ClientCommunicationRequirements.html"
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\comm.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Client Communication Requirements Form - Created')
					forms 'c:\log\comm.html'
				}
				"rollover" {
					[System.Diagnostics.Debug]::WriteLine('Hyperion Month End Account Roll Over')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\rollover.html"
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\rollover.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Hyperion Month End Account Roll Over - Created')
					forms 'c:\log\rollover.html'
				}	
				"serveraddform" {
					[System.Diagnostics.Debug]::WriteLine('Server Add Form')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\serveraddform.html"
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\serveraddform.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Server Add Form - Created')
					forms 'c:\log\serveraddform.html'
				}
				"empdeleteform" {
					[System.Diagnostics.Debug]::WriteLine('Employee Delete Form')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\empdeleteform.html"
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\empdeleteform.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Employee Delete Form - Created')
					forms 'c:\log\empdeleteform.html'
				}
				"empaddform" {
					[System.Diagnostics.Debug]::WriteLine('Employee Add Form')
					$hostname = $env:COMPUTERNAME
					$uid = ($env:USERNAME).ToLower()
					$data = get-content "$forms_folder\empaddform.html"
					$result = ($data -join "`r`n").ToString().replace('{hostname}',$hostname).replace('{uid}',$uid)
					$result | Out-File "$temp_folder\empaddform.html" -Force
					
					[System.Diagnostics.Debug]::WriteLine('Employee Add Form - Created')
					forms 'c:\log\empaddform.html'
				}
				default {
					# WebCaseEnquiry $userinput
					# get-process iexplore | Stop-Process
					
					[System.Diagnostics.Debug]::WriteLine('Execute KOT ' + $userinput)
					kot $userinput
				}
			}
		}
	}
}

#OpenCaseWindow -66780
#FindIE