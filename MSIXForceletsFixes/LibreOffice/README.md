# LibreOffice 26.8.2.2 as MSIX

| File | Purpose |
|---|---|
| `LibreOffice.psd1` | package description: name, version, installer and silent parameters |
| `Fix-LibreOffice.ps1` | fix script (MSIXForcelets), applied to the captured package |

Installer: `LibreOffice_26.8.2_Win_x86-64.msi` from libreoffice.org, not included. The package runs installed and as a
CimFS App Attach image, without the PSF.

## Capture

The MSI is a single installer, so no wrapper script is needed. Parameters (from `LibreOffice.psd1`):

```
/qn /norestart ALLUSERS=1 REBOOT=ReallySuppress RebootYesNo=No ISCHECKFORPRODUCTUPDATES=0 QUICKSTART=0 CREATEDESKTOPLINK=0 VC_REDIST=1
```

- **`/qn`, `/norestart`, `REBOOT=ReallySuppress`, `ALLUSERS=1`:** msiexec and Windows Installer.
- **`ISCHECKFORPRODUCTUPDATES=0`, `QUICKSTART=0`:** the MSI's online update and quickstart components are
  conditioned on these properties.
- **`VC_REDIST=1`:** puts the VC++ runtime into `VFS\SystemX64`/`VFS\SystemX86` of the package, so target machines
  don't need it.
- **Do not use `REMOVE=...` or `ADDLOCAL=...`.** With a feature property on the command line, Windows Installer no
  longer uses the default feature selection for the other features, and nothing is installed (status 0 after 2 s).
- The MSIX Packaging Tool appends its own `/le <file>` for MSI installers, so your own `/L*v` is overridden.

## Problems and measures

| Problem | Cause | Measure |
|---|---|---|
| Standard users cannot install the package: `0x80073D28` "administrator rights required to install the package service" | packaged service `LibreOfficeMaintenance` (`update_service.exe`, localSystem) | `Remove-MSIXServices`; an update service cannot update an MSIX package anyway |
| `python.exe` hangs; Python macros and extensions do not work | `python-core-3.13.17\bin\python.exe` imports `python313.dll`, which is only in `program\`. The error dialog reads "... python313.dll was not found". | `Add-MSIXloaderSearchPathOverride` on `VFS\ProgramFilesX64\LibreOffice\program` |
| No start from a CimFS App Attach image (`0x801F000F`) | InstalledLocationVirtualization, part of `Add-MSIXFixLibreOffice` | the parts of `Add-MSIXFixLibreOffice` are applied individually, **without ILV** |
| Start menu tile "LibreOffice (Safe Mode)" opens the normal Start Center | The Packaging Tool took the name from the `--safe-mode` shortcut | `Set-MSIXApplicationVisualElements -Id SOFFICE -DisplayName 'LibreOffice'` |
| Installation fails where `Microsoft.WindowsAppRuntime.1.4` is missing (`0x80073CF3`) | dependency added by the capture; LibreOffice does not use the Windows App SDK | `Remove-MSIXDependencies 'Microsoft.WindowsAppRuntime*'` |
| desktop7 shortcuts | no icon, can block the installation (`0x800700A1`) | `Remove-MSIXDesktop7Shortcut` |
| Fonts, Start menu group | parts of `Add-MSIXFixLibreOffice` | `Add-MSIXSharedFonts` (127 fonts, e.g. Liberation), `-VisualGroup 'LibreOffice'` |

## Tests

| Test | Windows 11 | Windows Server 2025 (no App Runtime) |
|---|---|---|
| Installation with `Add-AppxPackage` | ok | ok |
| Start of all 7 applications | ok | ok |
| Python-UNO: `python.exe -c "import uno"` | ok | ok |
| PDF export with `soffice --headless --convert-to pdf` | ok | ok |
| Save and reopen a file in Documents | ok | ok |
| Install an extension with `unopkg add` | ok | ok |
| Uninstallation without leftovers | ok | ok |
| Start from a CimFS App Attach image | ok | not tested |

Not tested: settings and extension after a restart, double-click on an `.odt` file, multi-user test on a terminal
server.

## Notes

- **User profile:** LibreOffice keeps the user profile and extensions in the **real** `%APPDATA%\LibreOffice\4\user`,
  not in the package cache. They remain after uninstalling the package.
- **Updater files:** `updater.exe` is still in the package. Without the service it has no effect.
- **Shell property handlers** for ODF files are not declared in the manifest, so metadata may be missing in
  Explorer's file properties (not tested).
- **For an update:** keep PackageName `LibreOffice`, the same signing certificate and the Application Ids `SOFFICE`,
  `SIMPRESS`, `SBASE`, `SWRITER`, `SDRAW`, `SCALC`, `SMATH`. Check after an update:
  - whether the new MSI brings the service `LibreOfficeMaintenance` again
  - the name of the Python DLL
