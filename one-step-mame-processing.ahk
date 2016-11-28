;### AUTOHOTKEY SCRIPT TO GENERATE CURATED MAME PLAYLISTS AND THUMBNAILS FOR RETROARCH
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;---------------------------------------------------------------------------------------------------------
#NoEnv  					;### Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  						;### Enable warnings to assist with detecting common errors.
SendMode Input  			;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir% ;### Ensures a consistent starting directory.
SetBatchLines -1			;### Don't yield CPU to other processes. 
							;### comment the SetBatchLines command out if there are CPU utilization issues
;---------------------------------------------------------------------------------------------------------

;##########################################################
; SET PATHS

dat = C:\MAME Roms\~MAME - ROMs (v0.176_XML).dat
;### Example: C:\MAME Roms\~MAME - ROMs (v0.176_XML).dat
;### local path to a MAME ROM database file
;### The most recent MAME DAT can be found here  http://www.emulab.it/rommanager/datfiles.php
;### DAT files for current and past MAME releases are available at http://www.progettosnaps.net/dats/

rom_directory = C:\MAME ROMs\Fighting
;### Full path of a MAME ROMs folder. 
;### If you run this script multiple times with a different folder set here each time you can make 
;### multiple playlists. For ex., make folders for each genre of ROMs, populate them, and then run 
;### this script on each folder. Result: One RA playlist for each folder.

playlist_name = Fighting
;### Name of playlist, no extension; this determines name of playlist file and name of related 
;### subfolder in RetroArch's thumbnails folder. Ex: Fighting   Ex: Driving   Ex: BeatEmUp
;### For instance, Fighting would result in a Fighting.lpl in \playlists and a subfolder called
;### \Fighting in \thumbnails
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THIS PATH

;### TIP: RA displays playlists in alphanumeric order. If you'd like to control the ordering,
;### prefix each playlist with a number. Ex: 01_Fighting  02_BeatEmUp  03_Action
;### This has the added bonus of making your icon image filenames conveniently cluster together.

local_art_source = C:\libretro-thumbnails\MAME
;### Path to the source thumbnails folder on the local machine
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THIS PATH
;### Example: C:\MAME 0.78 images\titles

RAPath = C:\RetroArch
;### Full path of Retroarch root folder  Ex: C:\Emulation\RetroArch
;### DO NOT INCLUDE A CLOSING SLASH AT THE END OF THIS PATH

;##########################################################

if !FileExist(dat) or !FileExist(rom_directory) or !FileExist(RAPath)
	return 			;### Exit if any of these files and folders desn't exist

FileCreateDir, %RAPath%\playlists		;### create playlists folder if it doesn't exist

playlist_filename = %RAPath%\playlists\%playlist_name%.lpl
FileSetAttrib, -R, %playlist_filename% 	;### remove read-only attrib from existing playlist file
FileDelete, %playlist_filename%        	;### clear existing playlist file
playlist_file := FileOpen(playlist_filename,"a")		;### Creates new playlist in 'append' mode

FileCreateDir, %RAPath%\thumbnails		;### create main thumbnails folder
FileCreateDir, %RAPath%\thumbnails\%playlist_name%\Named_Snaps		;### create thumbnail folder
FileCreateDir, %RAPath%\thumbnails\%playlist_name%\Named_Titles		;### create thumbnail folder
FileCreateDir, %RAPath%\thumbnails\%playlist_name%\Named_Boxarts	;### create thumbnail folder

FileRead, dat, %dat%
slimdat := 								;### Initialize to eliminate warning

FileRead, datcontents, %dat%
Loop, Parse, datcontents, `n, `r
	If (InStr(A_LoopField, "<game name=") or InStr(A_LoopField, "<description>"))  ;### only keep relevant lines
		slimdat .= A_LoopField "`n"
		
datcontents := slimdat

