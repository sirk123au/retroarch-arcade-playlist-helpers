;### AUTOHOTKEY SCRIPT TO RENAME ARCADE THUMBNAILS FOR RETROARCH
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;---------------------------------------------------------------------------------------------------------
#NoEnv  			; Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  				; Enable warnings to assist with detecting common errors.
SendMode Input  		; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  	; Ensures a consistent starting directory.
;---------------------------------------------------------------------------------------------------------

;### SETUP: ADD YOUR PATHS HERE

artsource = C:\MAME Roms\~Snaps
;### NOTE: THIS FOLDER MUST EXIST BEFORE THE SCRIPT IS EXECUTED
;### Path to the source thumbnails folder on the local machine
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example: C:\MAME 0.78 images\titles

destinationfolder = C:\MAME Roms\~SnapsFriendly
;### NOTE: THIS FOLDER MUST EXIST BEFORE THE SCRIPT IS EXECUTED
;### Path to the destination thumbnail folder on the local machine
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THE PATH
;### Example C:\MAME 0.78 images\Named_Titles

dat = C:\MAME Roms\~MAME - ROMs (v0.176_XML).dat
;### Example: C:\MAME Roms\~MAME - ROMs (v0.176_XML).dat
;### local path to a MAME ROM database file
;### The most recent MAME DAT can be found here  http://www.emulab.it/rommanager/datfiles.php
;### DAT files for current and past MAME releases are available at http://www.progettosnaps.net/dats/

;### TIP: If you're renaming Snaps, Titles, and Boxart thumbnails, it is possible to make three copies of this script,
;### point the folder paths at the other image types, and run all at once.

if !FileExist(dat) or !FileExist(artsource) or !FileExist(destinationfolder)
	return 	;### If any of these files and folders desn't exist, exit the script

FileDelete, Unmatched Thumbnails - %dat%.log	;### Delete old 'ummatched' log file, if it exists

FileRead, datcontents, %dat%

ThumbnailFileList :=  ; Initialize to be blank.
Loop, Files, %artsource%\*.png
{
    ThumbnailFileList = %ThumbnailFileList%%A_LoopFileName%`n	;### store list of ROMs in memory for searching
}
Sort, ThumbnailFileList

rawcounter = 0
A_Loop_File_Name = 0

Loop, Parse, ThumbnailFileList, `n 
{	

	if A_LoopField = 
		continue 	;### continue on blank line (sometimes the last line in the file list)
		
	SplitPath, A_LoopField,,,,filename	 ;### trim the file extension from the name

	needle = <game name=.%filename%.(?:| ismechanical=.*)(?:| sourcefile=.*)(?:| cloneof=.*)(?:|  romof=.*)>\R\s*<description>(.*)</description>
	RegExMatch(datcontents, needle, datname)
	
	fancyname := datname1	;### extract match #1 from the RegExMatch result
	
	if !fancyname
	{
		fancyname := filename   	;### the image filename/rom name is not matched in the dat file
; 		FileAppend, Unmatched Source %artsource%\%filename%.png`r`n, %destinationfolder%\Unmatched Thumbnails.log  ;### for error checking
		continue 			;### then skip to the next image
	}
    
	;### Replace characters unsafe for cross-platform filenames with underscore, 
	;### per RetroArch thumbnail/playlist convention
	fancyname := StrReplace(fancyname, "&apos;", "'")
	fancyname := StrReplace(fancyname, "&amp;", "_")
	fancyname := StrReplace(fancyname, "&", "_")
	fancyname := StrReplace(fancyname, "\", "_")
	fancyname := StrReplace(fancyname, "/", "_")
	fancyname := StrReplace(fancyname, "?", "_")
	fancyname := StrReplace(fancyname, ":", "_")
	fancyname := StrReplace(fancyname, "<", "_")
	fancyname := StrReplace(fancyname, ">", "_")
	fancyname := StrReplace(fancyname, "*", "_")
	fancyname := StrReplace(fancyname, "|", "_")

	destinationfile := destinationfolder . "`\" . fancyname . ".png"
	FileCopy, %artsource%\%filename%.png, %destinationfile% , 1
}
