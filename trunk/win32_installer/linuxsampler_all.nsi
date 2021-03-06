; LinuxSampler Windows installer
;
; Copyright (C) 2007-2016, The LinuxSampler Developers
;
; All-in-one Installer for all subprojects / software components of the
; LinuxSampler Project.
;
; PREREQUISITES:
;
; -> You must install the file cpudesc\cpudesc.dll into the working
;    directory before being able to compile this installer!
;
; -> The compiled binaries must be placed into the respective directories
;    under bin\ (you have to read this file in order to get those exact
;    locations and expected file names).

; NSIS plug-in for getting CPU information
!addplugindir cpudesc

; Probably the best compression ratio
SetCompressor lzma

;Include Modern UI
!include "MUI.nsh"
!include "EnvVarUpdate.nsh"
!include "WordFunc.nsh"

!define /date RELEASE_DATE "%Y%m%d"
!searchparse /file bin/686/linuxsampler.pc `Version: ` LINUXSAMPLER_VERSION
!searchparse /file bin/686/gig.pc `Version: ` LIBGIG_VERSION
!searchparse /file bin/686/gigedit.version `` GIGEDIT_VERSION
!define FANTASIA_VERSION "0.9"
!searchparse /file bin/686/qsampler.version `` QSAMPLER_VERSION
!searchparse /file bin/686/sndfile.pc `Version: ` SNDFILE_VERSION

; The name of the installer
Name "LinuxSampler (${RELEASE_DATE})"

; The file to write
OutFile "linuxsampler_${RELEASE_DATE}_setup.exe"

; Java Runtime Environment, needed for JSampler
!define JRE_VERSION "1.6"
; jre-8u191-windows-i586.exe:
!define JRE_32_URL "http://javadl.oracle.com/webapps/download/AutoDL?BundleId=235725_2787e4a523244c269598db4e85c51e0c"
; jre-8u191-windows-x64.exe:
!define JRE_64_URL "http://javadl.oracle.com/webapps/download/AutoDL?BundleId=235727_2787e4a523244c269598db4e85c51e0c"

; The default installation directory
InstallDir "$PROGRAMFILES64\LinuxSampler"
!define SUBDIR_32_BIT "32"
!define SUBDIR_64_BIT "64"

!define DEFAULT_VST_DIR64 "$PROGRAMFILES64\Steinberg\VstPlugins"
!define DEFAULT_VST_DIR "$PROGRAMFILES\Steinberg\VstPlugins"

; Get installation folder from registry if available
InstallDirRegKey HKLM "Software\LinuxSampler" "Main Directory"

;--------------------------------
;Interface Settings

!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_BITMAP "linuxsampler.bmp"
!define MUI_ABORTWARNING

!define BIN_TYPE_64BIT  "64 bit"
!define BIN_TYPE_686SSE "686 SSE"
!define BIN_TYPE_686    "686"

Var /GLOBAL binType

;--------------------------------
; Pages

!insertmacro MUI_PAGE_LICENSE "license.rtf"
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

;--------------------------------
;Languages

!insertmacro MUI_LANGUAGE "English"

;--------------------------------
;Version Information

VIProductVersion "0.0.0.0"
VIAddVersionKey /LANG=${LANG_ENGLISH} "ProductName" "all-in-one installer"
VIAddVersionKey /LANG=${LANG_ENGLISH} "Comments" "http://linuxsampler.org"
VIAddVersionKey /LANG=${LANG_ENGLISH} "CompanyName" "The LinuxSampler Project"
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalTrademarks" ""
VIAddVersionKey /LANG=${LANG_ENGLISH} "LegalCopyright" "� 2003-2017 The LinuxSampler Project"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileDescription" "LinuxSampler Installer (${RELEASE_DATE})"
VIAddVersionKey /LANG=${LANG_ENGLISH} "FileVersion" "0.0.0"

;--------------------------------

Function .onInit
  Var /GLOBAL installingLinuxSampler
  Var /GLOBAL installingJSampler
  Var /GLOBAL installingQSampler
  Var /GLOBAL installinggigedit
  Var /GLOBAL installing32BitToo
  StrCpy $installingLinuxSampler "0"
  StrCpy $installingJSampler "0"
  StrCpy $installingQSampler "0"
  StrCpy $installinggigedit "0"
  StrCpy $installing32BitToo "0"