ROMFileList :=  ; Initialize to be blank.
Loop, Files, %rom_directory%\*.zip 
{
    ROMFileList = %ROMFileList%%A_LoopFileName%`n	;### store list of ROMs in memory for searching
}
Sort, ROMFileList

posi = 1

Loop, Parse, ROMFileList, `n, `r
{
	if A_LoopField =
		continue						;### continue on blank line (sometimes the last line in list)
	SplitPath, A_LoopField,,,,filename	;### trim the file extension from the name

	filter1 = <game name=.%filename%. (isbios|isdevice)
	if RegExMatch(dat, filter1)
		continue						;### skip if the file listed as a BIOS or device in the dat

;	;### find the filename's position in datcontents
;	posi := InStr(datcontents, "game name=""" filename """",false,posi)	
;	if !posi
;		posi := InStr(datcontents, "game name=""" filename """")
;	if !posi
;		continue

	needle = <game name=.%filename%.(?:| ismechanical=.*)(?:| sourcefile=.*)(?:| cloneof=.*)(?:|  romof=.*)>\R\s*<description>(.*)</description>
	
	;### start regex search from filename position		
    RegExMatch(dat, needle, datname, posi)
					
	if !datname1
		continue
	fancyname := character_sanitize(datname1)

	playlist_entry = %rom_directory%\%filename%.zip`r`n%fancyname%`r`nDETECT`r`nDETECT`r`nDETECT`r`n%playlist_name%.lpl`r`n

;	MsgBox, %playlist_entry% 			;### for troubleshooting
	
	playlist_file.Write(playlist_entry)
	
	;### use local copy of libretro MAME thumbnail database
	;### and fall back on libretro thumbnail server
	
	local_image_path = %RAPath%\thumbnails\%playlist_name%\Named_Titles\%fancyname%.png
	source_image_path = %local_art_source%\Named_Snaps\%fancyname%.png
	if !FileExist(local_image_path) 
	{
		if FileExist(source_image_path) ;### copy from local repository if found
			FileCopy, %source_image_path%, %local_image_path%
		else							;### try to retrieve from libretro thumb server
			DownloadFile("http://thumbnails.libretro.com/MAME/Named_Titles/" . fancyname . ".png", local_image_path, True, True)
	}
	
	local_image_path = %RAPath%\thumbnails\%playlist_name%\Named_Snaps\%fancyname%.png
	source_image_path = %local_art_source%\Named_Titles\%fancyname%.png
	if !FileExist(local_image_path) 
	{
		if FileExist(source_image_path) ;### copy from local repository if found
			FileCopy, %source_image_path%, %local_image_path%
		else							;### try to retrieve from libretro thumb server
			DownloadFile("http://thumbnails.libretro.com/MAME/Named_Snaps/" . fancyname . ".png", local_image_path, True, True)
	}
	
	local_image_path = %RAPath%\thumbnails\%playlist_name%\Named_Boxarts\%fancyname%.png
	source_image_path = %local_art_source%\Named_Boxarts\%fancyname%.png
	if !FileExist(local_image_path) 
	{
		if FileExist(source_image_path) ;### copy from local repository if found
			FileCopy, %source_image_path%, %local_image_path%
		else							;### try to retrieve from libretro thumb server
			DownloadFile("http://thumbnails.libretro.com/MAME/Named_Boxarts/" . fancyname . ".png", local_image_path, True, True)		
	}
}

playlist_file.Close()					;## close and flush the new playlist file
FileSetAttrib, +R, %playlist_filename%	;## add read-only attrib to playlist file

character_sanitize(x) {					;## fix chars for multi-platform use per No-Intro standard
	x := StrReplace(x, "&apos;", "'")
	x := StrReplace(x, "&amp;", "_")
	x := StrReplace(x, "&", "_")
	x := StrReplace(x, "\", "_")
	x := StrReplace(x, "/", "_")
	x := StrReplace(x, "?", "_")
	x := StrReplace(x, ":", "_")
	x := StrReplace(x, "``", "_")	
	x := StrReplace(x, "<", "_")
	x := StrReplace(x, ">", "_")
	x := StrReplace(x, "*", "_")
	x := StrReplace(x, "|", "_")
	return x
}

;### DownloadFile function by Bruttosozialprodukt with modifications
DownloadFile(UrlToFile, SaveFileAs, Overwrite := True, UseProgressBar := True) {
    ;Check if the file already exists and if we must not overwrite it
      If (!Overwrite && FileExist(SaveFileAs))
          Return
    ;Check if the user wants a progressbar
      If (UseProgressBar) {
			LastSize = 
			LastSizeTick = 
		;Initialize the WinHttpRequest Object
            WebRequest := ComObjCreate("WinHttp.WinHttpRequest.5.1")
          ;Download the headers
            WebRequest.Open("HEAD", UrlToFile)
            WebRequest.Send()
			WebRequest.WaitForResponse(30)			;### possible slowdown point for with connectivity
			
			if (WebRequest.Status() == 404)			;### 404 error
				return
				
          ;Store the header which holds the file size in a variable:
            FinalSize := WebRequest.GetResponseHeader("Content-Length")
          ;Create the progressbar and the timer
            Progress, H80, , Downloading..., %UrlToFile%
            SetTimer, __UpdateProgressBar, 100
      }
    ;Download the file
      UrlDownloadToFile, %UrlToFile%, %SaveFileAs%
    ;Remove the timer and the progressbar because the download has finished
      If (UseProgressBar) {
          Progress, Off
          SetTimer, __UpdateProgressBar, Off
      }
    Return

    ;The label that updates the progressbar
      __UpdateProgressBar:
          ;Get the current filesize and tick
            CurrentSize := FileOpen(SaveFileAs, "r").Length ;FileGetSize wouldn't return reliable results
            CurrentSizeTick := A_TickCount
          ;Calculate the downloadspeed
            Speed := Round((CurrentSize/1024-LastSize/1024)/((CurrentSizeTick-LastSizeTick)/1000)) . " Kb/s"
          ;Save the current filesize and tick for the next time
            LastSizeTick := CurrentSizeTick
            LastSize := FileOpen(SaveFileAs, "r").Length
          ;Calculate percent done
            PercentDone := Round(CurrentSize/FinalSize*100)
          ;Update the ProgressBar
            Progress, %PercentDone%, %SaveFileAs%, %PercentDone%`% (%Speed%), Downloading thumbnails
      Return
}
