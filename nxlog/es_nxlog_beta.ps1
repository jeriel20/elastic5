<#
.SYNOPSIS  
    
.DESCRIPTION  

.NOTES  
    File Name  : 
    Org.       : CPB	
    Author     :  
	Modified by:
    Requires   : 
.LINK 
  None at this time. 
#>

# set variables for script to run  
$Script:pathToConfFile
$Script:pathToConfDir
$Script:pathToWinEvtxDir
$Script:fileConfName
$Script:jsonFileStorePath
$Script:elasticSearchIpCount = 0
$Script:flushInterval = 60
$Script:flushIntervalLimit = 7500
$Script:evtxFileReq = 50

# create array for files within evtx folder
$Script:dirList = New-Object System.Collections.ArrayList
# create array for elasticsearch ip address based on user input
$Script:elasticsearchIPs = New-Object System.Collections.ArrayList
# create array to capture user selection for nxlog execution
$Script:userSelection = New-Object System.Collections.ArrayList

function showMainMenu{
 cls
 write-host "========= Elasticsearch Main Menu =========`n" -foregroundcolor yellow
 write-host "`t1 - Create Nxlog conf. files using om_elasticsearch module" -foregroundcolor yellow
 write-host "`t2 - Create Nxlog conf. files using om_file module" -foregroundcolor yellow
 write-host "`t3 - Validate Nxlog conf files" -foregroundcolor yellow
 write-host "`t4 - Manual Nxlog conf files Execution" -foregroundcolor yellow
 write-host "`t5 - Automated Nxlog conf files Execution (json files)" -foregroundcolor yellow
 write-host "`t6 - Display Nxlog.exe history" -foregroundcolor yellow

 write-host "`n`tq - Quit`n" -foregroundcolor yellow
}#end function

function showValidationMenu{
 cls
 write-host "========= Elasticsearch Validation Menu =========`n" -foregroundcolor yellow
 write-host "`t1 - Validate all Nxlog.conf files withing a directory" -foregroundcolor yellow
 write-host "`t2 - Validate single Nxlog.config file" -foregroundcolor yellow
 write-host "`n`tq - Quit`n" -foregroundcolor yellow
}#end function

function get-confDir {
  param(
    [string]$msg
  )

  $ok = $false

  do{
    $userInput = read-host "`n$msg"
    if (test-path $userInput){
      $Script:pathToConfDir = $userInput
      $ok = $true
    }else {
      md $userInput | out-null
      $Script:pathToConfDir = $userInput
      write-host "`n$userInput directory created!" -foregroundcolor yellow 
      $ok=$true
    }
  }until($ok)
}#end function

function get-jsonFileStorePath {
  $ok = $false
  do{
    $userInput = read-host "`nProvide path where json output files will be store? (i.e. c:\program files\nxlog\confs)"
    if (test-path $userInput){
      $Script:jsonFileStorePath = $userInput
      $ok = $true
    }else {
      md $userInput |out-null
      $Script:jsonFileStorePath = $userInput
      write-host "`n$userInput directory created!" -foregroundcolor yellow
      $ok = $true      
    }
  }until($ok)
}#end function

function get-confFileName {
  $ok = $false
  do{
    $userInput = read-host "`nProvide nxlog configuration file name (i.e. nov.json)?"
    if (($userInput -eq "") -or ($userInput -notmatch "^*\.json$")){
      write-host "`nInvalid Input!" -foregroundcolor red
    }else {
      $Script:fileConfName = "$userInput"
      $ok = $true
    }
  }until($ok)
}#end function

function get-winEvtDir {
  $ok = $false
  do{
    $userInput = read-host "`nProvide directory path for evtx files? (i.e. c:\program files\nxlog\data\evtx)"
    if (test-path $userInput){
      $Script:pathToWinEvtxDir = $userInput
      $ok = $true  
    }else {
      write-host "`nDirectory does not exit. Invalid Input!" -foregroundcolor red  
    }
  }until($ok)
}#end function

function get-elasticSearchIpAddress {
  $ok = $false
  $Script:elasticsearchIPs.Clear()
  do{
    $userInput = read-host "`nProvide IP for elasticsearch output module (Enter q when done entering IPs)"
    switch -Regex ($userInput){
      "^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$"{
        [void] $Script:elasticsearchIPs.add($userInput)
        Write-Host "Input accepted!" -ForegroundColor yellow
      }#end ip option

      "^[Q|q]$"{
          $ok = $true
      }#end of q option

      default {
        write-host "`nInvalid Input!" -ForegroundColor red
      }#end default option
    }#end switch
  }until ($ok)
}#end function

function validateIpInput{
  $ok = $false
  $userInput = "n"
  do{
    $userInput = Read-Host "`nWould you like to modify any IP entry [N]?"
    switch -Regex ($userInput){
      "^[n|N]$"{
        $ok = $true
      }

      "^[y|Y]$"{
        Write-Host "Sorry Underdevelopment ; please restart the script if you made a mistake..." -ForegroundColor Yellow
        $ok = $true
      }

    }#end of switch statement
  }until($ok)
}#end of function

function get-flushInterval {
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide flush interval in seconds [60]"
    if ($userInput -match "[0-9]"){
      $Script:flushInterval = $userInput
      $ok = $true
    }elseif($userInput -eq ""){
      write-host "`nFlush Interval set to 60 seconds." -ForegroundColor yellow
      $ok = $true
    }else{
      write-host "`nInvalid Input!"
    }
  }until($ok)  
}#end function

function get-flushLimit {
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide flush limit value [7500]"
    if ($userInput -match "[0-9]"){
      $Script:flushIntervalLimit = $userInput
      $ok = $true
    }elseif($userInput -eq ""){
      write-host "`nFlush Limit set to 7500." -ForegroundColor yellow
      $ok = $true
    }else{
      write-host "`nInvalid Input!"
    }
  }until($ok)
}#end function

function get-winEvtxAvailable {
  #populate dirlList array
  $Script:dirList = get-childitem -path $Script:pathToWinEvtxDir
  if($script:dirList.length -eq 0){
    write-host "`nThere is not evtx data available at: $Script:pathToWinEvtxDir" -foregroundcolor red
    write-host "`nPlease upload evtx files before continue. Exiting...!" -ForegroundColor red
    sleep 2
    quit
  }
}#end function

function get-evtxFileReq {
  write-host "`nCurrently there are" $Script:dirList.length "evtx.logs available." -foregroundcolor yellow
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide evtx.log requierment for each nxlog.conf file to be created [50]"
    if ($userInput -match "[0-9]"){
      $Script:evtxFileReq = $userInput
      $ok = $true
    }elseif($userInput -eq ""){
       write-host "`nEvtx.logs requirement set to 50." -ForegroundColor yellow
       $ok = $true
    }else{
      write-host "Invalid input!" -foregroundcolor Red 
    }  
  }until($ok)
}#end function

function set-ConfFilesElasticModule {
  #variable controls the most outter loop
  $ok = $false
  #variable keep track of how many times the loops gets executed
  $loopCount = 0
  #variable represent the begging of a range
  $evtxStartIndex = 0
  #variable represent the increment by with evtx.log files are inserted into the nxlog.conf
  $evtxIncIndex = $Script:evtxFileReq
  #variable used to ensure all evtx.log are ingested
  $evtxEndIndex = 0
  #variable holding the path use at the end of the nxlog.conf file
  $path = ""
  #this ensure the last nxlog is process correctly
  $lastSet = 0

  #this loop creates all the nxlog.conf files base on user input
  do{
   
    #ensure start and end index are correct
    #ensure  elastic search ip address array is loop thru and correct
    if ($loopCount -eq 0){
      $evtxStartIndex = 0
      $evtxEndIndex = $evtxIncIndex - 1
      $Script:elasticSearchIPCount = 0
    }else{
      $evtxStartIndex = $evtxEndIndex + 1
      $evtxEndIndex += $evtxIncIndex
      $Script:elasticSearchIPCount += 1
      if (($evtxEndIndex + 1 -eq $Script:dirList.length) -or ($evtxEndIndex -gt $Script:dirList.length)){
        $lastSet = 1
        $evtxIncIndexLast = $Script:dirList.length - $evtxStartIndex  
      } 
      if ($Script:elasticSearchIPCount -eq $Script:elasticsearchIPs.count){
        $Script:elasticSearchIPCount = 0
      }
    }

    #provide status report of nxlog creation to user
    Write-Progress -Activity "Nxlog.conf file(s) creation in Progress" -Status "progress ->:" -PercentComplete ($evtxEndIndex/$Script:dirList.count);

    #create folder where nxlog.conf will be dropped
    md $Script:pathToConfDir\conf$loopCount | Out-Null

    #header of the file nxlog.conf document
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "Panic Soft"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "#NoFreeOnExit TRUE"
     
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`ndefine ROOT C:\Program Files (x86)\nxlog" 
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`#define ROOT C:\Program Files\nxlog"  
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define CERTDIR %ROOT%\cert"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define CONFDIR $Script:pathToConfDir\conf$loopCount"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define LOGDIR %ROOT%\data"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define LOGFILE '%LOGDIR%/nxlog.log'" 
    
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`nModuledir %ROOT%\modules"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "CacheDir %ROOT%\data"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "Pidfile %ROOT%\data\nxlog.pid"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "SpoolDir %ROOT%\data"
    
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Extension _json>" 
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule`txm_json"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Extension>"

    #input section of the nxlog.conf document
    if($lastSet -eq 0) {
      for ($i = 1; $i -le $evtxIncIndex; ++$i) {
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Input in$i>"
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule`tim_msvistalog"
	    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tFile`t$Script:pathToWinEvtxDir\$($Script:dirList[$evtxStartIndex])"   
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Input>" 
        $evtxStartIndex += 1
      } 
    }else {
      for ($i = 1; $i -le $evtxIncIndexLast; ++$i) {
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Input in$i>"
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule`tim_msvistalog"
	    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tFile`t$Script:pathToWinEvtxDir\$($Script:dirList[$evtxStartIndex])"   
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Input>" 
        $evtxStartIndex += 1
       }      
     }   

    #Output section of the nxlog.conf document
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Output es>"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule	om_elasticsearch"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tURL		http://$($Script:elasticsearchIPs[$Script:elasticSearchIPCount]):9200/_bulk"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tFlushInterval	60"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tFlushLimit	7500"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`t# Create an index daily" 
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tIndex	strftime(`$EventTime, `"nxlog-%Y%m%d`")" 
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tExec	if not defined `$SourceName `$SourceName = 'unknown';"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tIndexType	`$SourceName"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Output>"

    #Router section of the nxlog.conf document
    if($lastSet -eq 0) {
      for ($i = 1; $i -le $evtxIncIndex; ++$i) {
        if ($i -eq 1){
          $path = "in$i"
        }else {
          $path += ", in$i"
        }
      }   
    }else {
      for ($i = 1; $i -le $evtxIncIndexLast; ++$i) {  
        if ($i -eq 1){
          $path = "in$i"
        }else {
          $path += ", in$i"
        }      
      }
    }

    #Router Section of the nxlog.conf document
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Route r>"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tpath   $path => es" 
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Route>"

    #increment the loop contorl variables
    $loopCount += 1
 
    #ends the loop when last evtx.logs are processess
    if($lastSet -eq 1){
      $ok = $true
    }
  }until ($ok)
  Write-host "`nCreation of nxlog.conf files completed!" -foregroundcolor yellow
}#end function

