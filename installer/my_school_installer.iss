; Hibiscus Fancy - Inno Setup Script

[Setup]
AppId={{8B8B5B1E-1E1E-4B5B-8B8B-5B5B5B5B5B5B}
AppName=Hibiscus Supermarket
AppVersion=1.0.0
AppPublisher=Hibiscus
DefaultDirName={autopf}\HibiscusSupermarket
DefaultGroupName=Hibiscus Supermarket
OutputDir=Output
OutputBaseFilename=HibiscusSupermarketInstaller
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\hibiscus_fancy.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs
; Copy any other files in the root Release folder
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion; Excludes: "*.exe,*.dll,data"
Source: "VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\Hibiscus Supermarket"; Filename: "{app}\hibiscus_fancy.exe"
Name: "{autodesktop}\Hibiscus Supermarket"; Filename: "{app}\hibiscus_fancy.exe"; Tasks: desktopicon

[Run]
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/install /quiet /norestart"; Check: NeedsRedist; StatusMsg: "Installing Visual C++ Redistributable..."
Filename: "{app}\hibiscus_fancy.exe"; Description: "{cm:LaunchProgram,Hibiscus Supermarket}"; Flags: nowait postinstall skipifsilent

[Code]
function NeedsRedist: Boolean;
var
  Version: String;
begin
  // Check if Visual C++ 2015-2022 Redistributable (x64) is installed
  // This registry key is for the 14.x (2015-2022) redistributable
  if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
  begin
    Log('Visual C++ Redistributable version found: ' + Version);
    Result := False;
  end
  else
  begin
    Log('Visual C++ Redistributable not found, will install.');
    Result := True;
  end;
end;
