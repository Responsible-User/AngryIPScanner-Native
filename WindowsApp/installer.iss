; Go Network Scanner — Inno Setup installer script
;
; Compiled with ISCC.exe, one installer per architecture:
;   ISCC.exe /DArch=x64   /DAppVersion=1.0.0 installer.iss
;   ISCC.exe /DArch=arm64 /DAppVersion=1.0.0 installer.iss
;
; The installer bundles a framework-dependent publish (~5 MB), then at
; install time it checks for the .NET 10 Desktop Runtime and, if missing,
; offers to open Microsoft's download page for the user.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif
#ifndef Arch
  #define Arch "x64"
#endif

#define AppName       "Go Network Scanner"
#define AppExeName    "GoNetworkScanner.exe"
#define AppPublisher  "Go Network Scanner Project"
#define AppURL        "https://github.com/Responsible-User/GoNetworkScanner"
#define SrcDir        "release\fxdep-win-" + Arch
#define OutputBase    "GoNetworkScanner-Setup-" + AppVersion + "-win-" + Arch

[Setup]
AppId={{C8F4A2B5-9E6D-4B71-A1C3-5F8E7D9A0B12}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
AppUpdatesURL={#AppURL}

DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
UninstallDisplayIcon={app}\{#AppExeName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern

OutputDir=release
OutputBaseFilename={#OutputBase}
SetupIconFile=GoNetworkScanner\Resources\app.ico

#if Arch == "x64"
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#elif Arch == "arm64"
ArchitecturesAllowed=arm64
ArchitecturesInstallIn64BitMode=arm64
#endif

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

[Code]
const
  DotNetVersion = '10.';
  #if Arch == "x64"
    DotNetArch = 'x64';
    DotNetDownloadUrl = 'https://dotnet.microsoft.com/download/dotnet/10.0/runtime?arch=x64&os=win';
  #elif Arch == "arm64"
    DotNetArch = 'arm64';
    DotNetDownloadUrl = 'https://dotnet.microsoft.com/download/dotnet/10.0/runtime?arch=arm64&os=win';
  #endif

// Detect .NET 10 Windows Desktop Runtime by reading the version list
// under HKLM\SOFTWARE\dotnet\Setup\InstalledVersions\<arch>\sharedfx\Microsoft.WindowsDesktop.App
function IsDotNetDesktopInstalled(): Boolean;
var
  key: string;
  names: TArrayOfString;
  i: Integer;
begin
  Result := False;
  key := 'SOFTWARE\dotnet\Setup\InstalledVersions\' + DotNetArch + '\sharedfx\Microsoft.WindowsDesktop.App';
  if not RegGetValueNames(HKLM, key, names) then
    Exit;
  for i := 0 to GetArrayLength(names) - 1 do
  begin
    if Pos(DotNetVersion, names[i]) = 1 then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function InitializeSetup(): Boolean;
var
  shellResult: Integer;
begin
  Result := True;
  if IsDotNetDesktopInstalled() then
    Exit;

  if MsgBox(
      '{#AppName} requires the .NET 10 Desktop Runtime (' + DotNetArch + '),'
      + ' which is not installed on this system.' + #13#10#13#10
      + 'Click Yes to open the official Microsoft download page in your'
      + ' browser, then re-run this installer after installing the runtime.'
      + #13#10#13#10
      + 'Click No to exit without installing.',
      mbConfirmation, MB_YESNO) = IDYES then
  begin
    ShellExec('open', DotNetDownloadUrl, '', '', SW_SHOWNORMAL, ewNoWait, shellResult);
  end;
  Result := False;
end;
