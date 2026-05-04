<#
.SYNOPSIS
  Folder size analyzer with an interactive HTML report.

.DESCRIPTION
  Recursively scans a folder and generates an HTML report featuring:
    - collapsible tree structure
    - per-column sorting (click on header)
    - live filter / search
    - top-N largest files
    - progress output
  Siblings are sorted by size in descending order.

.PARAMETER Path
  Root path for the analysis. Default: C:\

.PARAMETER MaxDepth
  Maximum recursion depth for the visible tree. Default: 4

.PARAMETER MinSizeMB
  Minimum folder size in MB required for a folder to appear in the report.
  The root folder is always shown. Default: 10

.PARAMETER TopFiles
  Number of largest individual files that are additionally listed. Default: 50

.PARAMETER Output
  Path to the HTML output file. Default: %TEMP%\FolderSize_Report.html

.PARAMETER NoOpen
  If set, the report is not opened automatically.

.EXAMPLE
  .\get-FolderSize.ps1 -Path "C:\" -MaxDepth 4 -MinSizeMB 100

.EXAMPLE
  .\get-FolderSize.ps1 -Path "$env:USERPROFILE" -MaxDepth 6 -MinSizeMB 10

.NOTES
  Run as administrator for a complete analysis of C:\.
#>
param(
    [string]$Path      = "C:\",
    [int]   $MaxDepth  = 4,
    [int]   $MinSizeMB = 10,
    [int]   $TopFiles  = 50,
    [string]$Output    = "$env:TEMP\FolderSize_Report.html",
    [switch]$NoOpen
)

# --- Helper functions --------------------------------------------------------
function Format-Size {
    param([int64]$Bytes)
    if     ($Bytes -ge 1TB) { "{0:N2} TB" -f ($Bytes / 1TB) }
    elseif ($Bytes -ge 1GB) { "{0:N2} GB" -f ($Bytes / 1GB) }
    elseif ($Bytes -ge 1MB) { "{0:N1} MB" -f ($Bytes / 1MB) }
    elseif ($Bytes -ge 1KB) { "{0:N0} KB" -f ($Bytes / 1KB) }
    else                    { "$Bytes B" }
}

function HtmlEnc {
    param([string]$s)
    if (-not $s) { return "" }
    $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;').Replace("'",'&#39;')
}

# --- Global collectors -------------------------------------------------------
$global:AlleOrdner   = New-Object System.Collections.Generic.List[object]
$global:TopFilesList = New-Object System.Collections.Generic.List[object]
$global:Counter      = 0
$global:Id           = 0

# --- Recursive analysis ------------------------------------------------------
function Get-Tree {
    param([string]$Path, [int]$Ebene, [int]$ParentId)

    $eigeneId = ++$global:Id
    $global:Counter++
    if ($global:Counter % 50 -eq 0) {
        Write-Host "  ... $($global:Counter) folders scanned" -ForegroundColor DarkGray
    }

    # Create the node FIRST so parents appear before their children in the list
    # (otherwise the tree visually expands upward).
    $node = [PSCustomObject]@{
        Id          = $eigeneId
        ParentId    = $ParentId
        Ebene       = $Ebene
        Pfad        = $Path
        Name        = if ($Ebene -eq 0) { $Path } else { Split-Path $Path -Leaf }
        Bytes       = [int64]0
        EigeneBytes = [int64]0
        Dateien     = 0
        Unterordner = 0
        KindIds     = @()
    }
    $global:AlleOrdner.Add($node)

    $eigenBytes  = [int64]0
    $dateiAnzahl = 0
    $unterordner = @()

    try {
        Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction Stop | ForEach-Object {
            $eigenBytes += $_.Length
            $dateiAnzahl++
            if ($TopFiles -gt 0) {
                $global:TopFilesList.Add([PSCustomObject]@{
                    Pfad  = $_.FullName
                    Bytes = $_.Length
                    Datum = $_.LastWriteTime
                })
            }
        }
        $unterordner = @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction Stop)
    } catch {
        # Access denied or similar -> skip
    }

    $node.EigeneBytes = $eigenBytes
    $node.Unterordner = $unterordner.Count

    # Pre-sort siblings by size -> large folders appear at the top
    $unterMitGroesse = foreach ($u in $unterordner) {
        $s = (Get-ChildItem -LiteralPath $u.FullName -Recurse -File -Force -ErrorAction SilentlyContinue |
              Measure-Object Length -Sum).Sum
        [PSCustomObject]@{
            Item = $u
            Size = if ($s) { [int64]$s } else { [int64]0 }
        }
    }
    $unterMitGroesse = $unterMitGroesse | Sort-Object Size -Descending

    $kinderBytes   = [int64]0
    $kinderDateien = 0
    $kindIds       = @()

    foreach ($eintrag in $unterMitGroesse) {
        $u = $eintrag.Item
        if ($Ebene -lt $MaxDepth) {
            $erg = Get-Tree -Path $u.FullName -Ebene ($Ebene + 1) -ParentId $eigeneId
            $kinderBytes   += $erg.Bytes
            $kinderDateien += $erg.Dateien
            $kindIds       += $erg.Id
        } else {
            # Depth limit reached: use size from the pre-scan
            $kinderBytes += $eintrag.Size
        }
    }

    $node.Bytes   = $eigenBytes + $kinderBytes
    $node.Dateien = $dateiAnzahl + $kinderDateien
    $node.KindIds = $kindIds

    return [PSCustomObject]@{ Bytes = $node.Bytes; Dateien = $node.Dateien; Id = $eigeneId }
}

