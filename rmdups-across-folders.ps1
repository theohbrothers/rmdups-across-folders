﻿############### configure script settings ##########
 # Absolute path to directory where duplicates might exist. May contain trailing slash. Folders paths only.
$startingdir = "D:\duplicatesfolder" 

# The name of the directory name where duplicates will be moved. Cannot contain the following characters:/ \ : * ? < > |
# NOTE: only used when mode == 1
$dupdir = "!dup" 


# 0 - list duplicates only. will not move or delete duplicates.  
# 1 - delete files to recycle bin.
$mode = 0

# log the duplicates for reference (duplicates.log). Log file will be created in same directory as powershell script.
# 0 - log the duplicates to file.
# 1 - do not log the duplicates to file
$output = 1

# 0 - turn off debugging.
# 1 - turn on debugging. 
$debug = 0
############################################################# 
# Get script directory, set as cd
$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
Set-Location $scriptDir
Write-Host "Script directory: $scriptDir" -ForegroundColor Green

# Check for write permissions in script dir
Try { [io.file]::OpenWrite('output.txt').close() }
 Catch { Write-Warning "Script directory has to be writeable for logging the search session to output.txt for your review $outputfile" }

# start transcript
if($output -eq 1) {
$ErrorActionPreference="SilentlyContinue"
Stop-Transcript | out-null
$ErrorActionPreference = "Continue"
Start-Transcript -path output.txt -append
}

# Check parameters for invalid characters.
if(!$(Test-Path $startingdir -PathType Container)) {
    Write-Host 'Invalid starting directory! Must be a folder. ' -ForegroundColor Yellow
    pause; exit
}elseif ($startingdir -match '[\*\"\?\<\>\|]'){
    Write-Host 'Invalid starting directory! May not contain characters: : * ? < > | ' -ForegroundColor Yellow
    pause; exit
}elseif ($dupdir -match '[\/\\\:\*\"\?\<\>\|]'){
    Write-Host 'Invalid duplicates temp directory! May not contain characters: / \ : * ? < > | ' -ForegroundColor Yellow
    pause; exit
}elseif(($mode -gt 1) -or ($mode -lt 0)) { 
    Write-Host "Invalid mode! May be between 0 and 2. `n0 - list only.   `n1 - move duped files to $dupdir that will be created.  `n2 - delete files to recycle bin." -ForegroundColor Yellow
    pause; exit
}elseif(($output -gt 1) -or ($output -lt 0)) { 
    Write-Host "Invalid output mode! May be between 0 and 1. `n0 - log the duplicates to file.   `n1 - do not log the duplicates to file" -ForegroundColor Yellow
    pause; exit
}elseif(($debug -gt 1) -or ($debug -lt 0)) { 
    Write-Host "Invalid debug mode! May be between 0 and 1. `n0 - turn off debugging.   `n1 - turn on debugging." -ForegroundColor Yellow
    pause; exit
}
# Show configuration options to user
Write-Host "Checking configuration options...Configuation options are valid: `n`t`$startingdir: $startingdir `n`t`$dupdir: $dupdir `n`t`$mode:$mode `n`t`$ouput: $output `n`t`$debug: $debug `n" -ForegroundColor Green

# Begin prompts to user to confirm
Write-Host "Are you sure you want to run the script?" -ForegroundColor Yellow
if($mode -eq 1) { Write-Host "`tNOTE: You have configured the script to delete files to the recycle bin." -ForegroundColor Yellow} 
Write-Host "Press x to exit the script now. Press ENTER to continue." -ForegroundColor Yellow
$continue = Read-Host; If ($continue -eq "x" -or $continue -eq "X") {exit}

# recursively store all files (files in starting directory and sub-directories and sub-sub-directories etc.)
Write-Host "`n[Retrieving all files in $startingdir and its subfolders...]" -ForegroundColor Cyan
$files = Get-ChildItem -Path $startingdir -File -Recurse | Sort-Object Folder
#if($debug){echo $files}

Write-Host "`n[Calculating files' hashes ... this might take some time ...]" -ForegroundColor Cyan
$files_hashes = @{}
# get md5 hashes for all files
foreach($f in $files) {
    $md5 = Get-FileHash $f.PSPath -Algorithm MD5 # md5 hash of this file
    $md5 = $md5.Hash 
    $files_hashes.Add($f, $md5)
}
if($debug){$str = $files_hashes | Out-String ; Write-Host $str}

$j=0 # total dup count within this directory
$cd = $_.FullName # current directory's full path
$cd_filesmapping = @{};  # declare/reset the current directory's dup store

