# MSIXForceletsFixes

Fix scripts for MSIX packages, written with the [MSIXForcelets](https://github.com/AndreasNick/MSIXForcelets) PowerShell module.
Each folder has the following parts:

- a fix script, which is applied to the package captured with the MSIX Packaging Tool
- the package description (`<Name>.psd1`: name, version, installer, silent parameters)
- the installer wrapper, where one was needed
- a README with the problems found, the measures taken and the test results

Application installers are not included. Download them from the vendor.

| Folder | Application | Runs installed | Runs as App Attach (CimFS) | PSF |
|---|---|---|---|---|
| [LibreOffice](LibreOffice/) | LibreOffice 26.8.2.2 | yes | yes | no |
| [RuRStudio](RuRStudio/) | R 4.6.2 and RStudio 2026.11.0-203 | yes | yes | no; a corrected MFRFixup (DLL and source) is in [CustomMFRFixup](RuRStudio/CustomMFRFixup/) |

## Common points

- **No InstalledLocationVirtualization (ILV) for packages that are deployed as CimFS App Attach images.** With ILV,
  the package does not start from a CimFS image. Event 216/208 in AppModel-Runtime/Admin reports `0x801F000F`
  ("Cannot create the Desktop AppX container"). The ILV filter driver `wcifs` does not attach to CimFS volumes;
  `fltmc attach wcifs` fails with `0x801f000f` as well. Installed with `Add-AppxPackage`, the same packages run with
  ILV. If an application must write to its install folder and has to run from CimFS, the PSF MFRFixup with
  `ilvAware=false` is the user-mode alternative.
- **Windows App Runtime:** the MSIX Packaging Tool adds a dependency on `Microsoft.WindowsAppRuntime.1.4` during the
  capture. Neither application uses the Windows App SDK, so both fixes remove the dependency. Without that,
  `Add-AppxPackage` fails with `0x80073CF3` on machines without the runtime.
- **desktop7 shortcuts** are removed (`Remove-MSIXDesktop7Shortcut`). They show no icon and can block the
  installation (`0x800700A1`).

## Usage

```powershell
Import-Module MSIXForcelets
.\LibreOffice\Fix-LibreOffice.ps1 -MsixFile .\LibreOffice_unfixed.msix -OutputFile .\LibreOffice_fixed.msix `
    -PfxFile .\Signing.pfx -PfxPassword (Read-Host -AsSecureString)
```

Without `-PfxFile`, the package is not signed, and you sign it yourself. The publisher in the manifest must match
the subject of the certificate.

Tested on Windows 11 (build 26200) and Windows Server 2025, as of November 2026.
