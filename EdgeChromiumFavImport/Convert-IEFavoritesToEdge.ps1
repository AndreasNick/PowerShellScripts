
<#
    .SYNOPSIS
    This script migrates the favorite location folder to an Edge Chromium bookmark file
    
    .DESCRIPTION
    this script migrates the favorite location folder to an Edge Chromium bookmark file. 
    The script may work for chrome as well. It will create a backup of the old existing 
    bookmark file. The script will abort if the Edge Browse is running in the background. 
    Unless the ForceWriteBookmarks parameter is used. If you use a folder other than "Other" 
    ("Other Favorites",ger. "Andere Favoriten") then a folder is created under "bookmark_bar". 
    Apparently it is not possible to create more folders in another place.
    The script must be executed in the user context. You might also be able to have a folder
    with profiles automatically
    
    .PARAMETER FavoritesPath
    Path to Favorites Folder $ENV:Userprofile\Favorites
    
    .PARAMETER BookmarkPath
    Path to the Edge Bookmark file (\Microsoft\Edge\User Data\Default\Bookmarks)
    With chrome it should also work
  
    .PARAMETER EdgeBookmarkImportFolder
    The default folder here is "Other" (other favorites). If a different folder name is specified,
    a subfolder is created in the Favorites bar. Otherwise everything will be placed under Other Favorites.
    
    .EXAMPLE
    An example
    
    .NOTES
    Andreas Nick 2020
    
    #>

[CmdletBinding()]
Param
(
    [System.IO.DirectoryInfo] $FavoritesPath = $("$Env:USERPROFILE" + "\favorites"),
    [System.IO.DirectoryInfo] $BookmarkPath = $($Env:LOCALAPPDATA + "\Microsoft\Edge\User Data\Default\Bookmarks"),
    [String] $EdgeBookmarkImportFolder = "Other", #"Import from Internet Explorer",
    #[String] $EdgeBookmarkImportFolder = "Import IE",
    [switch] $ForceStopEdge = $false,
    [String] $RunOnceKey = "HKCU:\Software\_NICKIT\EdgeFavoritesMigration",
    [bool] $UserRunOnceKey = $true
    
)


function Get-Favorit {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [System.io.FileInfo] $ShortcutPath
    )
    $obj = New-Object -ComObject WScript.Shell
    # If that's not possible, with some URL's we get for a crash
    $ShortcutPath = [System.io.FileInfo] [Management.Automation.WildcardPattern]::Escape($ShortcutPath)

    
    try {
        $link = $obj.CreateShortcut($ShortcutPath)
    }
    catch {
        Write-Host "Cannot Open $ShortcutPath" 
    }

    $object = "" | Select-Object -Property FavoriteLink, TargetPath, CreationTime, ChromeTimeStamp
    #Error handling for very long names ?
    $object.FavoriteLink = Split-Path $ShortcutPath.FullName -Leaf
    $object.TargetPath = $link.TargetPath
    $CreationDate = [datetime] $ShortcutPath.LastWriteTime
    $object.CreationTime = $CreationDate
    $ChromeTimeStamp = [int64] ((New-TimeSpan -Start (Get-Date -Date "01/01/1601")  -End $CreationDate).TotalMilliseconds ) * 1000
    $object.ChromeTimeStamp = $ChromeTimeStamp
    [Runtime.InteropServices.Marshal]::ReleaseComObject($link) | Out-Null
    return $object
}
function New-EdgeBookmarkEntry {
    param
    (
        $id,
        $date_added,
        $name,
        $url
    )

    process {
        $BookmarkEntry = @'
{
        "date_added": "13232452287381997",
        "guid": "e9873aff-ff33-4b3b-9e94-291ba63bf259",
        "id": "4",
        "name": "URANOS Settings",
        "show_icon": false,
        "source": "user_add",
        "type": "url",
        "url": ""
}
'@
        $JBookmarkEntry = ConvertFrom-Json -InputObject $BookmarkEntry
        $JBookmarkEntry.date_added = [String] $date_added
        $JBookmarkEntry.id = [String] $id
        $JBookmarkEntry.name = $name
        $JBookmarkEntry.guid = [system.guid]::NewGuid()
        $JBookmarkEntry.url = $url

        Return $JBookmarkEntry
    }
}

function New-EdgeBookmarkFolder {
    param
    (
        $id,    
        [String] $Name,
        $date_added
        
    )

    process {
        $Folder = @'
{
    "children":  [
                 ],
    "date_added":  "13227648567132117",
    "date_modified":  "0",
    "guid":  "00000000-0000-4000-A000-000000000004",
    "id":  "",
    "name":  "",
    "source":  "unknown",
    "type":  "folder"
}
'@

        $JFolder = ConvertFrom-Json -InputObject $Folder
        $JFolder.date_added = [String] $date_added
        $JFolder.id = [String] $id
        $JFolder.name = $name
        $JFolder.guid = [system.guid]::NewGuid()
        Return $JFolder
    }
}

function find-BookmarkIDCount {
    param(
        [PSCustomObject] $object
    )
    #Write-Host "Run IDCount"
    foreach ($item in ($object | Get-Member -MemberType NoteProperty)) {
        if (($object.($item.name).GetType().name -eq "PSCustomObject")) {
            #Recrusiv
            #Write-Host $("Recruse :" + $($item.name))
            find-BookmarkIDCount $object.($item.name)    
        }
        elseif (($object.($item.name).GetType().name -eq "Object[]")) {
            foreach ($child in ($Object.children)) {
                find-BookmarkIDCount -object $child
            }
        }
        else {
            if ($item.name -eq "id") {
                [int] $Object.id
            }
        }
    }
}


function Get-SortedFavorites {
param(
    [System.IO.DirectoryInfo] $BaseFolder,
    $BaseList
    )
    
    $Files = New-Object System.Collections.ArrayList
    $follist = @(Get-ChildItem $BaseFolder  -Directory | Sort-Object)
    $follist +=  @(Get-ChildItem $BaseFolder -Filter *.url | Sort-Object)

    foreach ($scut in $follist) {
        if ($scut -is [System.IO.DirectoryInfo]) 
        {
            #$Directories += $scut
            $Script:MaxId++
            $CreationDate = [datetime] (Get-ItemProperty -Path $scut.FullName -Name CreationTime ).CreationTime 
            $ChromeTimeStamp = [int64] ((New-TimeSpan -Start (Get-Date -Date "01/01/1601") -End $CreationDate).TotalMilliseconds ) * 1000

            $Dir = New-EdgeBookmarkFolder -id $Script:MaxId -date_added  $ChromeTimeStamp -Name $scut.Name
            Write-Verbose $($scut.FullName)
            $BaseList += $dir
            $Dir.children += Get-SortedFavorites -BaseFolder $scut.FullName -BaseList $Dir.children
        }
        else #Add favorite file the a file List
        {
            $Files += $scut 
        }
    }
    #Add the files unerneath the last directory
    foreach ($scut  in $Files) {
        $Script:MaxId++
        $sk = Get-Favorit -ShortcutPath $scut.fullName
        $EdgeBookmark = New-EdgeBookmarkEntry $Script:MaxId -date_added $sk.ChromeTimeStamp -name $sk.FavoriteLink -url $sk.TargetPath
        $BaseList += $EdgeBookmark
    }

    return $BaseList
}

$JBookmarks = $null
$Continue = $True

#Test Run Once Key
if($UserRunOnceKey){
    if($null -ne (Get-Item $RunOnceKey -ErrorAction SilentlyContinue)){
        $Continue = $false
        Write-Verbose "Run once key exist. Skip script"
    }
}

#exist Bookmark file?
if (Test-Path $BookmarkPath){
    $JBookmarks = Get-Content -Raw -Path $BookmarkPath | ConvertFrom-Json
    #Backup
    $ChromeTimeStamp = Get-Date   -UFormat "%Y%m%d%H%M%S"
    Copy-Item $BookmarkPath -Destination $("$BookmarkPath" +'_' + $ChromeTimeStamp + '.old') 
} else {
    $Continue = $false
}

#Find highest ID
[int] $Script:MaxId = find-BookmarkIDCount -object $JBookmarks | Sort-Object -Descending | Select-Object -first 1

#Force stop msedge
if($null -ne (get-process -Name msedge -ea SilentlyContinue) ){
    #Edge Process is active. We cannot change the bookmarks with an active Edge process
    if($ForceStopEdge){
        get-process msedge -ea SilentlyContinue   | Stop-Process
    } 
    else {
        Write-Warning  "We cannot change the bookmarks with an active Edge process. Please use the ForceStopEdge switch"  
        $Continue = $false
    }
}

if ($Continue -or $forceWriteBookmarks) {

    $EList = new-object System.Collections.ArrayList
    #Create new folder. This is only possible in the Bookmark Bar
    if ($EdgeBookmarkImportFolder -ne "other") {
        $Script:MaxId++
        $Dir = New-EdgeBookmarkFolder -id $Script:MaxId -date_added  "13228497356305428" -Name $EdgeBookmarkImportFolder
        $BookmarkBar = New-Object System.Collections.ArrayList
        $BookmarkBar = $JBookmarks."roots"."bookmark_bar".children
    
        #Create Bookmarks
        $NewList = Get-SortedFavorites -BaseFolder $FavoritesPath -BaseList $EList
        $Dir.children = $NewList 
        $BookmarkBar += $Dir
        $JBookmarks."roots"."bookmark_bar".children = $BookmarkBar
    
    }
    else {
        #Read existing Elements
        $EList += $JBookmarks."roots"."Other".children
        #Create Bookmarks
        $NewList = Get-SortedFavorites -BaseFolder $FavoritesPath -BaseList $EList
        $JBookmarks."roots"."Other".children = $NewList
    }

    $JBookmarks | ConvertTo-Json -Depth 32 | Set-Content $BookmarkPath  -Encoding Utf8 

    #Test Run Once Key
    if ($UserRunOnceKey) {
        if ($null -eq (Get-Item $RunOnceKey -ErrorAction SilentlyContinue)) {
            New-Item $RunOnceKey -Force | Out-Null	
        }
    }
    Write-Verbose $("Processed items :" + $Script:MaxId ) 
} else {
    Write-Warning "the process was aborted. Use -verbose for details"
}