# for each file, do
:oloop foreach($f in $files) {
    # skip over files already checked
	if($cd_filesmapping.ContainsKey($f)) {
        if($debug){Write-Host "`t>Skipping(oloop)......." $f} 
        continue oloop;
    }

    # reset stores, and get md5 for this file.
    $dups_hash = @{}; # to store matches against this file. format: dupObj => thisObj
    $f_md5 = $files_hashes.($f)
        
    # against this file, search through all files for dups
	:iloop foreach($_ in $files) {          
		# skip over dups alrdy stored in hash
		if($cd_filesmapping.ContainsKey($_)) {if($debug){Write-Host "`t>Skipping(iloop)......." $_} continue iloop}
        
        # get md5 for file to be compared with
        $_md5 = $files_hashes.($_)
        if($debug){Write-Host " - f.Name:" $f.Name "`t _Name" $_.Name}
        if($debug){Write-Host " - f.BaseName:" $f.BaseName "`t _BaseName" $_.BaseName}
        if($debug){Write-Host " - f md5:" $f_md5.Hash "`t _md5:" $_md5.Hash}

        # a dup is: same file contents (hash), same size, within the same container folder.
		if(($_.Length -eq $f.Length) -and ($f_md5.Hash -eq $_md5.Hash) ) 
		{
			# store this first dup in hash
			if(!$dups_hash.ContainsKey($f)) {
				$dups_hash.add($_, $f ); # format: dupObj(key) => thisObj(value)
			}
			# store subsequent dups in hash
			if(!$dups_hash.ContainsKey($_)) {
				$dups_hash.add($_, $f ); # format: dupObj(key) => thisObj(value)
			}
			if($debug){Write-Host "`t> Match found. File comparison: `n`t`tname: $f" "`tlast modified:" $f.LastWriteTime "`tsize:" $f.Length " vs `n`t`tname:" $_ "`t`tlast modified:" $_.LastWriteTime "`tsize:" $_.Length;}
			}else {
			if($debug){Write-Host " --- not a dupe ---" }
			}
	}

	# if only 1 match found, file matched itself: no duplicates for this file. add to cd_filesmapping to mark as done, and continue with next file
	if($dups_hash.Count -eq 1) { 
		$cd_filesmapping.add($f, $f ); # format: thisObj(key) => thisObj(value)
		if($debug){Write-Host "`t>No dups, Skipping(oloop)......." $_} 
		if($debug){echo "-----#g----"}
		if($debug){echo $cd_filesmapping}
		continue oloop;
	}

	# among dups, find the file with shortest file name. This will be the main/original file.
	$f_shortestName = $f.Name; 
	$len_shortest = $f.Name.Length;
	$dups_hash.GetEnumerator() | % { 
		$len = $_.Key.ToString().Length
		if($debug){Write-Host ">key: " $_.key "key length: $len" }
		if($len -lt $len_shortest) {
			$len_shortest = $len
			$f_shortestName = $_.Key
			if($debug){Write-Host "(current) shortest string:" $len_shortest }
		}
	}

    # debug
	if($debug){echo "----#h(b4)-----"}
	if($debug){echo $dups_hash}
	if($debug){echo "----#h(af)-----"}
        
    # set main/original file name as value to all dups (All dups are mapped to the main/original file with the shortest name). then add them to cd_hash to mark as done
	foreach($key in $($dups_hash.keys)){
		$dups_hash[$key] = $f_shortestName
		# do not add global
		$cd_filesmapping.Add($key, $dups_hash[$key]) # format: dupObj(key) => oriObj(value)
	}
		
    # debug
    if($debug){echo $dups_hash}
	if($debug){echo "-----#cd----"}
	if($debug){echo $cd_filesmapping}
}

if($mode -eq 0) {
    $cd_filesmapping.GetEnumerator() | % {
        if($_.key.ToString() -ne $_.value.ToString()) { # exclude the original which has key==value
            $j++
            if ($j -eq 1) { Write-Host "`n[Mode: $mode - Listing duplicate files, and their original file] `n`tFolder: $cd" -ForegroundColor Cyan }
            if ($j -eq 1) { Write-Host "`tdup file`t`t`t`t`toriginal file`n`t----------`t`t`t`t`t--------------" }
            $f = $_.key
            $v = $_.value
            Write-Host "`t" $f.FullName "`t`t`t`t`t"   $v.FullName
        }
    }  
}elseif($mode -eq 1) {
    # delete files to recycle bin
    $cd_filesmapping.GetEnumerator() | % { 
        if($_.key.ToString() -ne $_.value.ToString()) { # exclude the original which has key==value
            $j++
            if($j -eq 1) { Write-Host "[Mode: $mode - Deleting duplicate files, keeping original file(shortest name among them)] " -ForegroundColor Cyan }
            if($j -eq 1) { Write-Host "`tdup file`t`t`t`t`toriginal file`n`t----------`t`t`t`t`t--------------" }
            $f = $_.key
            $v = $_.value
            $path = $f.FullName
            $shell = new-object -comobject "Shell.Application"
            $item = $shell.Namespace(0).ParseName("$path")
            $item.InvokeVerb("delete")
            
            Write-Host "`tDeleting:`t" $f.FullName "`t`t`t`t`tOriginal:`t"   $v.FullName
            # dont use Remove-item, it permanently deletes
            #Remove-item $falses
        }
    }
    if($j) { Write-Host "`tDeleting duplicates successful. Original files are left intact." -ForegroundColor Green }
}
# tell user no dups found throughout search
if($j -eq 0) { Write-Host "`nNo duplicate files were found" -ForegroundColor Green }
	
# show summary
$t = $files.Count # total file count within this directory
Write-Host " ---------- `n| summary | `n ---------- `n - original file count:$($t-$j) `n - duplicate file count:$j `n - total files: $t" -ForegroundColor Green


# stop transcript
if($output -eq 1) {
Stop-Transcript
}

pause

#>