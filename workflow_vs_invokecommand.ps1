#Basic workflow example to pull hostname of system involved
Workflow basicWorkflow
{
    Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name
}

#Gather objects to run workflow against.  AD is super useful for group managing devices with workflows and invoke-command
$computers = ((Get-ADComputer -Filter * | Where-Object {$_.Name -like "*diluted*"}) | Where-Object {$_.Name -notlike "*clus*"}).DnsHostName | Sort-Object -Unique

#Run your workflow
basicWorkflow -PSComputerName $computers

#Something more advanced that shows how sorting isn't an easy thing in workflows
Workflow get-OSVersioning
{
    systeminfo | findstr /B /C:"Host Name" /C:"OS Name" /C:"OS Version"
}

get-OSVersioning -PSComputerName $computers

#Passing credentials with a workflow
Workflow send-CredentialViaWorkflow
{
    hostname
    whoami
}

#Pull your crednetials into a variable with a user prompt
$credential = Get-Credential -UserName dilutedAD\dilutedadmin -Message "Gimme dem creds boi"
#Run the workflow with the -PScredential parameter
send-CredentialViaWorkflow -PSComputerName $computers -PSCredential $credential
#Take note of the messy order of the output.  Keep this in mind for when we move on to invoke-command

#Using workflows for something currently relevant
Workflow get-QualCurretKey
{
    Get-ItemProperty "HKLM:\software\microsoft\windows\CurrentVersion\QualityCompat\"
}

#Run your workflow
get-QualCurretKey -PSComputerName $computers
#Point out that you can tab complete through registry as if it's a file structure because powershell treats it as a file structure

#Covering some limitations
Workflow get-OSVersionFailure
{
    Get-ComputerInfo | Select-Object CsDNSHostName,OsVersion
}

get-OSVersionFailure -PSComputerName $computers

#Workflow fails as Get-ComputerInfo is not a supported workflow action.  Other useful powershell functions such as format-list are also not supported. 
#This is why it's recommened to move remote executions to invoke-command as Workflows are deprecated and don't fully support the Powershell toolbox.

#More examples of workflow short comings
Workflow get-environmentVariableFailure
{
    $env:computername
}

get-environmentVariableFailure -PSComputerName $computers

#CIM instance doesn't work either.  
Workflow get-environmentVariableFailure
{
    (Get-CIMInstance CIM_ComputerSystem).Name
}

get-environmentVariableFailure -PSComputerName $computers

#The last two examples both appear to pull the data from local device instead of the remote devices being passed to the workflow

#Moving onto invoke-command and why you should be using it
#Firstly, workflow has been deprecated in favor of invoke-command
#Invoke command is easier and cleaner.  Lets work through our previous examples using invoke command and script block

#Gather domain objects to run against
$computers = ((Get-ADComputer -Filter * | Where-Object {$_.Name -like "*diluted*"}) | Where-Object {$_.Name -notlike "*clus*"}).DnsHostName | Sort-Object -Unique

#So clean, short and effecient
$scriptblock = {Get-WMIObject Win32_ComputerSystem | Select-Object -ExpandProperty name}
Invoke-Command -ComputerName $computers -ScriptBlock $scriptblock

#See how much cleaner?
$scriptblock = {systeminfo | findstr /B /C:"Host Name" /C:"OS Name" /C:"OS Version"}
Invoke-Command -ComputerName $computers -ScriptBlock $scriptblock

#I think you guys get the point but lets keep going

$scriptblock = {
    hostname 
    whoami
}
$credential = Get-Credential -UserName dilutedAD\dilutedadmin -Message "Gimme dem creds boi"
Invoke-Command -ComputerName $computers -ScriptBlock $scriptblock -Credential $credential

#Take note of the proper order.  Command is ran inline for each device one at a time.  Workflows can be powerful for quick and dirty parallel group changes but the formatting gives me an aneurysm

#Things that didn't work in workflows are supported in invoke-command

#Get-ComputerInfo works because invoke-command acts as if the powershell is running locally to the devices passed to it
$scriptblock = {Get-ComputerInfo | Select-Object CsDNSHostName,OsVersion}
Invoke-Command -ComputerName $computers -ScriptBlock $scriptblock

#Environment variables work as well
$scriptblock = {$env:computername}
Invoke-Command -ComputerName $computers -ScriptBlock $scriptblock

#Get-CIMInstance works as well
$scriptblock = {(Get-CIMInstance CIM_ComputerSystem).Name}
Invoke-Command -ComputerName $computers -ScriptBlock $scriptblock

#According to my stream chat this was "Nerd Magic"

#As you can see invoke-command is much cleaner and more effective.
























#Bonus meme

#Below is an example of how a scrub can still write good looking code (thanks to copying other peoples good looking code and changing it to do what you want)

