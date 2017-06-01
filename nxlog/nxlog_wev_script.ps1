#Prompt the user for the amount of evtx files

[int]$amount_evtx = Read-Host -Prompt 'How Many EVTX files are we ingesting?'

#Check for Host List If found continue If not create a new one

if (Test-Path .\evtx_files.txt)
{
    "The EVTX list Exists! (evtx_files.txt). Creating nxlog.conf"
}
else 
{
    "The EVTX list is being created (evtx_files.txt)"
    get-item .\*evtx | select fullname | ft -HideTableHeaders > evtx_files.txt
    (Get-Content .\evtx_files.txt | select -skip 1) | set-content .\evtx_files.txt
    
}

#Create an nxlog.conf with the standard beginning

if (Test-Path .\nxlog.conf) {remove-item .\nxlog.conf}


#Create input entries for each evtx and append to the nxlog.conf

get-date -format g >> .\evtx_files_done.txt

for ($i=1; $i -lt $amount_evtx+1; $i++)
{
$first_line = Get-Content .\evtx_files.txt | select -first 1

"<Input in$i>
    Module		im_msvistalog
	File		$first_line
</Input>

" >> .\nxlog.conf

(Get-Content .\evtx_files.txt | select -first 1) >> .\evtx_files_done.txt

(Get-Content .\evtx_files.txt | select -skip 1) | set-content .\evtx_files.txt							
}

#Create the output entry for elastic search and append to nxlog.conf

"<Output es>
	Module	om_elasticsearch
	URL		http://IP_ADDRESS:PORT/_bulk
	FlushInterval	2
	FlushLimit	100
	# Create an index daily
	Index	strftime(`$EventTime, `"nxlog-%Y%m%d`")
	Exec	if not defined `$SourceName `$SourceName = 'unknown';
	IndexType	`$SourceName
</Output>

" >> .\nxlog.conf


#Create the route based on the amount of evtx files and append to nxlog.conf

$n1 = '<Route r>
	Path	'

for ($x=1; $x -lt $amount_evtx+1; $x++)
{
$r1 = "in$x, "
$n1 = $n1 + $r1
}
 
$s1= $n1.Substring(0,$n1.Length-2) + " => es
</Route>"

$s1 >> .\nxlog.conf

#Let the user know you are complete

"All Done! Check nxlog.conf for errors"
Write-Host "Press any key to continue ..."

$press_key = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