FunctionEnd

!macro CreateInternetShortcut FILENAME URL ICONFILE ICONINDEX
WriteINIStr "${FILENAME}.url" "InternetShortcut" "URL" "${URL}"
WriteINIStr "${FILENAME}.url" "InternetShortcut" "IconFile" "${ICONFILE}"
WriteINIStr "${FILENAME}.url" "InternetShortcut" "IconIndex" "${ICONINDEX}"
!macroend

; detects CPU capabilities, determines which native binary type to install
; and selects the appropriate windows registry view (32 bit or 64 bit)
!macro DetectSystemType un
Function ${un}DetectSystemType
  ; check if this is a 64 bit windows
  System::Call "kernel32::GetCurrentProcess() i .s"
  System::Call "kernel32::IsWow64Process(i s, *i .r0)"
  IntCmp $0 0 not64bit
  StrCpy $binType BIN_TYPE_64BIT
  DetailPrint "64 bit Windows detected."
  SetRegView 64
  Goto DetectSystemDone

  not64bit: ; a 32 bit system

  SetRegView 32

  ; check if CPU supports SSE
  cpudesc::tell
  Pop $0                     ; full identification string in $0
  StrCpy $1 $0 1, 34         ; pull out one character after SSE=
  IntFmt $2 "%u" $1          ; and turn it into a number
  IntCmpU $2 1 +1 +4 +4
  StrCpy $binType BIN_TYPE_686SSE
  DetailPrint "32 bit Windows, SSE CPU detected."
  Goto DetectSystemDone
  StrCpy $binType BIN_TYPE_686
  DetailPrint "32 bit Windows (no SSE support) detected."

  DetectSystemDone:
FunctionEnd
!macroend
!insertmacro DetectSystemType ""
!insertmacro DetectSystemType "un."

; Downloads and launches the JRE installer from the internet
Function GetJRE
  Var /GLOBAL jreUri

  StrCmp $binType BIN_TYPE_64BIT 0 +3
  StrCpy $jreUri ${JRE_64_URL}
  Goto +2
  StrCpy $jreUri ${JRE_32_URL}

  DetailPrint "Downloading JRE from: $jreUri"

  MessageBox MB_OK "JSampler requires Java ${JRE_VERSION} or later, \
                    it will now be downloaded and installed"

  StrCpy $2 "$TEMP\Java Runtime Environment.exe"
  nsisdl::download /TIMEOUT=30000 "$jreUri" $2
  Pop $R0  ; Get the return value
  StrCmp $R0 "success" +3
  MessageBox MB_OK "Download failed: $R0"
  Quit
  ExecWait $2
  Delete $2
FunctionEnd

; Checks if the JRE is already installed, if not it will download and install it from the internet
Function DetectJRE
  ReadRegStr $2 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment" \
             "CurrentVersion"
  ${VersionCompare} $2 ${JRE_VERSION} $R0
  IntCmp $R0 1 done done

  StrCmp $binType BIN_TYPE_64BIT 0 downloadjre

  ; on 64 bit systems also check the 32 bit view of the registry, maybe
  ; a 32 bit JRE was already installed
  SetRegView 32
  ReadRegStr $3 HKLM "SOFTWARE\JavaSoft\Java Runtime Environment" \
             "CurrentVersion"
  SetRegView 64  ; restore 64 bit view
  ${VersionCompare} $3 ${JRE_VERSION} $R0
  IntCmp $R0 1 done done

  downloadjre:
  Call GetJRE

  done:
FunctionEnd

