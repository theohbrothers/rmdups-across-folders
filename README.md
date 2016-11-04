# rmdups-across-folders - Documentation
A simple Powershell script that can be used to list / remove duplicate files distributed in various folders on Windows systems. 
- It performs a search of a folder and all subfolders, finding duplicate files distributed across those folders, and depending on the mode, can either list, or delete (to recycle bin) those duplicate files.
- NOTE: It's duplicate search scope is <b>across-folders</b> rather than within-folder. If you prefer a within-folder scope of search for duplicates, use <a href="https://github.com/theohbrothers/rmdups">this instead</a>.  

## Features:
- Searches through a folder and all decendent folders (i.e. subfolders) for duplicates that exist among all folders. 
	- The process is as follows: It gets a list of all files and nested files (in subfolders and sub-sub-folders etc.), and find duplicates among the list.
	- e.g. <code>D:\1.txt</code>, <code>D:\child_folder\2.txt</code>, <code>D:\child_folder\grandchild_folder\3.txt</code> are identical in content and file size. The script marks this as duplicates.
- Choose a mode for one of the following:
	- list duplicates 
	- delete duplicates to the recycle bin, leaving the original file intact (shortest named file)
- Logs the entire search session (output.txt) to the script's directory for you to review any duplicates. 

## Requirements:
- Powershell v4
- Windows environment
- User with read/write/modify permissions on script and searched directories.

## Installation/usage:
- Open the <code>rmdups-across-folders.ps1</code> in your favourite text editor and configure the script settings at the top of the script (instructions are included).
- Right click on the script in explorer and select <code>Run with Powershell</code>. (should be present on Windows 7 and up)
- Alternatively, open command prompt, and run <code>Powershell .\rmdups-across-folders.ps1</code>

## NOTE:
- By default, script directory (where you run the script) needs <b>write permission</b> for session logging (output.txt). If you prefer not to, turn off session logging in script configuration.
- If using mode 1 or 2, ensure directories searched have <b>read,write,execute,modify permissions</b>.

## FAQ
Q: What is a <b>duplicate file</b>?:
- Has separate file[s] with:
	- Same file contents (file hash)
	- Same file size
	
Q: What is the <b>original file</b>?:
- A duplicate file but with the shortest name among all duplicates found.

Q: Help! I am getting an error <code>'File C:\Users\User\rmdups\rmdups.ps1 cannot be loaded because the execution of scripts is disabled on this system. Please see "get-help about_signing" for more details.'</code>
- You need to allow the execution of unverified scripts. Open Powershell as administrator, type <code>Set-ExecutionPolicy Unrestricted -Force</code> and press ENTER. Try running the script again. You can easily restore the security setting back by using <code>Set-ExecutionPolicy Undefined -Force</code>

## Background:
- Most people create duplicate files in various folders either <i>accidentally</i>, or <i>inexperiencedly</i>, or <i>obliviously</i>
	- Obliviously: For instance, you accidentally but so quickly drag and drop a folder or files to another folder that you didn't even realize
	- Inexperiencedly: You use scripts that accidentally create duplicate files e.g. <code>cp, copy</code> commands
	- Accidentally: Using CTRL+C & CTRL+V too quickly can lead to duplicate file creation if CTRL-Z is not used immediately after