# --- Execution ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Path)) {
    Write-Host "Path not found: $Path" -ForegroundColor Red
    exit 1
}

Write-Host "Analyzing $Path (max. depth $MaxDepth) ..." -ForegroundColor Cyan
$start = Get-Date
[void](Get-Tree -Path $Path -Ebene 0 -ParentId 0)
$dauer = (Get-Date) - $start
Write-Host ("Done: {0} folders in {1:N1}s" -f $global:Counter, $dauer.TotalSeconds) -ForegroundColor Green

# --- Filtering ---------------------------------------------------------------
$rootBytes = ($global:AlleOrdner | Where-Object Ebene -eq 0 | Select-Object -First 1).Bytes
$gefiltert = $global:AlleOrdner | Where-Object {
    $_.Ebene -eq 0 -or ($_.Bytes / 1MB) -ge $MinSizeMB
}

$topFilesSorted = $global:TopFilesList | Sort-Object Bytes -Descending | Select-Object -First $TopFiles

# --- Build HTML tables -------------------------------------------------------
$rows = New-Object System.Text.StringBuilder
foreach ($n in $gefiltert) {
    $prozent = if ($rootBytes -gt 0) { [math]::Round($n.Bytes / $rootBytes * 100, 1) } else { 0 }
    $hatKinder = ($n.KindIds.Count -gt 0)
    $toggle = if ($hatKinder) { "<span class='tg'>&#9656;</span>" } else { "<span class='tg-leaf'></span>" }
    $name    = HtmlEnc $n.Name
    $pfad    = HtmlEnc $n.Pfad
    $size    = Format-Size $n.Bytes
    $own     = Format-Size $n.EigeneBytes
    $padding = $n.Ebene * 18
    $hidden  = if ($n.Ebene -gt 0) { "hidden" } else { "" }

    [void]$rows.AppendLine(@"
<tr data-id='$($n.Id)' data-parent='$($n.ParentId)' data-ebene='$($n.Ebene)'
    data-bytes='$($n.Bytes)' data-files='$($n.Dateien)' data-subs='$($n.Unterordner)'
    data-name='$($name.ToLower())' class='row $hidden'>
  <td class='c-name'>
    <span style='display:inline-block;width:${padding}px'></span>$toggle
    <span class='nm' title='$pfad'>$name</span>
  </td>
  <td class='num'>$size</td>
  <td class='num'>$own</td>
  <td class='num'>$($n.Dateien)</td>
  <td class='num'>$($n.Unterordner)</td>
  <td class='bar-cell'>
    <div class='bar-bg'><div class='bar-fg' style='width:${prozent}%'></div></div>
    <span class='pct'>${prozent}%</span>
  </td>
</tr>
"@)
}

$topRows = New-Object System.Text.StringBuilder
foreach ($f in $topFilesSorted) {
    $p = HtmlEnc $f.Pfad
    [void]$topRows.AppendLine("<tr><td class='c-name' title='$p'>$p</td><td class='num'>$(Format-Size $f.Bytes)</td><td class='num'>$($f.Datum.ToString('yyyy-MM-dd HH:mm'))</td></tr>")
}

$datum   = Get-Date -Format 'dd.MM.yyyy HH:mm'
$pfadEsc = HtmlEnc $Path
$gesamt  = Format-Size $rootBytes

# --- Write HTML file ---------------------------------------------------------
$html = @"
<!DOCTYPE html>
<html lang='en'>
<head>
<meta charset='UTF-8'>
<title>Folder Size Report - $pfadEsc</title>
<style>
  *{box-sizing:border-box}
  body{font-family:'Segoe UI',system-ui,sans-serif;background:#0f1419;color:#e0e6ed;margin:0;padding:0;font-size:13px}
  header{background:#1a2332;border-bottom:2px solid #2d4263;padding:14px 20px}
  h1{margin:0;color:#5dade2;font-size:20px;font-weight:500}
  .meta{margin-top:6px;color:#8899a6;font-size:12px;display:flex;gap:20px;flex-wrap:wrap}
  .meta strong{color:#e0e6ed}
  .toolbar{background:#16202c;padding:10px 20px;display:flex;gap:10px;align-items:center;border-bottom:1px solid #2d4263}
  .toolbar input,.toolbar button{background:#0f1419;color:#e0e6ed;border:1px solid #2d4263;padding:6px 10px;border-radius:4px;font-size:13px}
  .toolbar input{flex:1;max-width:400px}
  .toolbar button{cursor:pointer}
  .toolbar button:hover{background:#1a2332;border-color:#5dade2}
  main{padding:0 20px 20px}
  table{width:100%;border-collapse:collapse;margin-top:14px}
  thead th{background:#1a2332;color:#5dade2;text-align:left;padding:9px 10px;font-weight:500;font-size:12px;
           text-transform:uppercase;letter-spacing:0.5px;position:sticky;top:0;cursor:pointer;user-select:none;
           border-bottom:1px solid #2d4263}
  thead th:hover{background:#22324a}
  thead th.num,td.num{text-align:right;white-space:nowrap}
  td{padding:6px 10px;border-bottom:1px solid #1a2332}
  tr.row:hover{background:#1a2332}
  tr.hidden{display:none}
  .tg{display:inline-block;width:14px;color:#5dade2;cursor:pointer;transition:transform .15s;font-size:10px}
  .tg.open{transform:rotate(90deg)}
  .tg-leaf{display:inline-block;width:14px}
  .nm{color:#e0e6ed}
  .c-name{max-width:520px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
  .bar-cell{width:200px;display:flex;align-items:center;gap:8px}
  .bar-bg{flex:1;height:14px;background:#1a2332;border-radius:3px;overflow:hidden}
  .bar-fg{height:100%;background:linear-gradient(90deg,#2d4263,#5dade2);border-radius:3px}
  .pct{color:#8899a6;font-size:11px;min-width:42px;text-align:right}
  h2{color:#5dade2;font-size:15px;font-weight:500;margin:28px 0 8px;border-bottom:1px solid #2d4263;padding-bottom:6px}
  .badge{display:inline-block;background:#2d4263;color:#5dade2;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:500}
</style>
</head>
<body>
<header>
  <h1>Folder Size Report</h1>
  <div class='meta'>
    <span>Path: <strong>$pfadEsc</strong></span>
    <span>Total: <strong>$gesamt</strong></span>
    <span>Folders: <strong>$($gefiltert.Count)</strong></span>
    <span>Min: <strong>${MinSizeMB} MB</strong></span>
    <span>Max depth: <strong>$MaxDepth</strong></span>
    <span>Created: <strong>$datum</strong></span>
  </div>
</header>
<div class='toolbar'>
  <input type='text' id='search' placeholder='Filter (folder name)...'>
  <button onclick='expandAll()'>Expand all</button>
  <button onclick='collapseAll()'>Collapse all</button>
  <span class='badge' id='visibleCount'></span>
</div>
<main>
<table id='tree'>
  <thead>
    <tr>
      <th data-sort='name'>Folder</th>
      <th class='num' data-sort='bytes'>Size</th>
      <th class='num' data-sort='own'>Own</th>
      <th class='num' data-sort='files'>Files</th>
      <th class='num' data-sort='subs'>Subfolders</th>
      <th>Share</th>
    </tr>
  </thead>
  <tbody>
$($rows.ToString())
  </tbody>
</table>

<h2>Top $TopFiles largest files</h2>
<table>
  <thead><tr><th>File</th><th class='num'>Size</th><th class='num'>Modified</th></tr></thead>
  <tbody>
$($topRows.ToString())
  </tbody>
</table>
</main>
<script>
const rows = Array.from(document.querySelectorAll('tr.row'));
const childrenMap = {};
rows.forEach(r => {
  const p = r.dataset.parent;
  (childrenMap[p] = childrenMap[p] || []).push(r);
});

document.querySelectorAll('.tg').forEach(t => {
  t.addEventListener('click', e => {
    e.stopPropagation();
    const tr = t.closest('tr');
    const id = tr.dataset.id;
    const open = t.classList.toggle('open');
    t.innerHTML = open ? '&#9662;' : '&#9656;';
    toggleChildren(id, open);
  });
});

function toggleChildren(id, show) {
  const kids = childrenMap[id] || [];
  kids.forEach(k => {
    if (show) {
      k.classList.remove('hidden');
    } else {
      k.classList.add('hidden');
      const t = k.querySelector('.tg');
      if (t && t.classList.contains('open')) {
        t.classList.remove('open');
        t.innerHTML = '&#9656;';
        toggleChildren(k.dataset.id, false);
      }
    }
  });
  updateCount();
}

function expandAll() {
  document.querySelectorAll('.tg').forEach(t => { t.classList.add('open'); t.innerHTML='&#9662;'; });
  rows.forEach(r => r.classList.remove('hidden'));
  updateCount();
}
function collapseAll() {
  document.querySelectorAll('.tg').forEach(t => { t.classList.remove('open'); t.innerHTML='&#9656;'; });
  rows.forEach(r => { if (r.dataset.ebene !== '0') r.classList.add('hidden'); });
  updateCount();
}

document.getElementById('search').addEventListener('input', e => {
  const q = e.target.value.toLowerCase().trim();
  if (!q) { collapseAll(); return; }
  rows.forEach(r => {
    if (r.dataset.name.includes(q)) r.classList.remove('hidden');
    else r.classList.add('hidden');
  });
  updateCount();
});

document.querySelectorAll('th[data-sort]').forEach(th => {
  let asc = false;
  th.addEventListener('click', () => {
    const key = th.dataset.sort;
    asc = !asc;
    const tbody = document.querySelector('#tree tbody');
    const sorted = rows.slice().sort((a,b) => {
      let va, vb;
      switch (key) {
        case 'name':  va=a.dataset.name;   vb=b.dataset.name;   break;
        case 'files': va=+a.dataset.files; vb=+b.dataset.files; break;
        case 'subs':  va=+a.dataset.subs;  vb=+b.dataset.subs;  break;
        default:      va=+a.dataset.bytes; vb=+b.dataset.bytes;
      }
      if (va < vb) return asc ? -1 : 1;
      if (va > vb) return asc ? 1 : -1;
      return 0;
    });
    sorted.forEach(r => tbody.appendChild(r));
  });
});

function updateCount() {
  const visible = rows.filter(r => !r.classList.contains('hidden')).length;
  document.getElementById('visibleCount').textContent = visible + ' visible';
}
updateCount();
</script>
</body></html>
"@

$html | Out-File -FilePath $Output -Encoding UTF8
Write-Host "Report saved: $Output" -ForegroundColor Green

if (-not $NoOpen) { Start-Process $Output }