; Tries to find the location where VST plugins should be installed to
Function DetectVstPath
  Var /GLOBAL vstPluginPath
  Var /GLOBAL vstPluginPath64

  StrCmp $binType BIN_TYPE_64BIT 0 detectVst32
  SetRegView 64 ; make sure we have the 64 bit registry view

  ; ------- VST 64 bit detection -------

  ClearErrors
  ReadRegStr $0 HKCU "Software\VST" "VSTPluginsPath"
  IfErrors check2ndRegistryKey64 0
  StrCpy $vstPluginPath64 $0
  DetailPrint "Found VST plugin (64 bit) directory in HKCU registry."
  Goto done64

  check2ndRegistryKey64:
  ClearErrors
  ReadRegStr $0 HKLM "Software\VST" "VSTPluginsPath"
  IfErrors noRegistryKeyExists64 0
  StrCpy $vstPluginPath64 $0
  DetailPrint "Found VST plugin (64 bit) directory in HKLM registry."
  Goto done64

  noRegistryKeyExists64:
  ClearErrors
  DetailPrint "No VST plugin directory (64 bit) defined in registry."
  StrCpy $vstPluginPath64 "${DEFAULT_VST_DIR64}"

  done64:
  SetRegView 32 ; make sure we have a 32 bit registry view

  detectVst32: ; it follows the same thing for the 32 bit registry view

  ; ------- VST 32 bit detection -------

  ClearErrors
  ReadRegStr $0 HKCU "Software\VST" "VSTPluginsPath"
  IfErrors check2ndRegistryKey 0
  StrCpy $vstPluginPath $0
  DetailPrint "Found VST plugin (32 bit) directory in HKCU registry."
  Goto done

  check2ndRegistryKey:
  ClearErrors
  ReadRegStr $0 HKLM "Software\VST" "VSTPluginsPath"
  IfErrors noRegistryKeyExists 0
  StrCpy $vstPluginPath $0
  DetailPrint "Found VST plugin (32 bit) directory in HKLM registry."
  Goto done

  noRegistryKeyExists:
  ClearErrors
  DetailPrint "No VST plugin directory (32 bit) defined in registry."
  StrCpy $vstPluginPath "${DEFAULT_VST_DIR}"

  done: ; ------- summary of detection -------

  StrCmp $binType BIN_TYPE_64BIT 0 summaryVst32
  SetRegView 64  ; restore 64 bit view
  DetailPrint "Using the following as VST (64 bit) plugin directory: $vstPluginPath64"
  summaryVst32:
  DetailPrint "Using the following as VST (32 bit) plugin directory: $vstPluginPath"
FunctionEnd

;--------------------------------

; primer things to do (before installing, not called on uninstall)
Section ""
  Call DetectSystemType
  Call DetectVstPath
SectionEnd

;--------------------------------

; The stuff to install
Section "LinuxSampler ${LINUXSAMPLER_VERSION}" SecLinuxSampler
  DetailPrint "Installing LinuxSampler binaries ..."
  StrCpy $installingLinuxSampler "1"

  StrCmp $binType BIN_TYPE_64BIT linuxsampler64
  StrCmp $binType BIN_TYPE_686SSE linuxsampler686sse
  Goto linuxsampler686

  ; Files to install

  linuxsampler64:
  SetOutPath "$INSTDIR\${SUBDIR_64_BIT}"
  File bin\64\linuxsampler.exe
  File bin\64\liblinuxsampler-5.dll
  File bin\64\libsqlite3-0.dll
  SetOutPath $vstPluginPath64
  File /oname=LinuxSampler64.dll bin\64\LinuxSampler.dll
  MessageBox MB_YESNO \
    "It seems you are using a 64 bit Windows system. A native 64 bit version of LinuxSampler and its VST plugin version will be installed accordingly.$\r$\n$\r$\nShall a 32 bit version of the LinuxSampler VST be installed as well?" \
    IDNO done

  ; so the other sections install their 32 bit versions as well
  StrCpy $installing32BitToo "1"

  linuxsampler686sse:
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686sse\linuxsampler.exe
  File bin\686sse\liblinuxsampler-5.dll
  File bin\686\libsqlite3-0.dll
  SetOutPath $vstPluginPath
  File /oname=LinuxSampler32.dll bin\686sse\LinuxSampler.dll
  Goto done

  linuxsampler686:
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686\linuxsampler.exe
  File bin\686\liblinuxsampler-5.dll
  File bin\686\libsqlite3-0.dll
  SetOutPath $vstPluginPath
  File /oname=LinuxSampler32.dll bin\686\LinuxSampler.dll
  Goto done

  done:
SectionEnd

Section "JSampler 'Fantasia' ${FANTASIA_VERSION}" SecJSampler
  DetailPrint "Installing JSampler binaries ..."
  ; make sure JRE is installed
  Call DetectJRE
  StrCpy $installingJSampler "1"
  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  ; Files to install
  File bin\Fantasia-0.9.jar
  File jsampler.ico
SectionEnd

Section "QSampler ${QSAMPLER_VERSION}" SecQSampler
  DetailPrint "Installing QSampler binaries ..."
  StrCpy $installingQSampler "1"
  ; Set output path to the installation directory.
  SetOutPath $INSTDIR
  ; Files to install
  File bin\686\qsampler.exe
  File bin\686\liblscp-6.dll
  File bin\686\Qt5Core.dll
  File bin\686\Qt5Gui.dll
  File bin\686\Qt5Widgets.dll
  File bin\686\libicudt57.dll
  File bin\686\libicuin57.dll
  File bin\686\libicuuc57.dll
  File bin\686\libpcre16-0.dll
  File qt.conf
  File qsampler.ico
  SetOutPath $INSTDIR\plugins\platforms
  File bin\686\plugins\platforms\qwindows.dll
  SetOutPath $INSTDIR\share\locale
  File bin\686\share\locale\qsampler_*.qm
  File bin\686\share\locale\qt*_*.qm
  Call FilesCommonToQSamplerAndGigedit32
SectionEnd

Function FilesCommonToQSamplerAndGigedit32
  SetOutPath $INSTDIR
  File bin\686\libbz2-1.dll
  File bin\686\libfreetype-6.dll
  Delete $INSTDIR\${SUBDIR_32_BIT}\libglib-2.0-0.dll ; remove old version
  File bin\686\libglib-2.0-0.dll
  File bin\686\libgraphite2.dll
  File bin\686\libharfbuzz-0.dll
  File bin\686\libiconv-2.dll
  File bin\686\libintl-8.dll
  File bin\686\libpcre-1.dll
  File bin\686\libpng16-16.dll
  Delete $INSTDIR\${SUBDIR_32_BIT}\zlib1.dll ; remove old version
  File bin\686\zlib1.dll
FunctionEnd

