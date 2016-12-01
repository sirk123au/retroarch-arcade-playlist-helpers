;### AUTOHOTKEY SCRIPT TO GENERATE CURATED MAME PLAYLISTS AND THUMBNAILS FOR RETROARCH
;### Based on prior work by libretro forum users roldmort, Tetsuya79, Alexandra, and markwkidd

;---------------------------------------------------------------------------------------------------------
#NoEnv  					;### Recommended for performance and compatibility with future AutoHotkey releases.
#Warn  						;### Enable warnings to assist with detecting common errors.
SendMode Input  				;### Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir% 			;### Ensures a consistent starting directory.
SetBatchLines -1				;### Don't yield CPU to other processes. 
						;### comment the SetBatchLines command out if there are CPU utilization issues
;---------------------------------------------------------------------------------------------------------

;### INITIALIZE GLOBAL VARIABLES
;### Leave blank to prompt for all values in GUI
;### Enter values in the script to serve as defaults in GUI

dat = 
;### local path to a MAME ROM database file
;### The most recent MAME DAT can be found here  http://www.emulab.it/rommanager/datfiles.php
;### DAT files for current and past MAME releases are available at http://www.progettosnaps.net/dats/

base_rom_directory = 
;### Full path of the base MAME ROMs folder. 
;### This script will look for subfolders inside this base ROM directory that correspond to
;### the playlist name(s) below. For example, if individual ROM folders are located within 
;### folders called C:\Emulation\roms\Fighting and C:\Emulation\roms\Driving,
;### the base_rom_directory would be c:\Emulation\roms
;### If the ROM files are located in C:\Emulation\roms\MAME, then the base_rom_directory would
;### be c:\Emulation

use_alternate_rom_path = 0
;### Trigger to write a different base ROM path into the playlist than is used by AHK

alternate_rom_path = /storage/roms
;### Location of the primary ROM folder for the RetroArch installation where the playlist(s)
;### will be used.

playlist_names = 
;### Name of desired playlist(s) with no extension; this determines name of playlist file and name of related 
;### subfolder in RetroArch's thumbnails folder. Ex: Fighting   Ex: Driving   Ex: BeatEmUp
;### For instance, Fighting would result in a Fighting.lpl in \playlists and a subfolder called
;### \Fighting in \thumbnails

local_art_source = 
;### Path to the source thumbnails folder on the local machine. Leave blank if not using a local thumbnail source.
;### Example: C:\Emulation\libretro-thumbnails\MAME

RAPath = 
;### Full path of Retroarch root folder
;### Example: C:\Emulation\RetroArch

attempt_thumbnail_download = 0
;### Attempt to download missing thumbnails from the RetroArch server. Default is set in the GUI code

unix_filesystem = 0
;### Use forward slashes instead of backslashes in playlist paths. Use `n rather than `r`n for end of line.
;### Default is set in the GUI code

path_delimiter = \
;### Character to deliminate paths in the generated playlists. Defaults to backslash for use with Windows hosts

playlist_eol = `r`n
;### End of line character. Defaults to `r`n for use with Windows hosts

RA_core_path = DETECT
;### Optional parameter to manually specify the location of a RetroArch core. Set to DETECT by default.

;---------------------------------------------------------------------------------------------------------

PathEntryGUI()	;### Prompt the user to enter the configuration 
WinWaitClose

if(unix_filesystem) {
	path_delimiter = /
	playlist_eol = `n
} else
{
	path_delimiter = \
	playlist_eol = `r`n
}

;## Remove any trailing forward or back slashes from user-provided paths
StripFinalSlash(RAPath)
StripFinalSlash(base_rom_directory)
if (local_art_source <> "")
{
	StripFinalSlash(local_art_source)
}


;### Exit if these files/folders don't exist or are set incorrectly
if !FileExist(dat)
{
	MsgBox,,Path Error!, DAT file not found:`n%dat%`n`nExiting.
	ExitApp
} else if !FileExist(base_rom_directory)
{
	MsgBox,,Path Error!, Base ROM directory does not exist:`n%base_rom_directory%`n`nExiting.
	ExitApp
} else if !FileExist(RAPath)
{
	MsgBox,,Path Error!, RetroArch directory does not exist:`n%RAPath%`n`nExiting.
	ExitApp
} else if ((local_art_source <> "") and !FileExist(local_art_source))
{
	MsgBox,,Path Error!, Local art directory was specified but does not exist:`n%local_art_source%`n`nExiting.
}

Loop, Parse, playlist_names, :,		;### Parse and check the list of playlist names, using colon char as the delimiter
{
	if !FileExist(base_rom_directory . "\" . A_LoopField)
	{
		MsgBox,,Path Error!, Playlist source folder not found:`n%base_rom_directory%\%A_Loopfield%`n`nExiting.
		ExitApp
	}
}

