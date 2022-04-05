# WinGet Version Installation Scrip for Server 2019
# Work with Version 1.2.10271 or internal Version="1.17.10271.0"
# Or Bundle Version="2022.127.2322.0" 
# Andreas Nick 2022

Write-Host "Download and install winget" -ForegroundColor Yellow

if(!(Get-Module -ListAvailable -Name 'NTObjectManager')){
    Install-Module  'NTObjectManager' -scope CurrentUser -Force -Confirm:$false
    
} 

Import-Module  'NTObjectManager'

$Offline = $false 
$RepoPath = "$env:TEMP\WinGetTemp"
$BaseURL = 'https://www.microsoft.com/store/productId/9NBLGGH4NNS1'
$DownloadFiles = @( 'Microsoft.DesktopAppInstaller_2022.127.2322.0_neutral_~_8wekyb3d8bbwe.msixbundle',
                     'Microsoft.VCLibs.140.00.UWPDesktop_14.0.30704.0_x64__8wekyb3d8bbwe.appx',
                     'Microsoft.UI.Xaml.2.7_7.2203.17001.0_x64__8wekyb3d8bbwe.appx')

# Version 1.2.10271 !!
$LicenseFileURL = 'https://github.com/microsoft/winget-cli/releases/download/v1.2.10271/b0a0692da1034339b76dce1c298a1e42_License1.xml'

if(Test-Path $RepoPath   ) 
{
   #Remove-Item $RepoPath -Recurse 
} else {
    New-Item $RepoPath -ItemType Directory
}

function Get-AppXPackageURL {
[CmdletBinding()]
param (
  [string]$Uri,
  [string]$Filter = '.*' #Regex
)
   
  process {
    #$Uri=$StoreLink
    $WebResponse = Invoke-WebRequest -UseBasicParsing -Method 'POST' -Uri 'https://store.rg-adguard.net/api/GetFiles' -Body "type=url&url=$Uri&ring=Retail" -ContentType 'application/x-www-form-urlencoded'
    $result =$WebResponse.Links.outerHtml | Where-Object {($_ -like '*.appx*') -or ($_ -like '*.msix*')} | Where-Object {$_ -like '*_neutral_*' -or $_ -like "*_"+$env:PROCESSOR_ARCHITECTURE.Replace("AMD","X").Replace("IA","X")+"_*"} | ForEach-Object {
       $result = "" | Select-Object -Property filename, downloadurl
       if( $_ -match '(?<=rel="noreferrer">).+(?=</a>)' )
       {
         $result.filename = $matches.Values[0]
       }
       if( $_ -match '(?<=a href=").+(?=" r)' )
       {
         $result.downloadurl = $matches.Values[0]
       }
       $result
    } 
    $result | Where-Object -Property filename -Match $filter 
  }
}


#Download Winget 2022.127.2322.0 and Dependencies
$Packlist = @()
if(-not $Offline){
  $Packlist = @(Get-AppXPackageURL -Uri $BaseURL)
  #Download License file
  Invoke-WebRequest -Uri $LicenseFileURL -OutFile (Join-Path $RepoPath -ChildPath 'license.xml' )

  #Download package files
  foreach($item in $DownloadFiles)
  {
    if(-not (Test-Path (Join-Path $RepoPath  -ChildPath $item )))
    {
       $dlurl = [string]($Packlist | Where-Object -Property filename -match $item)[0].downloadurl
       Invoke-WebRequest -Uri  $dlurl -OutFile (Join-Path $RepoPath -ChildPath $item )
    } else 
    {
        Write-Information "The file $($item) already exist in the repo. Skip download"
    }
  }

}

#Install Winget without license
#Add-AppxPackage -Path $(Join-Path $RepoPath -ChildPath  $DownloadFiles[0]) -DependencyPath  $(Join-Path $RepoPath -ChildPath  $DownloadFiles[1]), $(Join-Path $RepoPath -ChildPath  $DownloadFiles[2]) 
#Get-AppxPackage Microsoft.DesktopAppInstaller | Remove-AppxPackage

#Install Winget with license
Add-AppxProvisionedPackage -PackagePath $(Join-Path $RepoPath -ChildPath  $DownloadFiles[0]) -LicensePath $(Join-Path $RepoPath -ChildPath 'license.xml') -online `
                           -DependencyPackagePath $(Join-Path $RepoPath -ChildPath  $DownloadFiles[1]), $(Join-Path $RepoPath -ChildPath  $DownloadFiles[2])  


# Here is the trick of Thorsten Butz. We create a rebase point ourselves
# The alias can be defined somewhere in the $Temp:Path. For example, in C:\Windows\System32
Set-ExecutionAlias -Path "$env:windir\winget.exe" -Target $((Get-AppxPackage *DesktopAppInstaller*).InstallLocation + '\winget.exe') -PackageName `
                  'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe' -AppType Desktop -EntryPoint 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe!winget' -Version 3

#Get-ExecutionAlias  'c:\windows\winget.exe'
#Remove-Item  'c:\windows\winget.exe'
#'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe'