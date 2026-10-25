; Bijou's Windows installer, Bijou-Setup.exe (Inno Setup 6; docs/install.md,
; docs/install/windows.md). The release workflow compiles it from the
; release build (with the bundled FFmpeg and the MSVC runtime beside
; iptv_player.exe):
;
;   ISCC /DAppVersion=0.1.0 /DAppBuild=330 /DBundleDir=<...\runner\Release>
;        /O<output folder> windows\packaging\bijou.iss
;
; - Installs for all users in Program Files\Bijou (asks for admin: UAC),
;   with a Start menu shortcut, a desktop one (a task, ticked), and
;   "Launch Bijou" at the end.
; - A newer setup run over an older install updates it in place: the same
;   AppId finds it, closes a running Bijou first (and its FFmpeg), and keeps
;   the ticked tasks.
; - Casting: the TV fetches the stream from the PC's relay (docs/04), so an
;   inbound Windows Firewall rule lets iptv_player.exe in on private
;   networks; the uninstaller takes it away again.
; - The data (sources, favourites, history, settings, the sign-ins) is in
;   %APPDATA%\io.github.yasiralobaidi\IPTV Player (windows/runner/Runner.rc
;   names it): neither install nor uninstall touches it.
; - Not code-signed: SmartScreen warns once (docs/install/windows.md).
; - Toasts: flutter_local_notifications registers its app id
;   (io.github.yasiralobaidi.iptvplayer, lib/data/platform/windows_notifier.dart)
;   itself. The shortcuts carry no AppUserModelID, so the taskbar groups
;   Bijou's window with a pinned shortcut as before; if toasts need it on a
;   real PC, add AppUserModelID and AppUserModelToastActivatorCLSID
;   (d321c6df-3e8e-4242-a7dc-05c2081f896c) to the Start menu icon.

#ifndef AppVersion
  #define AppVersion "0.1.0"
#endif
#ifndef AppBuild
  #define AppBuild "0"
#endif
#ifndef BundleDir
  ; SourcePath: this script's folder, so the default is absolute too.
  #define BundleDir AddBackslash(SourcePath) + "..\..\build\windows\x64\runner\Release"
#endif

#if !FileExists(AddBackslash(BundleDir) + "iptv_player.exe")
  #error No release build in BundleDir: run flutter build windows --release first
#endif
#if !FileExists(AddBackslash(BundleDir) + "ffmpeg\ffmpeg.exe")
  #error No FFmpeg in the build (it couldn't cast): tools/fetch_ffmpeg.sh windows-x64, then build again
#endif

#define AppExe "iptv_player.exe"
#define FirewallRule "Bijou"

[Setup]
; Fixed for good: a new AppId would install a second Bijou beside the first.
AppId={{9E976A76-8729-41D3-8B45-136751A8FD26}
AppName=Bijou
AppVersion={#AppVersion}.{#AppBuild}
AppVerName=Bijou {#AppVersion} (build {#AppBuild})
AppPublisher=Yasir Alobaidi
AppPublisherURL=https://github.com/yasir-alobaidi/iptv-player
AppSupportURL=https://github.com/yasir-alobaidi/iptv-player/blob/main/docs/install/windows.md
AppUpdatesURL=https://github.com/yasir-alobaidi/iptv-player/releases/latest
AppCopyright=Copyright (C) 2026 Yasir Alobaidi
VersionInfoVersion={#AppVersion}.{#AppBuild}
VersionInfoProductName=Bijou
VersionInfoDescription=Bijou Setup
DefaultDirName={autopf}\Bijou
DefaultGroupName=Bijou
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
WizardStyle=modern
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName=Bijou
OutputDir=..\..\build\windows\installer
OutputBaseFilename=Bijou-Setup
Compression=lzma2/max
SolidCompression=yes
; An update closes a running Bijou (Restart Manager), and forces it if it
; doesn't close by itself: a file in use would otherwise wait for a restart.
CloseApplications=force
RestartApplications=no
ShowLanguageDialog=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; The last version's assets and FFmpeg, replaced whole: nothing stale stays.
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\ffmpeg"

[Files]
Source: "{#BundleDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Bijou"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"
Name: "{autodesktop}\Bijou"; Filename: "{app}\{#AppExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
; The firewall rule, made anew each time (an update finds the old one).
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRule}"" program=""{app}\{#AppExe}"""; Flags: runhidden; StatusMsg: "Letting your TV reach Bijou for casting (Windows Firewall)..."
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""{#FirewallRule}"" dir=in action=allow program=""{app}\{#AppExe}"" enable=yes profile=private description=""Lets a Chromecast or Google TV on your home network fetch what Bijou casts."""; Flags: runhidden; StatusMsg: "Letting your TV reach Bijou for casting (Windows Firewall)..."
; As the user who ran the setup, not as the administrator it asked for.
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,Bijou}"; Flags: nowait postinstall skipifsilent runasoriginaluser

[UninstallRun]
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""{#FirewallRule}"" program=""{app}\{#AppExe}"""; Flags: runhidden; RunOnceId: "DeleteFirewallRule"
