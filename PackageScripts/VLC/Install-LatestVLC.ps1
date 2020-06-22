<#
    AutoSequencer Install Script for the latest VLC Version
#>


Param(
    [ValidateSet('x86','x64')]
    [string] $Architecture = 'x64',
    [Switch] $RemoveDesktopIcons,
    [System.IO.DirectoryInfo] $DownloadPath = 'Q:\PackageScripts\VLC\Source\',
    [System.IO.DirectoryInfo] $LogPath = 'Q:\LogPath\',
    [ValidateSet('English','German')]
    [String] $Language = 'English'
)

$LogFile = $((Get-Date -Format "yyyymmdd-hhmmss") +"_VLC.log")

Start-Transcript -Path $($LogPath.FullName + $LogFile)


$vlcURL = "https://download.videolan.org/vlc/last/win32/"
if($Architecture -eq "x64"){
    $vlcURL = "https://download.videolan.org/vlc/last/win64/"
}


function New-Shortcut{
<#
    .SYNOPSIS
        Create a Shortcut
    .DESCRIPTION
        Create a link based a a spacial folder name
    .PARAMETER  ShortcutFilePath
        relative Path to the SpecialFolder "\appfolder\myapp.lnk" oder simpley "myapp.lnk"
        example LinkLocation = Desktop: ..\Desktop\appfolder\myapp.lnk"
    .PARAMETER  linklocation
        ;andatory, a SpecialFolder name "Desktop","StartMenu" etc.
    .PARAMETER TargetPath
        Mandatory, Path to a exe or batch file etc.
    .PARAMETER Hotkey
        Optional, a Hotkey to start. Example : "CTRL+F"
    .PARAMETER WindowsStyle
        Optional
        1 - Activates and displays a window. If the window is minimized or maximized, the system restores it to its original size and position.
        3 - Activates the window and displays it as a maximized window. 
        7 - Minimizes the window and activates the next top-level window.
    .PARAMETER IconLocation
        Path to the icon file and Icon Number. Example: "C:\Windows\system32\shell32.dll, 1"
   .PARAMETER Arguments
       Optional, command line arguments. Example: /c echo hallo
   .PARAMETER WorkingDirectory
        Optional, execution path of the script or exe
    .PARAMETER $Description
        Optional, a description of your shortcut
    .PARAMETER UACAdmin
        Optinal, run the shortcut as administrator
    .EXAMPLE
        Create a administrative shortcut for notepad.exe in the folder lalula on the Desktop
        Create-Shortcut -ShortcutFilePath "lalula\test2.lnk" -linklocation Desktop -TargetPath c:\Windows\notepad.exe -UACAdmin:$true
 
    .AUTOR
        Andreas Nick' 2016
#>
 
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$ShortcutFilePath,
        [ValidateSet("CommonDesktop", "CommonStartMenu", "CommonPrograms", "CommonStartup", "Desktop", "Favorites", "SendTo", "StartMenu", "Startup")]
        [Parameter(Mandatory = $true)]
        [String]$linklocation,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [String]$Hotkey = "",
        [ValidateSet("1", "3", "7")]
        [String]$WindwosStyle = "1",
        [String]$IconLocation = "",
        [String]$Arguments = "",
        [String]$WorkingDirectory = "",
        [String]$Description = "",
        [switch]$UACAdmin = $false
    )
     
    process
    {
        
         
        If (-not ($ShortcutFilePath -match "\.lnk$"))
        {
            Write-Verbose $('Error: Illigal Shortcut' +  "$ShortcutFilePath"+ ' - a shortcut ends with .lnk')
            throw 'Error: Illigal Shortcut' +  "$ShortcutFilePath"+ ' - a shortcut ends with .lnk'
             
        }
         
        [System.IO.FileInfo] $DestinationPath = [environment]::getfolderpath("$linklocation") + '\' + $ShortcutFilePath
         
        #Check The Path
         
        if (-not (test-path (Split-Path $DestinationPath.FullName -Parent)))
        {
            new-item  -Type Directory  -Path (Split-Path $DestinationPath.FullName -Parent)
        }
 
        #Create a new shortcut for computers or users.
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($DestinationPath.FullName)
        $Shortcut.TargetPath = "$TargetPath"
        $Shortcut.Arguments = $Arguments
        $Shortcut.Description = $Description
        $Shortcut.HotKey = $HotKey
        $Shortcut.WorkingDirectory = $WorkingDirectory
        $Shortcut.WindowStyle = $WindwosStyle
         
        if ($IconLocation -eq "")
        {
            $Shortcut.IconLocation = "C:\Windows\system32\shell32.dll, 17"
        }
        else
        {
            $Shortcut.IconLocation = $IconLocation
        }
         
        try
        {
            $Shortcut.Save()
            if ($UACAdmin)
            {
                [byte[]]$bytes = [System.IO.File]::ReadAllBytes("$DestinationPath")
                $bytes[0x15] = $bytes[0x15] -bor 0x20
                [System.IO.File]::WriteAllBytes("$DestinationPath", $bytes)
            }
        }
        Catch
        {
            Write-Verbose "Cannot create the shortcut $($DestinationPath.FullName)" -Verbose
            Write-Verbose $Error[0].Exception.Message -Verbose
            Return $False
        }
    }

}


