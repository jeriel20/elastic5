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
$Script:elasticSearchIpCount = 0
$Script:flushInterval = 60
$Script:flushIntervalLimit = 10000
$Script:evtxFileReq = 50

# create array for files within evtx folder
$Script:dirList = New-Object System.Collections.ArrayList
#create array for elasticsearch ip address based on user input
$Script:elasticsearchIPs = New-Object System.Collections.ArrayList

function showMainMenu{
 cls
 write-host "========= Elasticsearch Main Menu =========`n" -foregroundcolor yellow
 write-host "`t1 - Create Nxlog config files" -foregroundcolor yellow
 write-host "`t2 - Validate Nxlog config files" -foregroundcolor yellow
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
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide nxlog configuration directory path? (i.e. c:\program files\nxlog\confs)"
    if (test-path $userInput){
      $Script:pathToConfDir = $userInput
      $ok = $true
    }else {
      write-host "`nDirectory does not exit. Invalid Input!" -foregroundcolor red  
    }
  }until($ok)
}#end function

function get-confFilePath {
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide nxlog configuration file path? (i.e. c:\program files\nxlog\confs\nxlog.conf)"
    if (test-path $userInput){
      $Script:pathToConfFile = $userInput
      $ok = $true
    }else {
      write-host "`nnxlog.conf file does not exit. Invalid Input!" -foregroundcolor red  
    }
  }until($ok)
}#end function


function get-winEvtDir {
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide nxlog data (evtx.log) directory path? (i.e. c:\program files\nxlog\data)"
    if (test-path $userInput){
      $Script:pathToWinEvtxDir = $userInput
      $ok = $true  
    }else {
      write-host "`nDirectory does not exit. Invalid Input!" -foregroundcolor red  
    }
  }until($ok)
}#end function
#need to work on this function ... not woring propertly
function get-elasticSearchIpAddress {
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide IP Address for Elasticsearch output module?"
    if ($userInput -match "^(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}$"){
      [void] $Script:elasticsearchIPs.add($userInput)
      $userInput = read-host "`nWhould you like to enter another IP Address[Y|N]?"
      switch -Regex ($userInput){
        "[N|n]"{
          $ok = $true
        }

        "[Y|y]"{
          break
        }

        default {
          write-host "`nInvalid Input!" -ForegroundColor red
        }
      }#end switch
    }else {
      write-host "`nInvalid Input!" -foregroundcolor red  
    }
  }until ($ok)
}#end function

function get-flushInterval {
  $ok = $false
  do{
    $userInput = read-host "`nPlease provide flush interval in seconds [60]"
    if ($userInput -match "[0-9]"){
      $flushInterval = $userInput
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
    $userInput = read-host "`nPlease provide flush limit value [10000]"
    if ($userInput -match "[0-9]"){
      $flushIntervalLimit = $userInput
      $ok = $true
    }elseif($userInput -eq ""){
      write-host "`nFlush Limit set to 10000." -ForegroundColor yellow
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
#create nxlog.conf files
function set-ConfFiles {
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
	ac "$Script:pathToConfDir\conf$loopCount\nxlog.conf" "`tFlushLimit	10000"
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

function checkConfFile {
  param (
    $path
  )
  #safe execution path of nxlog.exe into a variable exeFile
  $exeFile = "$env:programFiles\nxlog\nxlog.exe"
  #execute nxlog.exe with parameters to validate nxlog.conf file and
  #store results cmdOutputVariable for processing
  $cmdOutput = &$exeFile "-c" $path "-v" 2>&1
  if ($cmdOutput -match "INFO configuration OK"){
    write-host "$path configuration ok!" -foregroundcolor yellow
  }else{
    write-host "$path configuration failed! ( Review Line:" ($cmdOutput -split ":")[4]")" -foregroundcolor red
  
  }#end else statement

}#end function

$ok=$false
do{
  showMainMenu
  $input = Read-Host "Please make a selection"
  switch -regex ($input){
    #this part of the code gets execute if option 1 of top menu is selected
    '1' {
          get-confDir
          get-winEvtDir
          get-elasticSearchIpAddress
          get-flushInterval
          get-flushLimit
          get-winEvtxAvailable
          get-evtxFileReq
          set-ConfFiles
     }#end option 1

     '2'{
           showValidationMenu
           $ok2 = $false
           do{
             $input = Read-Host "Please make a selection"
             switch -regex ($input){
               '1'{
                    get-confDir
                    foreach ($item in get-item "$Script:pathToConfDir\*\nxlog.conf"){
                     checkConfFile -path $item
                    }#end foreach loop
                    pause
                    $ok2 = $true
                  }#end option 1

               '2'{
                    get-confFilePath
                    checkConfFile -path $item
                    pause
                    $ok2 = $true
               }

               "[q|Q]"{
                 $ok2 = $true
               }

               default {
                 write-host "Invalid Input" -foregroundcolor red
               }
           
             }
           }until($ok2) 
           #write-host "`nComming soon" -foreground yellow
     }

     "[q|Q]"{
       $ok = $true
     }

     default {
       write-host "Invalid Input!!" -foregroundcolor Red    
     }#end default		
  }#end top menu switch
  pause
}until ($ok)