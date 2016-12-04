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

global dat := ""
global dat_config_label := "Arcade DAT Path"
;### local path to a MAME ROM database file
;### Current MAME DATs: http://www.emulab.it/rommanager/datfiles.php
;### Current and past MAME DATs: http://www.progettosnaps.net/dats/

global base_rom_path := ""
global base_rom_path_label := "Base ROM Directory - Ex: C:\roms"
global base_rom_path_description := "The script will look for subfolders inside this base ROM directory that correspond to the playlist name(s) below."
;### If ROMs for curated playlists are in folders called
;### C:\roms\Fighting and C:\roms\Driving,
;### then the base ROM directory is c:\roms
;### If the ROM files are located in C:\roms\MAME,
;### then the base ROM directory is c:\roms

global use_alternate_rom_path := False			;### Default to False
;### use_alternate_rom_path: Trigger to write a different base ROM path into the playlist
;### than the base ROM path of the source ROMs.
global alternate_path_config_label := "Use alternate base ROM directory in generated playlist file.`nHelpful for OS X and Linux."
global alternate_rom_path = /storage/roms
;### alternate_rom_path: Location of the primary ROM folder for the RetroArch installation
;### where the playlist(s) will be used, if different from their current locations.

global playlist_names := ""
global playlist_names_config_label := "Name of desired playlist(s) with no file extension. This should match the names of the individual ROM folders being used as the source for the playlists."
global playlist_names_config_description := "Multiple playlists may be generated at once. Separate multiple playlist names with a colon (:) character, such as Fighting:Driving:BeatEmUp"
;### playlist_names: determines name of playlist file and name of related 
;### subfolder in RetroArch's thumbnails folder. For instance, listing Fighting
;### will result in Fighting.lpl in \playlists
;### and a new subfolder thumbnails\Fighting with thumbnails

global unix_playlist := False					;### Default to False
global unix_playlist_config_label := "Create playlist for use with OS X or Linux RetroArch installations.`nUses forward slashes for paths and ``n for line ends."

global local_art_path := ""						;### Can be left blank if not using a local thumbnail source.
global local_art_path_label := "Path to unzipped libretro thumbnail pack for MAME (optional)"

global attempt_thumbnail_download := False		;### Default to False
global attempt_thumbnail_download_label := "Download individual thumbnails from the RetroArch server"

global RA_path := ""
global RA_path_config_label := "Storage path for local RetroArch thumbnails and playlists"
;### RA_path: Full path of Retroarch root folder. Example: C:\Emulation\RetroArch

global RA_core_path := "DETECT"
global RA_core_path_label := "Direct path to libretro core for generated playlists. Set to DETECT by default."

;---------------------------------------------------------------------------------------------------------

GatherConfigData:
PathEntryGUI()	;### Prompt the user to enter the configuration 
WinWaitClose

global path_delimiter := "\"
global playlist_eol := "`r`n"

if(unix_playlist) {
	path_delimiter = /
	playlist_eol = `n
} else {
	path_delimiter = \
	playlist_eol = `r`n
}

;## Remove any trailing forward or back slashes from user-provided paths
StripFinalSlash(RA_path)
StripFinalSlash(base_rom_path)
if (local_art_path <> "")
{
	StripFinalSlash(local_art_path)
}


;### Exit if these files/folders don't exist or are set incorrectly
if !FileExist(dat)
{
	MsgBox,,Path Error!, DAT file not found:`n%dat%
	Goto, GatherConfigData
} else if !FileExist(base_rom_path) {
	MsgBox,,Path Error!, Base ROM directory does not exist:`n%base_rom_path%
	Goto, GatherConfigData
} else if !FileExist(RA_path) {
	MsgBox,,Path Error!, RetroArch directory does not exist:`n%RA_path%
	Goto, GatherConfigData
} else if ((local_art_path <> "") and !FileExist(local_art_path)) {
	MsgBox,,Path Error!, Local art directory was specified but does not exist:`n%local_art_path%
	Goto, GatherConfigData
}

Loop, Parse, playlist_names, :,		;### Parse and check the list of playlist names, using colon char as the delimiter
{
	if !FileExist(base_rom_path . "\" . A_LoopField)
	{
		MsgBox,,Path Error!, Playlist source folder not found:`n%base_rom_path%\%A_Loopfield%
		Goto, GatherConfigData
	}
}

