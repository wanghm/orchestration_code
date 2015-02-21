Param ([string] $strRegion = "ap-northeast-1", `
	[string] $strJmeterAsgGroupName = "asg01-jmeter", `
	[int] $intInstanceCount = 2, `
	[string] $strJmeterConfig)


#default values of parameters
$strJmeterConfig = [environment]::getenvironmentvariable("userprofile") + "\Documents\apache-jmeter\bin\jmeter.properties"
$LOG_ENCODE = "Ascii"


# create jmeter slaves (update autoscale group)
function func_CreateSlaves()
{
	try {
	    aws autoscaling update-auto-scaling-group --auto-scaling-group-name $strJmeterAsgGroupName  `
	        --min-size $intInstanceCount --desired-capacity $intInstanceCount --region $strRegion
	} catch [Exception] {
	    $strErr = "Failed to create jmeter slaves"
		throw $strErr
	}
}

# set ip of jmeter slvaes into config file of jmeter
function func_UpdataSlaveIP()
{
    try {
     	# get ip list of jmeter slvaes
		$items = @(aws ec2 describe-instances --filters `
		"Name=tag:aws:autoscaling:groupName,Values=$strJmeterAsgGroupName" "Name=instance-state-name,Values=running"  --region $strRegion `
		| jq '.Reservations[].Instances[].PrivateIpAddress')

		$strIPList = ""
		foreach($item in $items)
		{
		    if($strIPList.CompareTo("") -eq 0) {
		        $strIPList  += $item
		    } else {
		        $strIPList  += "," + $item
		    }
		}

		$strIPList = $strIPList -replace "`"", ""
		$date = get-date -format yyyyMMdd
		$time = get-date -format HHmmss

		$strJmeterConfigBackup = $strJmeterConfig + $date + $time
		# backup the config file
		copy $strJmeterConfig $strJmeterConfigBackup

		# replace ips of slave server (^remote_hosts=.* -> remote_hosts=$strIPList)
		$strContent = $(Get-Content $strJmeterConfigBackup) -replace "^remote_hosts=.*","remote_hosts=$strIPList"
		Set-Content -path $strJmeterConfig -value $strContent -encoding String

	} catch [Exception] {
	    $strErr = "Failed to update jmeter config"
		throw $strErr
	}
}


#func_CreateSlaves
func_UpdataSlaveIP
