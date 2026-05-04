# App-V Auto Sequencer — Session Walkthrough

A PowerShell **session script** that demonstrates how to build App-V packages automatically with the **Auto Sequencer** shipped in the Windows ADK. The file is the companion script to a conference session (PSConf, 2018) and is meant to be stepped through interactively — not run end-to-end.

> The script intentionally throws on direct execution:
> `throw "Ups, mark the code and use F8"`
>
> Open it in PowerShell ISE or VS Code, select the block you want to execute and press **F8**.

## What it covers

The script walks through a full Auto-Sequencing pipeline:

1. **Build a base image** — convert a Windows 10 ISO to a VHD with `Convert-WindowsImage`
2. **Prepare the host** — enable PS Remoting, set TrustedHosts, install Hyper-V, create a VSwitch
3. **Roll out a sequencer VM** — `New-AppVSequencerVM` (from the Windows ADK Auto Sequencer module)
4. **Define packages to build** — an XML config listing installer, options, etc.
5. **Run the batch** — `New-BatchAppVSequencerPackages` builds .appv packages inside the VM
6. **Install & test the package** — `Add-AppvClientPackage | Publish-AppvClientPackage`

## Requirements

- Windows 10 / Windows Server with **Hyper-V** capable hardware
- **Windows ADK** with the App-V Auto Sequencer feature installed
  - Default path: `C:\Program Files (x86)\Windows Kits\10\Microsoft Application Virtualization\AutoSequencer\`
- A Windows 10 installation ISO (the script targets 1703 / 1709 era builds)
- Administrative PowerShell session
- Module `Convert-WindowsImage` (the script installs it via `Install-Module`)

## Known caveats (kept as-is from the session notes)

- **German OS workaround** — `New-AppVSequencerVM.psm1` greps DISM output for the literal string `Architecture`. On a German Windows it must be `Architektur` (lines 31 and 37 of that module). Patch the module locally if you run the demo on a German host.
- **Convert-WindowsImage on 1709** — the TechNet Gallery version fails on 1709 ISOs. Use the fork at <https://github.com/nerdile/convert-windowsimage> instead.
- **Telemetry DLL bug** — `AutoSequencingTelemetry.psm1` may fail with `Join-Path: Cannot bind argument to parameter 'Path' because it is null`. The script contains the original investigation notes around line 134.
- **App-V is deprecated by Microsoft.** This material is historical / educational. Use it for understanding Auto Sequencer mechanics, not as a recommendation for new packaging pipelines.

## Files

| File | Purpose |
|------|---------|
| `Automatisierung_der_Erstellung_von_Softwarepaketen_mit_PowerShell.ps1` | The session walkthrough — step through with F8 |