<#
.Synopsis
    Displays the Windows Version for all discovered Hypervisors.
.DESCRIPTION
    Gets the Windows Version number. Automatically detects if running on a standalone hyp or hyp cluster. If standalone is detected it will display only the Windows Version for the device it's run against. If a cluster is detected it will display Windows Version for all nodes in the cluster.
.EXAMPLE
    Get-WindowsVersion
    This command displays Windows Version for all discovered Hypervisors.
.OUTPUTS
	ComputerName  Operating System               Version Build
	------------  ----------------               ------- -----
	test-Hyp01 Windows Server 2016 Datacenter 1607    14393
	test-Hyp02 Windows Server 2016 Datacenter 1607    14393
.NOTES
    Author: Wesley Knight
.FUNCTIONALITY
     Get the Windows Version for all discovered Hypervisors.
#>
function Get-WindowsVersion {
    $adminEval = Test-RunningAsAdmin
    if ($adminEval -eq $true) {
        $clusterEval = Test-IsACluster
        if ($clusterEval -eq $true) {
            #we are definitely dealing with a cluster - execute code for cluster
            Write-Verbose -Message "Cluster detected. Executing cluster appropriate diagnostic..."
            Write-Verbose "Getting all cluster nodes in the cluster..."
            $nodes = Get-ClusterNode -ErrorAction SilentlyContinue
            if ($nodes -ne $null) {
                #--------------------------------------------------------------------------
                Foreach ($node in $nodes) {
                    try {
                        #lets make sure we can actually reach the other nodes in the cluster
                        #before trying to pull information from them
                        Write-Verbose -Message "Performing connection test to node $node ..."
                        if (Test-Connection $node -Count 1 -ErrorAction SilentlyContinue) {
                            Write-Verbose -Message "Connection succesful.  Getting Windows Version information..."
                            #-----------------Get Windows Version data for cluster now---------------------
							#-----------------Pull ProductName---------------------
							$ProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
							#-----------------If not 2016 don't check registry for releaseID---------------------
							if($ProductName -notcontains "Windows Server 2016 Datacenter") {
								((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName,CurrentBuild) | Select @{Name="ComputerName";Expression={$_.PSComputerName}},@{Name="Operating System";Expression={$_.ProductName}},@{Name="Build";Expression={$_.CurrentBuild}})
							}
							#-----------------Else check for releaseID---------------------
							else{
								(Invoke-Command -ComputerName $node -ScriptBlock {(Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName,ReleaseId,CurrentBuild) | ` 
									Select-Object ProductName,ReleaseId,CurrentBuild}) | Select @{Name="ComputerName";Expression={$_.PSComputerName}}, @{Name="Operating System";Expression={$_.ProductName}},@{Name="Version";Expression={$_.ReleaseID}},@{Name="Build";Expression={$_.CurrentBuild}}
							}
                            #--------------END Get Windows Version data for Cluster---------------------
                        }#nodeConnectionTest
                        else {
                            Write-Verbose -Message "Connection unsuccesful."
                            Write-Host "Node: $node could not be reached - skipping this node" `
                                -ForegroundColor Red
                        }#nodeConnectionTest
                    }
                    catch {
                        Write-Host "An error was encountered with $node - skipping this node" `
                            -ForegroundColor Red
                        Write-Error $_
                    }
                }#nodesForEach
                #-----------------------------------------------------------------------
            }#nodeNULLCheck
            else {
                Write-Warning -Message "Device appears to be configured as a cluster but no cluster nodes were returned by Get-ClusterNode"
            }#nodeNULLCheck
        }#clusterEval
        else {
            #standalone server - execute code for standalone server
            Write-Verbose -Message "Standalone server detected. Executing standalone diagnostic..."
            #-----------------Get Windows Version data now---------------------
            Write-Verbose -Message "Getting Windows Version information..."
			try {
				#-----------------Pull ProductName---------------------
				$ProductName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName).ProductName
				#-----------------If not 2016 don't check registry for releaseID---------------------
				if($ProductName -notcontains "Windows Server 2016 Datacenter") {
					((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName,CurrentBuild) | Select @{Name="Operating System";Expression={$_.ProductName}},@{Name="Build";Expression={$_.CurrentBuild}})
				}
				#-----------------Else check for releaseID---------------------
				else{
				((Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -Name ProductName,ReleaseId,CurrentBuild -ErrorAction SilentlyContinue) |`
					Select @{Name="Operating System";Expression={$_.ProductName}},@{Name="Build";Expression={$_.CurrentBuild}})
				}
			}
			catch {
				Write-Host "An error was encountered with data retrieval..."
			}
            #--------------END Get VM Data ---------------------
        }
    }#administrator check
    else {
        Write-Warning -Message "Not running as administrator. No further action can be taken." 
    }#administrator check
}
