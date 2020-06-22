
Param(
    [ValidateSet('x86','x64')]
    [string] $Architecture = 'x64',
    [Switch] $RemoveDesktopIcons,
    [System.IO.DirectoryInfo] $DownloadPath = 'Q:\PackageScripts\Notepad++\Source\'
)

function Get-LatestVersionNPP{
    
    $URI = 'https://notepad-plus-plus.org/downloads/'
    $content = Invoke-WebRequest -Uri  $URI
    $regex = ‘https://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?’
    $URL = @($content.links.href | Select-String -Pattern $regex -AllMatches)
    $DL = $URL | ForEach-Object {
        [PSCustomObject]@{
            URL = [System.URI] $_.ToString()
            Version = [System.Version] $((Split-Path $_ -Leaf) -replace 'v','')
         }
    } | Sort-Object -Property Version -Descending | Select-Object -First 1

    if($DL -ne $null){
        Write-Verbose $("Get URL :" + $DL.URL)
        Return $DL
    } else {
        Write-Error "Wrong URL, cannot get latest Version"
        Return $Null
    }
}


function Download-LatestVersionNPP{
    param(       
        [ValidateSet('x86','x64')]
        [string] $Architecture = 'x64',
        [Parameter(Mandatory)]
        [System.IO.DirectoryInfo] $OutputPath
     
    )
    $DL = Get-LatestVersionNPP
    if($DL -ne $null){
        $Content = Invoke-WebRequest -Uri $DL.URL
        $regex = ‘https://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?Installer.exe$’
        if($Architecture -eq 'x64'){
            $regex = ‘https://([\w-]+\.)+[\w-]+(/[\w- ./?%&=]*)*?Installer.x64.exe$’
        }

        $URL = @($content.links.href | Select-String -Pattern $regex -AllMatches)[0].ToString()
        if($URL -ne $null){
            Invoke-WebRequest $URL -OutFile $( $OutputPath.FullName + '\' + $(Split-Path $URL -Leaf))
            return  $( $OutputPath.FullName  + $(Split-Path $URL -Leaf))
        }
    }
}


$NPPfile = Download-LatestVersionNPP  -Architecture $Architecture -OutputPath $DownloadPath
if(Test-Path $NPPfile){
  #Unblock-File $NPPfile
  Copy-Item $NPPfile -Destination c:\Temp\ -Force
  Start-Process -FilePath $('C:\Temp\' + $(Split-Path $NPPfile -Leaf)) -ArgumentList '/S' | Wait-Process
  Remove-Item  $('C:\Temp\' + $(Split-Path $NPPfile -Leaf))  -Force
}