Section "gigedit ${GIGEDIT_VERSION}" Secgigedit
  DetailPrint "Installing gigedit binaries ..."
  StrCpy $installinggigedit "1"

  StrCmp $installingQSampler "1" commonDone
  StrCmp $binType BIN_TYPE_64BIT 0 common
  StrCmp $installing32BitToo "0" commonDone
  common:
  Call FilesCommonToQSamplerAndGigedit32
  commonDone:

  ; Files common to 32 and 64 bit gigedit
  SetOutPath $INSTDIR\share
  File /r bin\686\share\glib-2.0
  File /r bin\686\share\icons
  SetOutPath $INSTDIR\share\locale
  File /r bin\686\share\locale\de
  File /r bin\686\share\locale\sv
    
  StrCmp $binType BIN_TYPE_64BIT gigedit64
  ; I think we don't need a SSE optimized 32 bit binary for gigedit, one 64bit and one simple 32 bit version should be sufficient
  ;StrCmp $binType BIN_TYPE_686SSE gigedit686sse
  Goto gigedit686

  ; Files to install

  gigedit64:
  SetOutPath "$INSTDIR\${SUBDIR_64_BIT}"
  File bin\64\gigedit.exe
  File bin\64\libgigedit-4.dll
  SetOutPath "$INSTDIR\${SUBDIR_64_BIT}\plugins"
  File bin\64\plugins\libgigeditlinuxsamplerplugin.dll
  SetOutPath "$INSTDIR\${SUBDIR_64_BIT}"
  File bin\64\libatk-1.0-0.dll
  File bin\64\libatkmm-1.6-1.dll
  File bin\64\libbz2-1.dll
  File bin\64\libcairo-2.dll
  File bin\64\libcairo-gobject-2.dll
  File bin\64\libcairomm-1.0-1.dll
  File bin\64\libepoxy-0.dll
  File bin\64\libexpat-1.dll
  File bin\64\libffi-6.dll
  File bin\64\libfontconfig-1.dll
  File bin\64\libfreetype-6.dll
  File bin\64\libgdkmm-3.0-1.dll
  File bin\64\libgdk_pixbuf-2.0-0.dll
  File bin\64\libgdk-3-0.dll
  File bin\64\libgio-2.0-0.dll
  File bin\64\libgiomm-2.4-1.dll
  File bin\64\libglib-2.0-0.dll
  File bin\64\libglibmm-2.4-1.dll
  File bin\64\libgmodule-2.0-0.dll
  File bin\64\libgobject-2.0-0.dll
  File bin\64\libgraphite2.dll
  File bin\64\libgtkmm-3.0-1.dll
  File bin\64\libgtk-3-0.dll
  File bin\64\libharfbuzz-0.dll
  File bin\64\libiconv-2.dll
  File bin\64\libintl-8.dll
  File bin\64\libpango-1.0-0.dll
  File bin\64\libpangocairo-1.0-0.dll
  File bin\64\libpangoft2-1.0-0.dll
  File bin\64\libpangomm-1.4-1.dll
  File bin\64\libpangowin32-1.0-0.dll
  File bin\64\libpcre-1.dll
  File bin\64\libpixman-1-0.dll
  File bin\64\libpng16-16.dll
  File bin\64\libsigc-2.0-0.dll
  File bin\64\zlib1.dll
  ; remove old share directory
  RMDir /r $INSTDIR\${SUBDIR_64_BIT}\share

  ; shall we install the 32 bit version as well?
  StrCmp $installing32BitToo "1" gigedit686 done

  gigedit686:
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686\gigedit.exe
  File bin\686\libgigedit-4.dll
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}\plugins"
  File bin\686\plugins\libgigeditlinuxsamplerplugin.dll
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686\libatk-1.0-0.dll
  File bin\686\libatkmm-1.6-1.dll
  File bin\686\libcairo-2.dll
  File bin\686\libcairo-gobject-2.dll
  File bin\686\libcairomm-1.0-1.dll
  File bin\686\libepoxy-0.dll
  File bin\686\libexpat-1.dll
  File bin\686\libffi-6.dll
  File bin\686\libfontconfig-1.dll
  File bin\686\libgdk_pixbuf-2.0-0.dll
  File bin\686\libgdk-3-0.dll
  File bin\686\libgdkmm-3.0-1.dll
  File bin\686\libgio-2.0-0.dll
  File bin\686\libgiomm-2.4-1.dll
  File bin\686\libglibmm-2.4-1.dll
  File bin\686\libgmodule-2.0-0.dll
  File bin\686\libgobject-2.0-0.dll
  File bin\686\libgtk-3-0.dll
  File bin\686\libgtkmm-3.0-1.dll
  File bin\686\libpango-1.0-0.dll
  File bin\686\libpangocairo-1.0-0.dll
  File bin\686\libpangoft2-1.0-0.dll
  File bin\686\libpangomm-1.4-1.dll
  File bin\686\libpangowin32-1.0-0.dll
  File bin\686\libpixman-1-0.dll
  File bin\686\libsigc-2.0-0.dll
  ; remove old share directory
  RMDir /r $INSTDIR\${SUBDIR_32_BIT}\share

  done:
SectionEnd