function set-ConfFilesFileModule {
  #variable controls the most outter loop
  $ok = $false
  #variable keep track of how many times the loops gets executed
  $loopCount = 0
  #variable represent the begging of a range
  $evtxStartIndex = 0
  #variable represent the increment by with evtx.log files are inserted into the nxlog.conf
  $evtxIncIndex = $Script:evtxFileReq
  #variable used to ensure all evtx.log are ingested
  $evtxEndIndex = 0
  #variable holding the path use at the end of the nxlog.conf file
  $path = ""
  #this ensure the last nxlog is process correctly
  $lastSet = 0

  #this loop creates all the nxlog.conf files base on user input
  do{
   
    #ensure start and end index are correct
    #ensure  elastic search ip address array is loop thru and correct
    if ($loopCount -eq 0){
      $evtxStartIndex = 0
      $evtxEndIndex = $evtxIncIndex - 1
      $Script:elasticSearchIPCount = 0
    }else{
      $evtxStartIndex = $evtxEndIndex + 1
      $evtxEndIndex += $evtxIncIndex
      $Script:elasticSearchIPCount += 1
      if (($evtxEndIndex + 1 -eq $Script:dirList.length) -or ($evtxEndIndex -gt $Script:dirList.length)){
        $lastSet = 1
        $evtxIncIndexLast = $Script:dirList.length - $evtxStartIndex  
      } 
      if ($Script:elasticSearchIPCount -eq $Script:elasticsearchIPs.count){
        $Script:elasticSearchIPCount = 0
      }
    }

    #provide status report of nxlog creation to user
    Write-Progress -Activity "Nxlog.conf file(s) creation in Progress" -Status "progress ->:" -PercentComplete ($evtxEndIndex/$Script:dirList.count);

    #create folder where nxlog.conf will be dropped
    md $Script:pathToConfDir\conf$loopCount | Out-Null

    #header of the file nxlog.conf document
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "Panic Soft"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "#NoFreeOnExit TRUE"
     
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`ndefine ROOT C:\Program Files (x86)\nxlog" 
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`#define ROOT C:\Program Files\nxlog"  
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define CERTDIR %ROOT%\cert"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define CONFDIR $Script:pathToConfDir\conf$loopCount"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define LOGDIR %ROOT%\data"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "define LOGFILE '%LOGDIR%/nxlog.log'" 
    
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`nModuledir %ROOT%\modules"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "CacheDir %ROOT%\data"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "Pidfile %ROOT%\data\nxlog.pid"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "SpoolDir %ROOT%\data"
    
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Extension _json>" 
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule`txm_json"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Extension>"

    #input section of the nxlog.conf document
    if($lastSet -eq 0) {
      for ($i = 1; $i -le $evtxIncIndex; ++$i) {
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Input in$i>"
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule`tim_msvistalog"
	    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tFile`t$Script:pathToWinEvtxDir\$($Script:dirList[$evtxStartIndex])"   
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tExec to_json();" 
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Input>" 
        $evtxStartIndex += 1
      } 
    }else {
      for ($i = 1; $i -le $evtxIncIndexLast; ++$i) {
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Input in$i>"
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule`tim_msvistalog"
	    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tFile`t$Script:pathToWinEvtxDir\$($Script:dirList[$evtxStartIndex])"   
        ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Input>" 
        $evtxStartIndex += 1
       }      
     }   

    #Output section of the nxlog.conf document
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Output out>"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tModule	om_file"
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tfile	'$Script:jsonFileStorePath\$loopCount`_$Script:fileConfName'"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Output>"

    #Router section of the nxlog.conf document
    if($lastSet -eq 0) {
      for ($i = 1; $i -le $evtxIncIndex; ++$i) {
        if ($i -eq 1){
          $path = "in$i"
        }else {
          $path += ", in$i"
        }
      }   
    }else {
      for ($i = 1; $i -le $evtxIncIndexLast; ++$i) {  
        if ($i -eq 1){
          $path = "in$i"
        }else {
          $path += ", in$i"
        }      
      }
    }

    #Router Section of the nxlog.conf document
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`r`n<Route r>"
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tpath   $path => out" 
    ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "</Route>"

    #increment the loop contorl variables
    $loopCount += 1
 
    #ends the loop when last evtx.logs are processess
    if($lastSet -eq 1){
      $ok = $true
    }
  }until ($ok)
  Write-host "`nCreation of nxlog.conf files completed!" -foregroundcolor yellow
}#end 

function checkConfFile {
  param (
    $path
  )
  #safe execution path of nxlog.exe into a variable exeFile
  $exeFile = "${env:ProgramFiles(x86)}\nxlog\nxlog.exe"
  #execute nxlog.exe with parameters to validate nxlog.conf file and
  #store results cmdOutputVariable for processing
  $cmdOutput = &$exeFile "-c" $path "-v" 2>&1
  if ($cmdOutput -match "INFO configuration OK"){
    write-host "$path configuration ok!" -foregroundcolor yellow
  }else{
    write-host "$path configuration failed! ( Review Line:" ($cmdOutput -split ":")[4]")" -foregroundcolor red
  }#end else statement
}#end function