MsgBox,,AHK RetroArch Arcade Playlist Generator,Click OK to begin playlist generation. Another window will open when the process is complete.

FileCreateDir, %RA_path%\playlists					;### create playlists subfolder if it doesn't exist
FileCreateDir, %RA_path%\thumbnails					;### create main thumbnails folder if it doesn't exist

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

	playlist_filename = %RA_path%\playlists\%individual_playlist%.lpl
	FileDelete, %playlist_filename%      				  		;### clear existing playlist file
	playlist_file := FileOpen(playlist_filename,"a")			;### Creates new playlist in 'append' mode

	FileCreateDir, %RA_path%\thumbnails\%individual_playlist%\Named_Snaps		;### create thumbnail subfolder
	FileCreateDir, %RA_path%\thumbnails\%individual_playlist%\Named_Titles		;### create thumbnail subfolder
	FileCreateDir, %RA_path%\thumbnails\%individual_playlist%\Named_Boxarts		;### create thumbnail subfolder

	ROMFileList =  			;### Initialize to be blank.
	Loop, Files, %base_rom_path%\%individual_playlist%\*.zip 
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
		} else {
			fancyname := datname1
			fancyname := StrReplace(fancyname, "&apos;", "'")	;### remove any URL encoded entities in the game name
			fancyname := StrReplace(fancyname, "&amp;", "_")
		}
		
		if(use_alternate_rom_path) 
		{
			playlist_entry_rom_path = %alternate_rom_path%%path_delimiter%%individual_playlist%%path_delimiter%%filename%.zip
		} else {
			playlist_entry_rom_path = %base_rom_path%%path_delimiter%%individual_playlist%%path_delimiter%%filename%.zip
		}

		playlist_entry = %playlist_entry_rom_path%%playlist_eol%%datname1%%playlist_eol%%RA_core_path%%playlist_eol%DETECT`r`nDETECT%playlist_eol%%individual_playlist%.lpl%playlist_eol%

	;	MsgBox, %playlist_entry% 			;### for troubleshooting
		
		playlist_file.Write(playlist_entry)

		sanitized_name := character_sanitize(fancyname)	;### thumbnail filenames must be a 'sanitized' version of the game name
		
		;### use local copy of libretro MAME thumbnail database
		;### and fall back on libretro thumbnail server if selected in GUI
		local_image_path = %RA_path%\thumbnails\%individual_playlist%\Named_Titles\%sanitized_name%.png
		source_image_path = %local_art_path%\Named_Snaps\%sanitized_name%.png
		if !FileExist(local_image_path) 
		{
			if FileExist(source_image_path) ;### copy from local repository if found
			{
				FileCopy, %source_image_path%, %local_image_path%
			} else if(attempt_thumbnail_download) {
				DownloadFile("http://thumbnails.libretro.com/MAME/Named_Titles/" . fancyname . ".png", local_image_path)
			}
		}
		
		local_image_path = %RA_path%\thumbnails\%individual_playlist%\Named_Snaps\%sanitized_name%.png
		source_image_path = %local_art_path%\Named_Titles\%sanitized_name%.png
		if !FileExist(local_image_path) 
		{
			if FileExist(source_image_path) ;### copy from local repository if found
			{
				FileCopy, %source_image_path%, %local_image_path%
			} else if(attempt_thumbnail_download){
				DownloadFile("http://thumbnails.libretro.com/MAME/Named_Snaps/" . fancyname . ".png", local_image_path)
			}
		}
		
		local_image_path = %RA_path%\thumbnails\%individual_playlist%\Named_Boxarts\%sanitized_name%.png
		source_image_path = %local_art_path%\Named_Boxarts\%sanitized_name%.png
		if !FileExist(local_image_path) 
		{
			if FileExist(source_image_path) ;### copy from local repository if found
			{	
				FileCopy, %source_image_path%, %local_image_path%
			} else if(attempt_thumbnail_download) {
				DownloadFile("http://thumbnails.libretro.com/MAME/Named_Boxarts/" . fancyname . ".png", local_image_path)		
			}
		}
	}

	playlist_file.Close()					;## close and flush the new playlist file
}


