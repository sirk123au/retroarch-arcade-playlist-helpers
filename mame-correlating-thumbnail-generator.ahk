;### AUTOHOTKEY SCRIPT TO IMPORT BOXART FOR A PLAYLIST

;---------------------------------------------------------------------------------------------------------
#NoEnv  						; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  							; Enable warnings to assist with detecting common errors.
SendMode Input  				; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  	; Ensures a consistent starting directory.
;---------------------------------------------------------------------------------------------------------

;### SETUP: ADD YOUR PATHS HERE

artsource = D:\Emulation\Original ROM Sets\Atari 2600 - Rom Hunter V11 TZ\snapshots
;### Path to the source thumbnails folder on the local machine
;### DO NOT TO INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example: C:\MAME 0.78 images\titles

processed = D:\Emulation\Original ROM Sets\Atari 2600 - Rom Hunter V11 TZ\snapshots-processed
;### NOTE: THIS FOLDER MUST EXIST BEFORE THE SCRIPT IS EXECUTED
;### Path to the destination thumbnail folder on the local machine
;### DO NOT TO INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example C:\MAME 0.78 images\Named_Titles

play = Atari - 2600.lpl
;### Path to the local copy of the Lakka playlist file, including filename
;### DO NOT TO INCLUDE A CLOSING SLASH AT THE END OF THE PATH 
;### Example 1: C:\MAME 0.78 Non-Merged\MAME.lpl

if !FileExist(play) or !FileExist(artsource) or !FileExist(processed)
 return 	;### If any of these files and folders desn't exist, exit the script

;### Delete old 'ummatched' log file if it exists 
FileDelete, Unmatched Thumbnails - %play%.log

forceUnixPath = :/			;### For an ugly fix later

c = 2
Loop, Read, %play%
{
if (a_index == c-1)        			;rom file path line
    filepath := A_LoopReadLine  
else if (a_index == c)            	;rom name line
	{
	name := A_LoopReadLine 
	
	unixpath := forceUnixPath . filepath
	SplitPath, unixpath, , , , OutNameNoExt
	
    ifexist %artsource%\%OutNameNoExt%.png
	{
		FileCopy, %artsource%\%OutNameNoExt%.png, %processed%`\%name%.png , 1
	} 
	else
	{
		FileAppend, Missing Source: %artsource%\%OutNameNoExt%.png `nDestination: %processed%\%name%.png`n`n, Unmatched Thumbnails - %play%.log  		 ;for error checking
	}
    c := c + 6
    }
}