function get-AvailableConfFile {
  param(
    [string]$title,
    [string]$path
  )
  #ensure array is cleared
  $Script:dirList.Clear()
  #populate dirlList array
  $Script:dirList = get-childitem -path "$path" -Directory

  if($Script:dirList.length -eq 0){
    write-host "`nThere are not configuration files at: $path ...returning to main menu." -foregroundcolor "Yellow"
    break
  }else{
    #set table header
    Write-Host "`n$title"`n -foregroundcolor Yellow
    Write-Host "Index." `t "Conf. File"
    Write-Host "=====" `t "==========="
    # Display TOE available
    for ($i = 0; $i -lt $Script:dirList.Length; ++$i) {
      if (($i -gt 0) -and ($i%20 -eq 0)){
        pause
      }
      Write-Host "  $i `t   $($Script:dirList[$i])"
    }#end for
  }#end else
}#end function

function get-userSelection {
  $Script:userSelection.clear() # clear toeToAnalize array
  $ok = $false #initialize loop control variable
  do {
	# capture user input
    $userInput = Read-Host "`nSelet Conf file for execution(i.e. 0 or 0-2)"
    switch -Regex ($userInput){
      # validate user range input
      "\d{1,3}-\d{1,3}"{
	    # cast user input into a int variable type
	    [int]$a = ($userInput -split '-')[0]
	    [int]$b =($userInput -split '-')[1]
	    if ($a -lt $Script:dirList.length -and $b -lt $Script:dirList.length){
	      for ($i = $a; $i -le $b ; ++$i) {
		    [void]$Script:userSelection.add($i)
		  }#end for
          $ok = $true
	    }else{
          Write-Host "Invalid Input!" -ForegroundColor Yellow
        }#end of else statement
      }#end range option

	  # validate user single digit input
	  "^\d{1,3}$"{
	    #cast user inpunt into a int variable type
	    [int]$i = $userInput
	    if ($i -lt $Script:dirList.length){
	      [void]$Script:userSelection.add($i)
          $ok = $true
	    }else{
          Write-Host "Invalid Input!" -ForegroundColor Yellow
        }#end of else statement
	  } #end single option

	  #validate all other user input
	  default {
        Write-Host "Invalid Input!" -ForegroundColor Yellow
	  }#end default option
    }#end switch
  } until ($ok)
}#end function

function set-report {
  Param (
	[string]$command,
    [string]$path,
    [string]$date  	
   ) 
  # End of Parameters
  process{
	if (test-path "$Script:pathToConfDir\nxlog_report.txt"){
	  "`nExecuted $command  on $date" >>  "$Script:pathToConfDir\nxlog_report.txt"
	  (Get-Content $path) | %{ if ($_ -match "evtx$") {"`t$_ ingested." >> "$Script:pathToConfDir\nxlog_report.txt"}}
	}
	else {
	  "`nExecuted $command  on $date" >  "$Script:pathToConfDir\nxlog_report.txt"	
      (Get-Content $path) | %{ if ($_ -match "evtx$") {"`t$_ ingested." >> "$Script:pathToConfDir\nxlog_report.txt"}}
	}
  }#end process
}#end function

function get-report {
  if (test-path "$Script:pathToConfDir\nxlog_report.txt"){
    #get the time of the report
    Write-Host "`nReport as of: " (Get-ChildItem $Script:pathToConfDir\nxlog_report.txt).LastWriteTime -foregroundcolor yellow  
    Get-Content "$Script:pathToConfDir\nxlog_report.txt" 
  }else {
      write-host "`nNo report available at this time...`n"
  }#end else statement
}#end function

function monitor-currentExe{
  Param (
    [int]$id,
    [string]$path	
   )
  #loop control variable
  $ok = $false 
  #stop function for 5 seconds to allow executable to start
  sleep 5
  #capture the nxlog process id
  [int]$childPid = ((Get-WmiObject win32_process -Filter "ParentProcessId='$id' and name='nxlog.exe'") -split '"')[1]
  #provide feedback to user
  write-host "`nProcessing $path please wait ..."
  #monitoring loop star here
  do {  
    $pastFileSize = (get-item $path).Length
    sleep 30
    if($pastFileSize -eq (get-item $path).Length){
      Stop-Process $childPid
      Stop-Process $id 
      $ok = $true
    }else{
      Write-Host -NoNewline "."
    }
  }until ($ok)
}#end of function

