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