Section "libgig ${LIBGIG_VERSION}" Seclibgig
  DetailPrint "Installing libgig binaries ..."
  ; We make this a mandatory component
  SectionIn RO

  StrCmp $binType BIN_TYPE_64BIT libgig64
  StrCmp $binType BIN_TYPE_686SSE libgig686sse
  Goto libgig686

  ; Files to install

  libgig64:
  SetOutPath "$INSTDIR\${SUBDIR_64_BIT}"
  File bin\64\libgig-8.dll
  File bin\64\libakai-0.dll
  File bin\64\rifftree.exe
  File bin\64\dlsdump.exe
  File bin\64\gigdump.exe
  File bin\64\gigextract.exe
  File bin\64\gigmerge.exe
  File bin\64\gig2mono.exe
  File bin\64\gig2stereo.exe
  File bin\64\korg2gig.exe
  File bin\64\korgdump.exe
  File bin\64\akaidump.exe
  File bin\64\akaiextract.exe
  File bin\64\sf2dump.exe
  File bin\64\sf2extract.exe
  File bin\64\libgcc_s_seh-1.dll
  File bin\64\libwinpthread-1.dll  
  File bin\64\libstdc++-6.dll

  ; shall we install the 32 bit version as well?
  StrCmp $installing32BitToo "1" libgig686sse
  StrCmp $installingQSampler "1" libgigForQsampler done

  ; QSampler needs the 32 bit libgig dll
  libgigForQsampler:
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686sse\libgig-8.dll
  Goto libgig32common

  libgig686sse:
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686sse\libgig-8.dll
  File bin\686sse\libakai-0.dll
  File bin\686sse\rifftree.exe
  File bin\686sse\dlsdump.exe
  File bin\686sse\gigdump.exe
  File bin\686sse\gigextract.exe
  File bin\686sse\gigmerge.exe
  File bin\686sse\gig2mono.exe
  File bin\686sse\gig2stereo.exe
  File bin\686sse\korg2gig.exe
  File bin\686sse\korgdump.exe
  File bin\686sse\akaidump.exe
  File bin\686sse\akaiextract.exe
  File bin\686sse\sf2dump.exe
  File bin\686sse\sf2extract.exe
  Goto libgig32common

  libgig686:
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686\libgig-8.dll
  File bin\686\libakai-0.dll
  File bin\686\rifftree.exe
  File bin\686\dlsdump.exe
  File bin\686\gigdump.exe
  File bin\686\gigextract.exe
  File bin\686\gigmerge.exe
  File bin\686\gig2mono.exe
  File bin\686\gig2stereo.exe
  File bin\686\korg2gig.exe
  File bin\686\korgdump.exe
  File bin\686\akaidump.exe
  File bin\686\akaiextract.exe
  File bin\686\sf2dump.exe
  File bin\686\sf2extract.exe

  libgig32common:
  Delete $INSTDIR\libgcc_s_dw2-1.dll ; remove old version
  File bin\686\libgcc_s_dw2-1.dll
  File bin\686\libwinpthread-1.dll  
  File bin\686\libstdc++-6.dll
  
  done:

  ; As this is a mandatory component, we misuse is for the following
  ; common tasks as well ...

  ; Add LinuxSampler and friends to the system's PATH variable
  ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR"
  ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\${SUBDIR_64_BIT}"
  ${EnvVarUpdate} $0 "PATH" "A" "HKLM" "$INSTDIR\${SUBDIR_32_BIT}"

  ; Write the uninstall keys for Windows
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LinuxSampler" "DisplayName" "LinuxSampler ${RELEASE_DATE}"
  WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LinuxSampler" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LinuxSampler" "NoModify" 1
  WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LinuxSampler" "NoRepair" 1
  WriteUninstaller "uninstall.exe"

  ; Store installation folders
  WriteRegStr HKLM "Software\LinuxSampler" "Main Directory" $INSTDIR
  StrCmp $binType BIN_TYPE_64BIT 0 +3
  WriteRegStr HKLM "Software\LinuxSampler" "VST 64 Directory" $vstPluginPath64
  StrCmp $installing32BitToo "1" 0 +2
  WriteRegStr HKLM "Software\LinuxSampler" "VST 32 Directory" $vstPluginPath

  ; Just for info, store the release date as well
  WriteRegStr HKLM "Software\LinuxSampler" "Release Date" ${RELEASE_DATE}
SectionEnd

