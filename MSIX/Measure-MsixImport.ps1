#Requires -Version 5.1
<#
.SYNOPSIS
    Measures, per MSIX/AppX package, how long identity extraction and a full SHA-256 take.

.DESCRIPTION

    Scans a folder recursively, takes the newest packages by write time, and prints one
    row per package plus totals. Bundles are read via AppxMetadata/AppxBundleManifest.xml
    (their identity lives there; a bundle has no top-level AppxManifest.xml).

.PARAMETER Path
    Folder or share to scan recursively.

.PARAMETER Count
    How many of the newest packages to measure. Default 50.

.EXAMPLE
    .\Measure-MsixImport.ps1 -Path \\server\MsixRepository
.NODE
     Andreas Nick 2026


#>
    $Path = '\\server1\Autosequencer\MSIXPackages\'
    [int] $Count = 50

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path -LiteralPath $Path)) { throw "Folder not found: $Path" }

$extensions = @('.msix', '.appx', '.msixbundle', '.appxbundle')

Write-Host "Scanning $Path ..." -ForegroundColor Cyan
$packages = Get-ChildItem -LiteralPath $Path -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First $Count

if (-not $packages) { Write-Host "No packages found."; exit 0 }
Write-Host ("Measuring the {0} newest of them ..." -f @($packages).Count) -ForegroundColor Cyan
Write-Host ''

$results = New-Object System.Collections.Generic.List[object]
$stopwatch = New-Object System.Diagnostics.Stopwatch

foreach ($file in $packages) {
    $row = [ordered]@{
        File       = $file.Name
        MB         = [math]::Round($file.Length / 1MB, 1)
        Name       = ''
        Version    = ''
        Arch       = ''
        ManifestMs = $null
        HashMs     = $null
        Error      = ''
    }

    # --- Identity from the manifest (size-independent: central directory + one entry) ---
    try {
        $stopwatch.Restart()
        $zip = [System.IO.Compression.ZipFile]::OpenRead($file.FullName)
        try {
            $entry = $zip.GetEntry('AppxManifest.xml')
            if (-not $entry) { $entry = $zip.GetEntry('AppxMetadata/AppxBundleManifest.xml') }
            if (-not $entry) { throw 'no AppxManifest.xml / AppxBundleManifest.xml' }

            $reader = New-Object System.IO.StreamReader($entry.Open())
            try { $xml = [xml]$reader.ReadToEnd() } finally { $reader.Dispose() }

            # PowerShell property access ignores namespaces, so one line covers both roots.
            $identity = $xml.DocumentElement.Identity
            $row.Name    = $identity.Name
            $row.Version = $identity.Version
            $row.Arch    = if ($identity.PSObject.Properties['ProcessorArchitecture']) {
                               $identity.ProcessorArchitecture
                           } else { 'bundle' }
        }
        finally { $zip.Dispose() }
        $stopwatch.Stop()
        $row.ManifestMs = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 1)
    }
    catch {
        $row.Error = "manifest: $($_.Exception.Message)"
    }

    # --- Full SHA-256 (streams every byte) ---
    try {
        $stopwatch.Restart()
        $stream = [System.IO.File]::OpenRead($file.FullName)
        try {
            $sha = [System.Security.Cryptography.SHA256]::Create()
            try { [void]$sha.ComputeHash($stream) } finally { $sha.Dispose() }
        }
        finally { $stream.Dispose() }
        $stopwatch.Stop()
        $row.HashMs = [math]::Round($stopwatch.Elapsed.TotalMilliseconds, 0)
    }
    catch {
        $row.Error = ($row.Error + " hash: $($_.Exception.Message)").Trim()
    }

    $obj = [pscustomobject]$row
    $results.Add($obj)
    Write-Host ("{0,9:N1} MB  manifest {1,7:N1} ms  hash {2,8:N0} ms  {3} v{4}  {5}" -f `
        $obj.MB, $obj.ManifestMs, $obj.HashMs, $obj.Name, $obj.Version, $obj.Error)
}

# --- Totals ---
$measured = $results | Where-Object { $null -ne $_.ManifestMs -and $null -ne $_.HashMs }
if ($measured) {
    $sumMb       = ($measured | Measure-Object MB -Sum).Sum
    $sumManifest = ($measured | Measure-Object ManifestMs -Sum).Sum
    $sumHash     = ($measured | Measure-Object HashMs -Sum).Sum

    Write-Host ''
    Write-Host ('=' * 78)
    Write-Host ("Packages measured : {0}  ({1:N0} MB)" -f @($measured).Count, $sumMb)
    Write-Host ("Identity total    : {0,10:N0} ms   (avg {1,7:N1} ms per package)" -f `
        $sumManifest, ($sumManifest / @($measured).Count))
    Write-Host ("SHA-256 total     : {0,10:N0} ms   (avg {1,7:N1} ms per package)" -f `
        $sumHash, ($sumHash / @($measured).Count))
    if ($sumManifest -gt 0) {
        Write-Host ("Hash costs {0:N0}x the identity read." -f ($sumHash / $sumManifest))
    }
}

$failed = $results | Where-Object { $_.Error }
if ($failed) {
    Write-Host ''
    Write-Host ("{0} package(s) with errors - see the Error column above." -f @($failed).Count) -ForegroundColor Yellow
}