$getHTML = Invoke-Webrequest -Uri $vlcURL
$name = ($getHTML.ParsedHtml.getElementsByTagName("a")| Where {$_.innerhtml -like 'vlc-*.exe'}).innertext
$vlcURL = $($vlcURL + $name)

$outFile = $($DownloadPath.FullName +  $name)

#Invoke-WebRequest -Uri $vlcURL -OutFile $outFile

$Version = [String] ($Name | Select-String '[0-9]+(\.[0-9]+)+(\.[0-9]+)' | ForEach-Object {$_.Matches}).Value
$Version | Out-File -FilePath $($outFile -replace '.exe','.info')

$LanguageSwitch = '/L=1031'
if($LanguageSwitch -eq 'English'){
    $LanguageSwitch = '/L=1033'
}

Copy-Item $outFile -Destination C:\Temp\
    Start-Process $('C:\Temp\'+$Name)  -ArgumentList @($LanguageSwitch, '/S') -Wait

Remove-Item  $('C:\Temp\'+$Name) 


if($RemoveDesktopIcons){
 #remove-Item "$env:USERPROFILE\Desktop\VLC media player.lnk" 
 remove-Item "$env:Public\Desktop\VLC media player.lnk" 
}

#Shortcuts not exists here!


#Remove Icons
Remove-Item "$env:ALLUSERSPROFILE\Microsoft\windows\start Menu\Programs\VideoLAN\VLC media player - reset preferences and cache files.lnk" -ea SilentlyContinue
Remove-Item "$env:ALLUSERSPROFILE\Microsoft\windows\start Menu\Programs\VideoLAN\VLC media player skinned.lnk" -ea SilentlyContinue
Remove-Item "$env:ALLUSERSPROFILE\Microsoft\windows\start Menu\Programs\VideoLAN\VLC media player.lnk" -ea SilentlyContinue
Remove-Item "$env:ALLUSERSPROFILE\Microsoft\windows\start Menu\Programs\VideoLAN\VideoLAN Website.lnk" -ea SilentlyContinue
Remove-Item "$env:ALLUSERSPROFILE\Microsoft\windows\start Menu\Programs\VideoLAN\Release Notes.lnk" -ea SilentlyContinue
Remove-Item "$env:ALLUSERSPROFILE\Microsoft\windows\start Menu\Programs\VideoLAN\Documentation.lnk" -ea SilentlyContinue

if($Architecture -eq 'x64'){
    New-Shortcut -ShortcutFilePath "Programs\VideoLAN\VLC media player.lnk" -linklocation CommonStartMenu -TargetPath  "C:\Program Files\VideoLAN\VLC\vlc.exe" `    -Arguments '--no-qt-privacy-ask --no-qt-updates-notif' -IconLocation "C:\Program Files\VideoLAN\VLC\vlc.exe" 
} else {
    New-Shortcut -ShortcutFilePath "Programs\VideoLAN\VLC media player.lnk" -linklocation CommonStartMenu -TargetPath  "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe" `    -Arguments '--no-qt-privacy-ask --no-qt-updates-notif' -IconLocation "C:\Program Files (x86)\VideoLAN\VLC\vlc.exe" 
}


Stop-Transcript 