Section "libsndfile ${SNDFILE_VERSION}" Seclibsndfile
  DetailPrint "Installing libsndfile binaries ..."
  ; We make this a mandatory component
  SectionIn RO

  StrCmp $binType BIN_TYPE_64BIT libsndfile64
  ; I think we don't need a SSE optimized 32 bit binary for libsndfile, one 64bit and one simple 32 bit DLL should be sufficient
  ;StrCmp $binType BIN_TYPE_686SSE libsndfile686sse
  Goto libsndfile686

  ; Files to install

  libsndfile64:
  SetOutPath "$INSTDIR\${SUBDIR_64_BIT}"
  File bin\64\libsndfile-1.dll
  File bin\64\libFLAC-8.dll
  File bin\64\libogg-0.dll
  File bin\64\libvorbis-0.dll
  File bin\64\libvorbisenc-2.dll
  File bin\64\libspeex-1.dll

  ; shall we install the 32 bit version as well?
  StrCmp $installing32BitToo "1" libsndfile686 done

  libsndfile686:
  SetOutPath "$INSTDIR\${SUBDIR_32_BIT}"
  File bin\686\libsndfile-1.dll
  File bin\686\libFLAC-8.dll
  File bin\686\libogg-0.dll
  File bin\686\libvorbis-0.dll
  File bin\686\libvorbisenc-2.dll
  File bin\686\libspeex-1.dll
  Goto done

  done:
SectionEnd

Section "Start Menu Shortcuts" SecShortcuts
  Var /GLOBAL javawbin
  Var /GLOBAL samplerDir

  StrCmp $binType BIN_TYPE_64BIT 0 +3
  StrCpy $samplerDir "$INSTDIR\${SUBDIR_64_BIT}"
  Goto +2
  StrCpy $samplerDir "$INSTDIR\${SUBDIR_32_BIT}"

  ; Switch system variables to 'all users', to ensure we create the start
  ; menu shortcuts for all users and not just for the current user.
  SetShellVarContext all

  ; try to resolve the full qualified path of the javaw binary
  ClearErrors
  SearchPath $javawbin javaw.exe
  IfErrors 0 javawDetected
  ClearErrors
  ; if all fails, simply use SYSDIR (which should work almost always anyway)
  DetailPrint "WRN: Could not resolve javaw.exe path, using SYSDIR."
  StrCpy $javawbin "$SYSDIR\javaw.exe"
  javawDetected:

  CreateDirectory "$SMPROGRAMS\LinuxSampler"

  SetOutPath $INSTDIR
  CreateShortCut "$SMPROGRAMS\LinuxSampler\Uninstall.lnk" "$INSTDIR\uninstall.exe" "" "$INSTDIR\uninstall.exe" 0

  StrCmp $installingLinuxSampler '1' 0 +3
  SetOutPath $samplerDir
  CreateShortCut "$SMPROGRAMS\LinuxSampler\LinuxSampler ${LINUXSAMPLER_VERSION} (stand alone backend).lnk" "$samplerDir\linuxsampler.exe" "" "$samplerDir\linuxsampler.exe" 0

  StrCmp $installingJSampler '1' 0 +3
  SetOutPath $INSTDIR
  CreateShortCut '$SMPROGRAMS\LinuxSampler\JSampler Fantasia ${FANTASIA_VERSION} (frontend).lnk' '$javawbin' '-jar "$INSTDIR\Fantasia-0.9.jar"' '$INSTDIR\jsampler.ico' 0

  StrCmp $installingQSampler '1' 0 +3
  SetOutPath $INSTDIR
  CreateShortCut "$SMPROGRAMS\LinuxSampler\QSampler ${QSAMPLER_VERSION} (frontend).lnk" "$INSTDIR\qsampler.exe" "" "$INSTDIR\qsampler.ico" 0

  StrCmp $installinggigedit '1' 0 +3
  SetOutPath $samplerDir
  CreateShortCut "$SMPROGRAMS\LinuxSampler\gigedit ${GIGEDIT_VERSION} (stand alone).lnk" "$samplerDir\gigedit.exe" "" "$samplerDir\gigedit.exe" 0

  !insertmacro CreateInternetShortcut \
  "$SMPROGRAMS\LinuxSampler\\Support LinuxSampler" \
  "http://www.linuxsampler.org/donations.html" \
  "" "0"
SectionEnd

;--------------------------------

; Uninstaller

Section "Uninstall"
  Var /GLOBAL vstdir32
  Var /GLOBAL vstdir64

  Call un.DetectSystemType

  DetailPrint "Removing LinuxSampler directories from PATH variable ..."
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR"
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\${SUBDIR_32_BIT}"
  ${un.EnvVarUpdate} $0 "PATH" "R" "HKLM" "$INSTDIR\${SUBDIR_64_BIT}"

  StrCmp $binType BIN_TYPE_64BIT 0 uninstallVst32
  DetailPrint "Searching for VST plugin (64 bit) ..."
  ClearErrors
  ReadRegStr $0 HKLM "Software\LinuxSampler" "VST 64 Directory"
  IfErrors uninstallVst32 0
  StrCpy $vstdir64 $0
  DetailPrint "Removing VST plugin (64 bit) from: $vstdir64 ..."
  Delete "$vstdir64\LinuxSampler64.dll"

  uninstallVst32:

  DetailPrint "Searching for VST plugin (32 bit) ..."
  ClearErrors
  ReadRegStr $0 HKLM "Software\LinuxSampler" "VST 32 Directory"
  IfErrors uninstallVstDone 0
  StrCpy $vstdir32 $0
  DetailPrint "Removing VST plugin (32 bit) from: $vstdir32 ..."
  Delete "$vstdir32\LinuxSampler32.dll"

  uninstallVstDone:
  ClearErrors

  DetailPrint "Removing registry keys ..."
  DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\LinuxSampler"
  DeleteRegKey HKLM "Software\LinuxSampler"

  ; Workaround for Vista and younger: switch system variables to 'all users'
  ; otherwise e.g. we couldn't delete start menu shortcuts below on those
  ; systems, as those variables would point to the current user.
  SetShellVarContext all

  DetailPrint "Removing shortcuts (if any) from: $SMPROGRAMS ..."
  Delete "$SMPROGRAMS\LinuxSampler\*.*"

  DetailPrint "Removing directories used ..."
  RMDir /r "$SMPROGRAMS\LinuxSampler"
  RMDir /r "$INSTDIR"
SectionEnd

;--------------------------------
;Descriptions

;Language strings
LangString DESC_SecLinuxSampler ${LANG_ENGLISH} "Sampler backend (stand-alone and VST), including sampler engine, MIDI and audio drivers, native C++ API as well as network (LSCP) API. Use a frontend application like JSampler or QSampler to control the sampler."
LangString DESC_SecJSampler ${LANG_ENGLISH} "Graphical frontend (user interface) for LinuxSampler written in Java, supporting all current features of LinuxSampler. This is the 'Fantasia' distribution of JSampler, offering a modern skin based look."
LangString DESC_SecQSampler ${LANG_ENGLISH} "Graphical light-weight frontend (user interface) for LinuxSampler written in C++, offering a fast native user interface. NOTE: QSampler doesn't support all LinuxSampler features yet!"
LangString DESC_Secgigedit ${LANG_ENGLISH} "Graphical instrument editor for Gigasampler format v2 and v3 files. Can be used stand-alone or in conjunction with LinuxSampler."
LangString DESC_Seclibgig ${LANG_ENGLISH} "C++ program library for accessing DLS (Level 1 and Level 2) and GigaStudio/Gigasampler format (up to v4), SoundFont, AKAI and KORG files. This library is required by LinuxSampler, gigedit and QSampler."
LangString DESC_Seclibsndfile ${LANG_ENGLISH} "C program library for reading and writing files containing sampled sound (such as MS Windows WAV and the Apple/SGI AIFF format), used by gigedit to import samples."
LangString DESC_SecShortcuts ${LANG_ENGLISH} "Installs start menu shortcuts for all applications."

;Assign language strings to sections
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecLinuxSampler} $(DESC_SecLinuxSampler)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecJSampler} $(DESC_SecJSampler)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecQSampler} $(DESC_SecQSampler)
  !insertmacro MUI_DESCRIPTION_TEXT ${Secgigedit} $(DESC_Secgigedit)
  !insertmacro MUI_DESCRIPTION_TEXT ${Seclibgig} $(DESC_Seclibgig)
  !insertmacro MUI_DESCRIPTION_TEXT ${Seclibsndfile} $(DESC_Seclibsndfile)
  !insertmacro MUI_DESCRIPTION_TEXT ${SecShortcuts} $(DESC_SecShortcuts)
!insertmacro MUI_FUNCTION_DESCRIPTION_END
