# R 4.6.2 and RStudio 2026.11.0-203 as MSIX (RuRStudio)

| File | Purpose |
|---|---|
| `RuRStudio.psd1` | package description: name, version, installer |
| `Install-RuRStudio.cmd` | installer wrapper for the capture: installs R, then RStudio, silently for all users |
| `Fix-RuRStudio.ps1` | fix script (MSIXForcelets), no ILV, no PSF |
| `Rprofile.site.append.R` | block that the fix appends to R's `Rprofile.site` |
| `CustomMFRFixup\` | corrected PSF MFRFixup: `MFRFixup64.dll` and its source as a zip (see below) |

Installers are not included: `R-4.6.2-win.exe` (CRAN) and `RStudio-2026.11.0-203.exe` (Posit). Put both next to
`Install-RuRStudio.cmd`.

## Capture

`Install-RuRStudio.cmd` is the installer in the MSIX Packaging Tool (no arguments):

- **R:** Inno Setup. It uses `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /ALLUSERS /LOG=...`.
  `/ALLUSERS` is required, otherwise R installs per user.
- **RStudio:** NSIS with NsisMultiUser. It uses `/S /allusers`, which installs to `Program Files\RStudio`.

## Problems and measures (`Fix-RuRStudio.ps1`)

| Problem | Cause | Measure |
|---|---|---|
| RStudio: "Error Starting R", `rsession` exits with `0xC0000135` | RStudio passes `R_HOME` as an 8.3 short path. The loader does not find `R.dll` in the container. | `Add-MSIXloaderSearchPathOverride` on `VFS\ProgramFilesX64\R\R-4.6.2\bin\x64` |
| `install.packages()`: "'lib = ...' is not writable" | the R library in the package is read-only | R's personal library: `Rprofile.site.append.R` creates `R_LIBS_USER` and puts it first in `.libPaths()` |
| `rstudio.exe` cannot be started by name | App Paths in the package registry are not visible outside | `Add-MSIXAppExecutionAlias rstudio.exe` |
| Installation fails without the Windows App Runtime | dependency added by the capture | `Remove-MSIXDependencies` |
| desktop7 shortcuts, `R 4.6.2.lnk` on the common desktop | no icon, can block the installation | `Remove-MSIXDesktop7Shortcut`, `Remove-Item` |

### Personal R library

- **Behaviour:** R behaves as with a normal installation under `Program Files`, where standard users cannot write
  either.
- **Location:** Windows redirects the folder for the package. The real location is
  `%LOCALAPPDATA%\Packages\RuRStudio_<PublisherId>\LocalCache\Local\R\win-library\4.6`.
- **Lifetime:** it is per user, survives updates and restarts, and is removed when the package is uninstalled.
- **R versions:** the block in `Rprofile.site` is version-neutral. R creates a new personal library for each minor
  version (e.g. `4.7`).

### Why not InstalledLocationVirtualization

ILV solves the library problem when the package is installed. From a CimFS App Attach image, however, the package
does not start (`0x801F000F`, see the [overview](../README.md)). The same fix without ILV starts.

### Why not the PSF (Tim Mangan, release 2026-11-14)

- **MFRFixup:**
  - `install.packages()` still fails. Rgui and Rscript cannot load their base packages
    (`normalizePath(".../R-46~1.2/library")`: path not found).
  - RStudio shows "RStudio cannot write to required folders".
  - The cause is seven defects in the MFRFixup with 8.3 short paths inside the package, CimFS, and the API
    `GetFileInformationByName` used by Electron. The corrected build is in `CustomMFRFixup\` (see below).
- **FileRedirectionFixup:**
  - R cannot rename the extracted package in the redirected folder.
  - RStudio stays grey with "system error 3".
- **Every PSF with RStudio (Electron):**
  - The PsfRuntime is also injected into the sandboxed GPU process, and RStudio ends after about 1 s. The only
    remedy is `--disable-gpu-sandbox`.
  - `Add-MSIXPSFShim` renames the Application Ids.

## Tests (Windows 11, build 26200)

| Test | Installed | CimFS App Attach |
|---|---|---|
| Installation / staging and registration | ok | ok |
| Start of RStudio and Rgui | ok | ok |
| RStudio with R console (rsession running) | ok | ok |
| `install.packages("jsonlite")`, then `library(jsonlite)` in a new process | ok | ok |
| Uninstallation / removal of the image without leftovers | ok | ok |

Not tested: multi-user test on a terminal server.

## Corrected MFRFixup (`CustomMFRFixup\`)

| File | Content |
|---|---|
| `MFRFixup64.dll` | x64 Release build, toolset v143, not signed. SHA256 `b84ae9eba387881373a97634a95b2f8aca561e9823b34e621ee27dc9b7c86c06` |
| `TimManganPSF-MFRFixup-source.zip` | full source of this build, without the release zips. It is Tim Mangan's PSF `develop` (2026-11-14) plus the corrections plus three local build changes (see below). License: MIT, `LICENSE` in the zip. |

The corrections are submitted to Tim Mangan as
[pull request #32](https://github.com/TimMangan/MSIX-PackageSupportFramework/pull/32):

1. **`IsCreateForChange`:** read-only opens no longer count as writes. Before, they pre-created empty folders in the
   redirection area.
2. **`DetermineCohorts`:** a request for `<PackageRoot>\VFS` itself finds the folder.
3. **`ChooseIndexForFindResult`:** it never returns an index without a find handle.
4. **`DetermineCohorts`:** short or mixed 8.3 forms of the package root and of the writable root are expanded.
5. **`FindFirstFile(Ex)`:** returns the 8.3 name of the package or native entry instead of the redirected one.
6. **New hook for `GetFileInformationByName`:** the stat API of libuv/Electron on Windows 11 24H2+.
7. **ILV mode only:** `desktop.ini` and junctions in local redirections are no longer taken for ILV deletion
   markers.

The local build changes are not part of the pull request:
- `ReplaceFile.cpp` and `DeviceIoControl.cpp` are excluded from the project (the first is missing in the
  repository, the second needs the WDK)
- `#include <list>` in `FindData3.h`
- `NuGet.Config`

**Tests on Windows 11 (build 26200):** the RuRStudio package with PSF launcher and MFRFixup passed the tests above in
three modes:
- installed with `ilvAware=false`
- as CimFS App Attach with `ilvAware=false`
- installed with ILV and `ilvAware=true`

In all three, RStudio showed no dialog. The tests used this `MFRFixup64.dll` together with the `PsfRuntime64.dll`
built from the same source, at `debugLevel` 4. RStudio needs `--disable-gpu-sandbox`, and the Application Ids change
(see above), so the personal R library remains the simpler solution.

## For an update

- **Package identity:** keep PackageName `RuRStudio`, the same signing certificate and the Application Ids
  `RSTUDIO` and `RGUI`.
- **New R version:** the path `R\R-4.6.2` appears in the fix three times: `Rprofile.site`, the loader search path
  and the desktop shortcut.
