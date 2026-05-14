#define AppName "Limonchero 3D"
#define AppPublisher "PUCV"
#define AppVersion "0.0.0"
#define SourceDir "..\\..\\..\\dist\\installer"
#define OutputDir "..\\..\\..\\dist\\installer-out"
#define OutputBaseFilename "limonchero-setup-win"
#define AppExe "game\\limons.exe"

[Setup]
AppId={{7B2A2E4E-1B9C-4E61-9A7A-9EAC8D2F1F12}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
DefaultDirName={pf}\JuegoLimonchero
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\{#AppExe}

[Tasks]
Name: "desktopicon"; Description: "Create a desktop icon"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\game\*"; DestDir: "{app}\game"; Flags: recursesubdirs ignoreversion
Source: "{#SourceDir}\backend\*"; DestDir: "{app}\backend"; Flags: recursesubdirs ignoreversion

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{commondesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon
