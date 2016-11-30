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
;### the playlist name below. For example, if individual ROM folders are located within 
;### folders called C:\Emulation\roms\Fighting and C:\Emulation\roms\Driving,
;### the base_rom_directory would be c:\Emulation\roms
;### If the ROM files are located in C:\Emulation\roms\MAME, then the base_rom_directory would
;### be c:\Emulation

playlist_name = MAME
;### Name of playlist, no extension; this determines name of playlist file and name of related 
;### subfolder in RetroArch's thumbnails folder. Ex: Fighting   Ex: Driving   Ex: BeatEmUp
;### For instance, Fighting would result in a Fighting.lpl in \playlists and a subfolder called
;### \Fighting in \thumbnails

local_art_source = 
;### Path to the source thumbnails folder on the local machine. Leave blank if not using a local thumbnail source.
;### Example: C:\Emulation\libretro-thumbnails\MAME

RAPath = 
;### Full path of Retroarch root folder
;### Example: C:\Emulation\RetroArch

;---------------------------------------------------------------------------------------------------------

PathEntryGUI()	;### Prompt the user to enter the configuration 
WinWaitClose

;## Remove any trailing slashes from user-provided paths
no_trailing_slash = 											;### Initialize temp variable

plitPath, RAPath,, no_trailing_slash
RAPath := no_trailing_slash
SplitPath, base_rom_directory,, no_trailing_slash
base_rom_directory := no_trailing_slash
if (local_art_source <> "")
{
	SplitPath, local_art_source,, no_trailing_slash
	local_art_source := no_trailing_slash
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

FileCreateDir, %RAPath%\playlists					;### create playlists subfolder if it doesn't exist
FileCreateDir, %RAPath%\thumbnails					;### create main thumbnails folder if it doesn't exist

FileRead, dat, %dat%
slimdat := 								;### Initialize to eliminate warning

FileRead, datcontents, %dat%
Loop, Parse, datcontents, `n, `r
	If (InStr(A_LoopField, "<game name=") or InStr(A_LoopField, "<description>"))  ;### only keep relevant lines
		slimdat .= A_LoopField "`n"
		
datcontents := slimdat


playlist_filename = %RAPath%\playlists\%playlist_name%.lpl
FileDelete, %playlist_filename%      				  	;### clear existing playlist file
playlist_file := FileOpen(playlist_filename,"a")			;### Creates new playlist in 'append' mode

FileCreateDir, %RAPath%\thumbnails\%playlist_name%\Named_Snaps		;### create thumbnail subfolder
FileCreateDir, %RAPath%\thumbnails\%playlist_name%\Named_Titles		;### create thumbnail subfolder
FileCreateDir, %RAPath%\thumbnails\%playlist_name%\Named_Boxarts	;### create thumbnail subfolder

ROMFileList :=  ; Initialize to be blank.
Loop, Files, %base_rom_directory%\%playlist_name%*.zip 
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
		continue
	fancyname := character_sanitize(datname1)

	playlist_entry = %base_rom_directory%\%playlist_name%\%filename%.zip`r`n%fancyname%`r`nDETECT`r`nDETECT`r`nDETECT`r`n%playlist_name%.lpl`r`n

;	MsgBox, %playlist_entry% 			;### for troubleshooting
	
	playlist_file.Write(playlist_entry)
	
	;### use local copy of libretro MAME thumbnail database
	;### and fall back on libretro thumbnail server
	
	local_image_path = %RAPath%\thumbnails\%playlist_name%\Named_Titles\%fancyname%.png
	source_image_path = %local_art_source%\Named_Snaps\%fancyname%.png
	if !FileExist(local_image_path) 
	{
		if FileExist(source_image_path) ;### copy from local repository if found
		{
			FileCopy, %source_image_path%, %local_image_path%
		}
		else							;### try to retrieve from libretro thumb server
		{
;			DownloadFile("http://thumbnails.libretro.com/MAME/Named_Titles/" . fancyname . ".png", local_image_path)
		}
	}
	
	local_image_path = %RAPath%\thumbnails\%playlist_name%\Named_Snaps\%fancyname%.png
	source_image_path = %local_art_source%\Named_Titles\%fancyname%.png
	if !FileExist(local_image_path) 
	{
		if FileExist(source_image_path) ;### copy from local repository if found
		{
			FileCopy, %source_image_path%, %local_image_path%
		}
		else							;### try to retrieve from libretro thumb server
		{
;			DownloadFile("http://thumbnails.libretro.com/MAME/Named_Snaps/" . fancyname . ".png", local_image_path)
		}
	}
	
	local_image_path = %RAPath%\thumbnails\%playlist_name%\Named_Boxarts\%fancyname%.png
	source_image_path = %local_art_source%\Named_Boxarts\%fancyname%.png
	if !FileExist(local_image_path) 
	{
		if FileExist(source_image_path) ;### copy from local repository if found
		{	
			FileCopy, %source_image_path%, %local_image_path%
		}
		else							;### try to retrieve from libretro thumb server
		{
;			DownloadFile("http://thumbnails.libretro.com/MAME/Named_Boxarts/" . fancyname . ".png", local_image_path)		
		}
	}
}

playlist_file.Close()					;## close and flush the new playlist file

ExitApp
;### End of main script. Functions follow.


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

PathEntryGUI()		;### Based on an AutoHotKey example by Tank
{

	global dat
	global base_rom_directory
	global playlist_name
	global local_art_source
	global RAPath

	gui, path_entry_window: new
	gui,Default
	gui,+LastFound
	gui, add, groupbox, w500 r17,Configure Paths
	gui, add, text, xm12 ym30 section, Arcade DAT Location - Ex: C:\Emulation\~MAME - ROMs (v0.176_XML).dat
	gui, add, edit, w200 xm12 yp+16 vdat, %dat%
	gui, add, text, xm12 yp+40, Base ROM Directory - Ex: C:\roms
	gui, add, edit, w200 xm12 yp+16  vbase_rom_directory, %base_rom_directory%
	gui, add, text, xm12 yp+40, Playlist Name - Ex: Fighting
	gui, add, edit, w200 xm12 yp+16 vplaylist_name,	 %playlist_name%
	gui, add, text, xm12 yp+40, Path to unzipped thumbnail pack (optional) - Ex: C:\Emulation\libretro-thumbnails\MAME
	gui, add, edit, w200 xm12 yp+16  vlocal_art_source, %local_art_source%
	gui, add, text, xm12 yp+40, RetroArch path - Ex: C:\RetroArch
	gui, add, edit, w200 xm12 yp+16  vRAPath, %RAPath%
	gui, add, button, w100 xm12 yp+40 gDone, Generate
	gui, add, button, w100 xp+120 yp  gGUIclose, Exit

	gui, show,, AHK RetroArch Arcade Playlist Generator
	return WinExist()

	Done:
	{
		gui,submit,nohide
		gui,destroy
		return
	}

	GUIescape:
	GUIcancel:
	GUIclose:
	{
		gui,destroy
		ExitApp
		return
	}
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