;---------------------------------------------------------------------------------------------------------

character_sanitize(x) {					;## fix chars for multi-platform use per No-Intro standard
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

	DetectHiddenWindows, Off

	gui, path_entry_window: new
	gui,Default
	gui,+LastFound
	gui, font, s10 w400, Verdana

	gui, font, s12 w700, Verdana
	gui, add, groupbox, w580 r23,Configure Paths

	;### DAT file location
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 ym30 w560, %dat_config_label%
	gui, font, normal s10 w400, Verdana
	gui, add, edit, w400 xm12 y+0 vdat, %dat%

	;### ROM storage location
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+12 w560, %base_rom_path_label%
	gui, font, s10 w400, Verdana
	gui, add, text, xm12 y+0 w560, %base_rom_path_description%
	gui, add, edit, w400 xm12 y+4 vbase_rom_path, %base_rom_path%

	gui, add, text, xm12 y+10 w300 h1 0x7
	if(use_alternate_rom_path) {		;### respect the default set at the top of the script
		gui, Add, Checkbox, xm12 y+4 Checked vuse_alternate_rom_path, %alternate_path_config_label%
	} else {
		gui, Add, Checkbox, xm12 y+4 vuse_alternate_rom_path, %alternate_path_config_label%
	}
	gui, add, edit, w400 xm12 y+0 valternate_rom_path, %alternate_rom_path%
	gui, add, text, xm12 y+8 w300 h1 0x7


	;### Playlist names
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+12  w560, Playlist Name
	gui, font, s10 w400, Verdana
	gui, add, text, xm12 y+0 w560, %playlist_names_config_label%
		gui, add, edit, w400 xm12 y+0 vplaylist_names, %playlist_names%
	gui, font, s10 w400 italic, Verdana
	gui, add, text, xm12 y+0 w560, %playlist_names_config_description%
	gui, font, normal s10 w400, Verdana
	if(unix_playlist) {					;### respect the default set at the top of the script
		gui, Add, Checkbox, xm12 y+12 Checked vunix_playlist, %unix_playlist_config_label%
	} else {
		gui, Add, Checkbox, xm12 y+12 vunix_playlist, %unix_playlist_config_label%
	}

	;### Thumbnail settings
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+12  w560, %local_art_path_label%
	gui, add, edit, w400 xm12 y+0  vlocal_art_path, %local_art_path%
	gui, font, normal s10 w700, Verdana
	gui, font, underline
	gui, add, text, cBlue gLibretroMAMEThumbLink y+0, Click here to download the MAME thumbnail pack via browser.
	gui, font, normal
	if(attempt_thumbnail_download) {	;### respect the default set at the top of the script
		gui, add, checkbox, xm12 y+4 Checked vattempt_thumbnail_download, %attempt_thumbnail_download_label%
	} else {
		gui, add, checkbox, xm12 y+4 vattempt_thumbnail_download, %attempt_thumbnail_download_label%
	}

	;### RetroArch path
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+12  w560, %RA_path_config_label%
	gui, font, normal s10 w400, Verdana
	gui, add, edit, w400 xm12 y+0  vRA_path, %RA_path%

	;### Manual RetroArch core path location
	gui, font, s10 w700, Verdana
	gui, add, text, xm12 y+12  w560, %RA_core_path_label%
	gui, font, normal s10 w400, Verdana
	gui, add, edit, w400 xm12 y+0  vRA_core_path, %RA_core_path%

	;### Buttons
	gui, font, s10 w700, Verdana
	gui, add, button, w100 xp+240 y+12 gDone, Generate
	gui, add, button, w100 xp+120 yp gExit, Exit

	gui, show, w600, AHK RetroArch Arcade Playlist Generator
	return WinExist()

	LibretroMAMEThumbLink:
	{
		run http://thumbnailpacks.libretro.com/MAME.zip
		return
	}
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
            Progress, H120 W700, , Downloading..., %UrlToFile%
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