MsgBox,,AHK RetroArch Arcade Playlist Generator,Click OK to begin playlist generation. Another window will open when the process is complete.

FileCreateDir, %RAPath%\playlists					;### create playlists subfolder if it doesn't exist
FileCreateDir, %RAPath%\thumbnails					;### create main thumbnails folder if it doesn't exist

FileRead, dat, %dat%
slimdat := 								;### Initialize to eliminate warning

FileRead, datcontents, %dat%
Loop, Parse, datcontents, `n, `r
	If (InStr(A_LoopField, "<game name=") or InStr(A_LoopField, "<description>"))  ;### only keep relevant lines
		slimdat .= A_LoopField "`n"
		
datcontents := slimdat

Loop, Parse, playlist_names, :,		;### Parse and process the list of playlist names, using colon char as the delimiter
{
	Generator(A_LoopField)
}

MsgBox,,AHK RetroArch Arcade Playlist Generator,Playlist generation complete. Click OK to exit.
ExitApp		;### End main function


;---------------------------------------------------------------------------------------------------------

Generator(individual_playlist)
{

	global dat
	global base_rom_directory
	global local_art_source
	global RAPath
	global attempt_thumbnail_download
	global path_delimiter
	global RA_core_path
	global playlist_eol
	global use_alternate_rom_path
	global alternate_rom_path

	playlist_filename = %RAPath%\playlists\%individual_playlist%.lpl
	FileDelete, %playlist_filename%      				  		;### clear existing playlist file
	playlist_file := FileOpen(playlist_filename,"a")			;### Creates new playlist in 'append' mode

	FileCreateDir, %RAPath%\thumbnails\%individual_playlist%\Named_Snaps		;### create thumbnail subfolder
	FileCreateDir, %RAPath%\thumbnails\%individual_playlist%\Named_Titles		;### create thumbnail subfolder
	FileCreateDir, %RAPath%\thumbnails\%individual_playlist%\Named_Boxarts		;### create thumbnail subfolder

	ROMFileList =  			;### Initialize to be blank.
	Loop, Files, %base_rom_directory%\%individual_playlist%\*.zip 
	{
	    ROMFileList = %ROMFileList%%A_LoopFileName%`n	;### store list of ROMs in memory for searching
	}
	Sort, ROMFileList

	posi = 1

	Loop, Parse, ROMFileList, `n, `r
	{
		if A_LoopField =
			continue						;### continue on blank line (sometimes the last line in list)
		SplitPath, A_LoopField,,,,filename				;### trim the file extension from the name

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
		{
			continue
		} else
		{
			fancyname := datname1
		}
		
		if(use_alternate_rom_path) 
		{
			playlist_entry_rom_path = %alternate_rom_path%%path_delimiter%%individual_playlist%%path_delimiter%%filename%.zip
		} else
		{
			playlist_entry_rom_path = %base_rom_directory%%path_delimiter%%individual_playlist%%path_delimiter%%filename%.zip
		}

		playlist_entry = %playlist_entry_rom_path%%playlist_eol%%datname1%%playlist_eol%%RA_core_path%%playlist_eol%DETECT`r`nDETECT%playlist_eol%%individual_playlist%.lpl%playlist_eol%

	;	MsgBox, %playlist_entry% 			;### for troubleshooting
		
		playlist_file.Write(playlist_entry)

		sanitized_name := character_sanitize(fancyname)	;### thumbnail filenames must be a 'sanitized' version of the game name
		
		;### use local copy of libretro MAME thumbnail database
		;### and fall back on libretro thumbnail server if selected in GUI
		local_image_path = %RAPath%\thumbnails\%individual_playlist%\Named_Titles\%sanitized_name%.png
		source_image_path = %local_art_source%\Named_Snaps\%sanitized_name%.png
		if !FileExist(local_image_path) 
		{
			if FileExist(source_image_path) ;### copy from local repository if found
			{
				FileCopy, %source_image_path%, %local_image_path%
			}
			else if(attempt_thumbnail_download)							;### try to retrieve from libretro thumb server
			{
				DownloadFile("http://thumbnails.libretro.com/MAME/Named_Titles/" . fancyname . ".png", local_image_path)
			}
		}
		
		local_image_path = %RAPath%\thumbnails\%individual_playlist%\Named_Snaps\%sanitized_name%.png
		source_image_path = %local_art_source%\Named_Titles\%sanitized_name%.png
		if !FileExist(local_image_path) 
		{
			if FileExist(source_image_path) ;### copy from local repository if found
			{
				FileCopy, %source_image_path%, %local_image_path%
			}
			else if(attempt_thumbnail_download)							;### try to retrieve from libretro thumb server
			{
				DownloadFile("http://thumbnails.libretro.com/MAME/Named_Snaps/" . fancyname . ".png", local_image_path)
			}
		}
		
		local_image_path = %RAPath%\thumbnails\%individual_playlist%\Named_Boxarts\%sanitized_name%.png
		source_image_path = %local_art_source%\Named_Boxarts\%sanitized_name%.png
		if !FileExist(local_image_path) 
		{
			if FileExist(source_image_path) ;### copy from local repository if found
			{	
				FileCopy, %source_image_path%, %local_image_path%
			}
			else if(attempt_thumbnail_download)							;### try to retrieve from libretro thumb server
			{
				DownloadFile("http://thumbnails.libretro.com/MAME/Named_Boxarts/" . fancyname . ".png", local_image_path)		
			}
		}
	}

	playlist_file.Close()					;## close and flush the new playlist file
}


;---------------------------------------------------------------------------------------------------------

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

;---------------------------------------------------------------------------------------------------------

PathEntryGUI()
{
	global dat
	global base_rom_directory
	global playlist_names
	global local_art_source
	global RAPath
	global attempt_thumbnail_download
	global unix_filesystem
	global RA_core_path
	global use_alternate_rom_path
	global alternate_rom_path

	DetectHiddenWindows, Off

	gui, path_entry_window: new
	gui,Default
	gui,+LastFound
	gui, font, s10 w400, Verdana

	gui, font, s12 w700, Verdana
	gui, add, groupbox, w580 r24,Configure Paths

	;### DAT file location
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 ym30 w560, Arcade DAT Location`n
	gui, font, normal s10 w400, Verdana
	gui, add, edit, w400 xm12 y+0 vdat, %dat%

	;### ROM storage location
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+14 w560, Base ROM Directory - Ex: C:\roms
	gui, font, s10 w400, Verdana
	gui, add, text, xm12 y+0 w560, The script will look for subfolders inside this base ROM directory that correspond to the playlist name(s) below.
	gui, add, edit, w400 xm12 y+4 vbase_rom_directory, %base_rom_directory%

	Gui, Add, Checkbox, xm12 y+10 vuse_alternate_rom_path, Use alternate base ROM directory in generated playlist file.`nHelpful for OS X and Linux.
	gui, add, edit, w400 xm12 y+0 valternate_rom_path, %alternate_rom_path%


	;### Playlist names
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+14  w560, Playlist Name
	gui, font, s10 w400, Verdana
	gui, add, text, xm12 y+0 w560, This should be the name of the desired playlist(s) with no extension. This should match the names of the individual ROM folders being used as the source for the playlists.
	gui, add, edit, w400 xm12 y+0 vplaylist_names, %playlist_names%
	gui, font, s10 w400 italic, Verdana
	gui, add, text, xm12 y+0 w560, Note: Multiple playlists may be generated at once. Separate multiple playlist names with a colon (:) character, such as Fighting:Beat 'em Up:Driving
	gui, font, normal s10 w400, Verdana
	Gui, Add, Checkbox, xm12 y+12 vunix_filesystem, Create playlist for use with an OS X or Linux RetroArch installation.`nUses forward slashes for paths and ``n for line ends.

	;### Thumbnail settings
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+14  w560, Path to unzipped libretro thumbnail pack (optional)
	gui, add, edit, w400 xm12 y+0  vlocal_art_source, %local_art_source%
	gui, font, normal s10 w700, Verdana
	Gui, Add, Checkbox, xm12 y+8 vattempt_thumbnail_download, Download missing thumbnails from the RetroArch server

	;### RetroArch path
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+14  w560, RetroArch path - Ex: C:\RetroArch
	gui, font, normal s10 w400, Verdana
	gui, add, edit, w400 xm12 y+0  vRAPath, %RAPath%

	;### Manual RetroArch core path location
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+14  w560, Direct path to RetroArch core for generated playlists
	gui, font, normal s10 w400, Verdana
	gui, add, text, xm12 y+0  w560, Optional. Defaults to 'DETECT'
	gui, add, edit, w400 xm12 y+0  vRA_core_path, %RA_core_path%

	;### Buttons
	gui, font, s10 w700, Verdana
	gui, add, button, w100 xp+240 y+14 gDone, Generate
	gui, add, button, w100 xp+120 yp gExit, Exit

	gui, show, w600, AHK RetroArch Arcade Playlist Generator
	return WinExist()

	Done:
	{
		gui,submit,nohide
		gui,destroy
		return
	}

	path_entry_windowGuiClose:
	Exit:
	{
		Gui path_entry_window:destroy
		ExitApp
	}
}

;---------------------------------------------------------------------------------------------------------
StripFinalSlash(ByRef source_path)
{
	last_char = SubStr(source_path,0,1)

	if ((last_char == "\") or (last_char == "/"))
	{
		StringTrimRight, source_path, source_path, 1
	}
	return
}

;---------------------------------------------------------------------------------------------------------

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
