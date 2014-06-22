#.ExternalHelp RESAM.psm1-help.xml
function ConvertFrom-Xml{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [Xml]$Base,
        [Parameter(Mandatory=$True)]
        [string]$Path
    )

    $Object = New-Object PSObject

    $base.SelectNodes($Path) | Get-Member -MemberType Property | %{
        if($_.Definition -match "System.Xml.XmlElement"){
            $newObject = ConvertFrom-Xml -Base $Base -Path "$Path/$($_.Name)"
            Add-Member -InputObject $Object -Name $_.Name -Value $newObject -MemberType NoteProperty
        }
        else{
            $value = $Base.SelectNodes($path)."$($_.Name)"
            Add-Member -InputObject $Object -Name $_.Name -Value $value -MemberType NoteProperty
        }
    }
    $Object
}

#.ExternalHelp RESAM.psm1-help.xml
function Invoke-ResAMREST {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
	    [string]$Uri,
        [Parameter(Mandatory=$True)]
        [ValidateSet("GET","PUT","POST")] 
	    [string]$Method,
        [Parameter(Mandatory=$True)]
	    [System.Management.Automation.PSCredential]$Credential,
	    [System.Object]$Body
	)
	
	process {
		$restSplat = @{
			Uri = $Uri
			Credential = $Credential
			Method = $Method
			ContentType = "application/json"
			SessionVariable = "Script:ResAMSession"
		}
		if($Body){
			$restSplat.Add("Body",$Body)
		}
		
		Invoke-RestMethod @restSplat
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Test-ResAM {
    [CmdletBinding()]
	param(
      [Parameter(Mandatory=$True)]
	    [string]$Dispatcher,
      [Parameter(Mandatory=$True)]
	    [System.Management.Automation.PSCredential]$Credential
	)

  process {
    if(Test-Connection -ComputerName $Dispatcher){
      $DispatcherConnect = $true

      $endPoint = "Dispatcher/SchedulingService/help"
      $uri = "http://$Dispatcher/$($endPoint)"

      $pREST = @{
	      Uri = $Uri
	      Method = "GET"
	      Credential = $Credential
      }
      (Invoke-ResAMREST @pREST) -match "service operations at this endpoint."
    }
    else{
      $false
    }
  }
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMModule {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
        [String[]]$Module = @(".*")
	)
	
	process {
    $tgtRegExModule = [String]::Join('|',$Module)

		$endPoint = "Dispatcher/SchedulingService/what/modules"
		$uri = "http://$Dispatcher/$($endPoint)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
		(Invoke-ResAMREST @pREST) | Where Name -match $tgtRegExModule
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMProject {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
        [String[]]$Project = @(".*")
	)
	
	process {
        $tgtRegExProject = [String]::Join('|',$Project)

		$endPoint = "Dispatcher/SchedulingService/what/projects"
		$uri = "http://$Dispatcher/$($endPoint)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
		(Invoke-ResAMREST @pREST) | Where Name -match $tgtRegExProject
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMRunBook {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
        [String[]]$RunBook = @(".*")
	)
	
	process {
    $tgtRegExRunBook = [String]::Join('|',$RunBook)

		$endPoint = "Dispatcher/SchedulingService/what/runbooks"
		$uri = "http://$Dispatcher/$($endPoint)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
		(Invoke-ResAMREST @pREST) | Where Name -match $tgtRegExRunBook
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMInputParameter {
    [CmdletBinding()]
	param(
    [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
    [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory=$True)]
		[PSObject]$What,
    [Switch]$Raw = $false
	)
	
	process {
		$endPoint = "Dispatcher/SchedulingService/what"

		$uri = "http://$Dispatcher/$($endPoint)/$([RESAM.JobWhatType]$What.Type)s/$($What.Id)/inputparameters"
		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
#
# Only parameters that are actually used in any of the module tasks will be returned !
#
		$result = Invoke-ResAMREST @pREST
        if($Raw){$result}
        else{$result.JobParameters}
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMJob {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
        [int]$NumberOfJobs = ([int]::MaxValue),
        [DateTime]$Start,
        [DateTime]$Finish,
        [Switch]$Reverse = $True,
		[ValidateSet("All","Scheduled","Active","History")]
		[String]$Stage = "All",
		[Switch]$IncludeRunBookJobs = $False,
		[Switch]$IncludeRecurringJobs = $False,
        [String]$Description
	)
	
	process {
    $allJobs = @()
    $pagesize = $MyInvocation.MyCommand.Module.PrivateData["PageSize"]
    if(!$Start){
            $daysBack = $MyInvocation.MyCommand.Module.PrivateData["DaysBackDefault"]
            $Start = (Get-Date).AddDays(-$daysBack)
        }
    if(!$Finish){
            $Finish = Get-Date
        }
    $Start = $Start.ToUniversalTime()
    $Finish = $Finish.ToUniversalTime()
# Fix issue with JSON DateTime values that are 2x converted to UTC
    $offsetUTC = ([System.TimeZoneInfo]::Local).GetUtcOffset($Start) | Select -ExpandProperty TotalMinutes
    $Start = $Start.AddMinutes(- $offsetUtc)
    $Finish = $Finish.AddMinutes(- $offsetUTC)

 		$endPoint = "Dispatcher/SchedulingService/jobs"
    $lastPage = $False
    $pageNumber = 1

    While(!$lastPage){
      $paramArray = @()
		  $paramArray += "stage=$($Stage)"
		  $paramArray += "runbookjobs=$($IncludeRunBookJobs.ToString())"
		  $paramArray += "recurringjobs=$($IncludeRecurringJobs.ToString())"
		  $paramArray += "page=$($pageNumber.ToString())"
		  $paramArray += "pagesize=$($pageSize.ToString())"
		  $paramStr = [String]::Join('&',$paramArray)

		  $uri = "http://$Dispatcher/$($endPoint)?$($paramStr)"
		  $pREST = @{
			  Uri = $Uri
			  Method = "GET"
			  Credential = $Credential
		   }
		  $result = (Invoke-ResAMREST @pREST) | Where Description -match $tgtRegExDescription
      $allJobs += $result.Items
      if($result.CurrentPage -le $result.PageCount){
              $pageNumber = $result.CurrentPage + 1
           }
      else{
              $lastPage = $true
           }
    }
      
    $pSort = @{
           Property = {$_.Status.StartDateTime}
        }
    if($Reverse){
           $pSort | Add-Member -Name Descending -Value $True -MemberType NoteProperty
        }
    $allJobs = $allJobs | Sort-Object @pSort
    if($description){
            $tgtRegExDescription = [String]::Join('|',$Description)
            $allJobs = $allJobs | Where{$_.Description -match $tgtRegExDescription}         
        }
    if($Start -or $Finish){
            if(!$Start){
                $Start = Get-Date -Year 1970 -Month 1 -Day 1
            }
            if(!$Finish){
                $Finish = Get-Date
            }

            $allJobs = $allJobs | 
                Where {$_.Status.StartDateTime -ge $Start -and $_.Status.StartDateTime -le $Finish}
#                Where {$_.When.ScheduledDateTime -ge $Start -and $_.When.ScheduledDateTime -le $Finish}
        }
    if($NumberOfJobs -lt ([int]::MaxValue)){
            $allJobs | Select -First $NumberOfJobs
        }
    else{
            $allJobs
        }
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMJobByID {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$True)]
		[String]$JobID
	)
	
	process {
		$endPoint = "Dispatcher/SchedulingService/jobs"

		$uri = "http://$Dispatcher/$($endPoint)/$($JobID)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
		Invoke-ResAMREST @pREST
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMJobResult {
    [CmdletBinding()]
	param(
    [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
    [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
    [Parameter(Mandatory=$True)]
		[String]$JobID,
		[Switch]$IncludeOverview = $False,
		[Switch]$IncludeDetailed = $False
	)
	
	process {
		$endPoint = "Dispatcher/SchedulingService/jobs"

		$paramArray = @()
		$paramArray += "overview=$($IncludeOverview.ToString())"
		$paramArray += "detailed=$($IncludeDetailed.ToString())"
		$paramStr = [String]::Join('&',$paramArray)

		$uri = "http://$Dispatcher/$($endPoint)/$($JobID)/results?$($paramStr)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
		$result = Invoke-ResAMREST @pREST

# The actual result is an XML object, base64 encoded, stored under the Xml property
# 
    $xmlResult = [Xml]([System.Text.Encoding]::Unicode.GetString($result.Xml))
    $start = "/masterjobresults/masterjobresult"

    ConvertFrom-Xml -Base $xmlResult -Path $start
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMRunBookJob {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$True)]
		[String]$JobID
    )
    
    Process{
		$endPoint = "Dispatcher/SchedulingService/runbookjobs"

		$uri = "http://$Dispatcher/$($endPoint)/$($JobID)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
		Invoke-ResAMREST @pREST
    }
}

#.ExternalHelp RESAM.psm1-help.xml
function New-ResAMJob {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
		[String]$Description,
		[String[]]$Agent,
        [Parameter(ParameterSetName='Module')]
        [String[]]$Module,
        [Parameter(ParameterSetName='Project')]
		[String[]]$Project,
        [Parameter(ParameterSetName='RunBook')]
		[String[]]$RunBook,
		[DateTime]$Start = (Get-Date),
		[Switch]$Immediate = $true,
        [Switch]$LocalTime = $true,
		[Switch]$UseWOL = $false,
		[HashTable]$Parameter
	)

	process {
        if($Module){
            $tgtTask = Get-ResAMModule -Dispatcher $Dispatcher -Credential $Credential -Module $Module
        }
        if($Project){
            $tgtTask = Get-ResAMProject -Dispatcher $Dispatcher -Credential $Credential -Project $Project
        }
        if($RunBook){
            $tgtTask = Get-ResAMRunBook -Dispatcher $Dispatcher -Credential $Credential -RunBook $RunBook
        }

        $tgtParameters = Get-ResAMInputParameter -Dispatcher $Dispatcher -Credential $Credential -What $tgtTask -Raw         
        $tgtAgent = Get-ResAMAgent -Dispatcher $Dispatcher -Credential $Credential -Agent $Agent

        if($Parameter){
            $updatedJobParameters = &{
                foreach($jobParam in $tgtParameters.JobParameters){
                    $Parameter.GetEnumerator() | %{
                        if($_.Key -eq $jobParam.Name){
                            $jobParam.Value1 = $_.Value
                        }
                    }
                    $jobParam
                } 
            }
            $tgtParameters.JobParameters = @($updatedJobParameters)
        }

		$endPoint = "Dispatcher/SchedulingService/jobs"
		$uri = "http://$Dispatcher/$($endPoint)"
		
		$blob = [pscustomobject]@{
			Description = $Description
			When = @{
			    ScheduledDateTime = $Start
                Immediate = $Immediate.ToString().ToLower()
                IsLocalTime = $LocalTime.ToString().ToLower()
                UseWakeOnLAN = $UseWOL.ToString().ToLower()
			}
            What = @($tgtTask)
            Who = @($tgtAgent)
            Parameters = @($tgtParameters)
		}
		$pREST = @{
			Uri = $Uri
			Method = "POST"
			Credential = $Credential
		}
		Invoke-ResAMREST @pREST -Body (ConvertTo-Json $blob -Depth 99)
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Stop-ResAMJob {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
        [Parameter(Mandatory=$True)]
		[PSObject]$Job
	)

	process {
		$endPoint = "Dispatcher/SchedulingService/jobs"
		$uri = "http://$Dispatcher/$($endPoint)/$($Job.JobID)"
		$pREST = @{
			Uri = $Uri
			Method = "PUT"
			Credential = $Credential
		}
# Set job type to Aborting (2)
        $Job.Status.Type = 2
		Invoke-ResAMREST @pREST -Body (ConvertTo-Json $Job.Status)
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMAgent {
    [CmdletBinding()]
	param(
        [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
        [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
    [String]$AgentName,
		[String[]]$Agent = @(".*"),
		[Switch]$IncludeAgents = $True,
		[Switch]$IncludeTeams = $True,
		[Switch]$OnlineOnly = $False,
		[Switch]$LicensedOnly = $False
	)
	
	process {
    $tgtRegExAgent = [String]::Join('|',$Agent)

		$paramArray = @()
		$endPoint = "Dispatcher/SchedulingService/who"
		$paramArray += "agents=$($IncludeAgents.ToString())"
		$paramArray += "teams=$($IncludeTeams.ToString())"
		$paramArray += "online=$($OnlineOnly.ToString())"
		$paramArray += "licensed=$($LicensedOnly.ToString())"
		if($AgentName){
			$paramArray += "search=$AgentName"
		}
		$paramStr = [String]::Join('&',$paramArray)
		$uri = "http://$Dispatcher/$($endPoint)?$($paramStr)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
		(Invoke-ResAMREST @pREST) | Where Name -match $tgtRegExAgent
	}
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMJobUsage{
	param(
    [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
    [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential,
    [DateTime]$Start,
    [DateTime]$Finish
	)

  process{
		$endPoint = "Dispatcher/SchedulingService/report/jobusage"

    $paramArray = @()
		$paramArray += "Start=$($Start.ToString("yyyyMMddHHmmss"))"
		$paramArray += "Stop=$($Finish.ToString("yyyyMMddHHmmss"))"
		$paramStr = [String]::Join('&',$paramArray)

		$uri = "http://$Dispatcher/$($endPoint)?$($paramStr)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
    Invoke-ResAMREST @pREST
  }
}

#.ExternalHelp RESAM.psm1-help.xml
function Get-ResAMTeams{
	param(
    [Parameter(Mandatory=$True)]
		[String]$Dispatcher,
    [Parameter(Mandatory=$True)]
		[System.Management.Automation.PSCredential]$Credential
  )

  process{
		$endPoint = "Dispatcher/SchedulingService/report/teams"
		$uri = "http://$Dispatcher/$($endPoint)"

		$pREST = @{
			Uri = $Uri
			Method = "GET"
			Credential = $Credential
		}
    Invoke-ResAMREST @pREST
  }
}