$ok=$false
do{
  showMainMenu
  $input = Read-Host "Please make a selection"
  switch -regex ($input){
    #this part of the code gets execute if option 1 of top menu is selected
    "^1$" {
          get-confDir -msg "Provide directory path where nxlog configuration files will be store (i.e. c:\program files\nxlog\confs)"
          get-winEvtDir
          get-elasticSearchIpAddress
          validateIpInput
          get-flushInterval
          get-flushLimit
          get-winEvtxAvailable
          get-evtxFileReq
          set-ConfFilesElasticModule
     }#end option 1 top menu

    #this part of the code gets execute if option 2 of top menu is selected
    "^2$" {
          get-confDir -msg "Provide directory path where nxlog configuration files will be store (i.e. c:\program files\nxlog\confs)"
          get-winEvtDir
          get-confFileName
          get-jsonFileStorePath
          get-winEvtxAvailable
          get-evtxFileReq
          set-ConfFilesFileModule
     }#end option 2 top menu

     #this part of the code gets execute if option 3 of top menu is selected
     "^3$"{
           showValidationMenu
           $ok2 = $false
           do{
             $input = Read-Host "Please make a selection"
             switch -regex ($input){
               "^1$"{
                    get-confDir -msg "Provide directory path where nxlog configuration files are stored (i.e. c:\program files\nxlog\confs)"
                    foreach ($item in get-item "$Script:pathToConfDir\*\nxlog.conf"){
                      checkConfFile -path $item
                    }#end foreach loop
                    $ok2 = $true
                  }#end option 1

               "^2$"{
                    get-confFilePath
                    checkConfFile -path $Script:pathToConfFile
                    $ok2 = $true
               }#ends option 2

               "^[q|Q]$"{
                 $ok2 = $true
               }#ends option quit 

               default {
                 write-host "Invalid Input" -foregroundcolor red
               }#end option default
             }#ends option 2 switch statement
           }until($ok2) 
     }#end option 3 top menu

     #this part of the code gets execute if option 4 of top menu is selected
     "^4$"{
       get-confDir -msg "Provide directory path where nxlog configuration files are stored (i.e. c:\program files\nxlog\confs)"
       get-AvailableConfFile -title "Configuaration Files Ready For Execution"  -path $Script:pathToConfDir
       get-userSelection
       Write-Host "`nBased on selection execute below commands to process log files:`n" -ForegroundColor Yellow
       foreach ($item in $Script:userSelection){
         write-host "`t${env:ProgramFiles(x86)}\nxlog\nxlog.exe -c $Script:pathToConfDir\conf$item\nxlog.conf -f" -ForegroundColor Yellow
       }#end of foreach loop
     }#end option 4 top menu

     #this part of the code gets execute if option 5 of top menu is selected
     "^5$"{
       get-confDir -msg "Provide directory path where nxlog configuration files are stored (i.e. c:\program files\nxlog\confs)"
       get-AvailableConfFile -title "Configuaration Files Ready For Execution"  -path $Script:pathToConfDir
       get-userSelection
       foreach ($item in $Script:userSelection){
         $env:currentConfPath = "$Script:pathToConfDir\conf$item\nxlog.conf"
         #finds what json file needs monitoring
         $pathToMonitor = cat $Script:pathToConfDir\conf$item\nxlog.conf | %{if ($_ -match "json'$"){($_ -split "'")[1]}}
         $currentExe = start-process powershell.exe {echo "Executing:` nxlog.exe` -c` $env:currentConfPath` -f" ;&${env:ProgramFiles(x86)}\nxlog\nxlog.exe -c $env:currentConfPath -f } -PassThru
         set-report -date (get-date -format g) -command "${env:ProgramFiles(x86)}\nxlog\nxlog.exe -c $env:currentConfPath -f" -path $env:currentConfPath
         monitor-currentExe -id $currentExe.Id -path $pathToMonitor
       }#end of foreach loop
     }#end option 5 top menu

     #this part of the code gets execute if option 6 of top menu is selected
     "^6$"{
       get-report
     }#end option 6 top menu

     #this part of the code gets execute if option q of top menu is selected
     "^[q|Q]$"{
       $ok = $true
       exit
     }#end option quit top menu

     default {
       write-host "Invalid Input!!" -foregroundcolor Red    
     }#end option default top menu
  }#end top menu switch
  pause
}until ($ok)