<#
    .SYNOPSIS
    Script to export all WLAN settings for a user
    .AUTOR
    Andreas Nick 2018 without any warranty
    .EXAMPLE     

#>

#$ErrorActionPreference = "Continue"

param(
  [string] $strKey = 'SECRETKEY123a234', #16 Byte Key
  [string] $DestinationFolder = $($env:APPDATA + '\WLANEXPORT')  #Folder to save the encrypted settings
)

write-Host $strKey

$enc = [system.text.Encoding]::UTF8
$key = $enc.GetBytes($strKey)



<#
    .SYNOPSIS
    function to encrypt wlan export file
#>
function Encrypt-Wlanexport{
  param([String] $wlanString)

  if($wlanString.Length -lt 64kb){

    $str = $wlanString | ConvertTo-SecureString -AsPlainText -Force
    $encripted = $str | ConvertFrom-SecureString -key $Global:key
     
    return $encripted

  } else {
    Write-Host "Error: Max length ist 64kb" -ForegroundColor Red
    return $null
  }
}

<#
    .SYNOPSIS
    convert xml to a String
#>
function Out-Xml{
  param([xml]$xml)
  $strWriter = New-Object System.IO.StringWriter
  $xmlWriter = New-Object System.Xml.XmlTextWriter $strWriter
  $xmlWriter.Formatting = "Indented"
  $xml.WriteTo($xmlWriter)
  $xmlWriter.Flush()
  $strWriter.ToString()
}


<#
    .SYNOPSIS
    Decript a wlan file
    .OUTPUT
    xmlfile as String
    
#>

function Decrypt-Wlanfile{
  param([string] $secstring)

  $SecurePassword = ConvertTo-SecureString $secstring -Key $Global:key

  $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
  $UnsecurePassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
  #$UnsecurePassword
  $wlanxml = [xml]$UnsecurePassword

  return Out-Xml -xml $wlanxml
}


function Export-WLANSettings{
  Param([System.IO.DirectoryInfo] $exportPath)
  
  $patternNetz = '\s+:.*$' 
  $out = netsh wlan show profiles 
  $result = ($out | Select-String -AllMatches $patternNetz | Select-Object -ExpandProperty Matches | Select-Object -ExcludeProperty Value)
  $networkList = @()
  $result | % {$networkList+= $($_.Value -replace ' : ','') }
  #$networkList


  if($networkList.Count -ge 1){
    Write-Host "Network(s) found - start export" -ForegroundColor Cyan
    foreach($net in $networkList){
      Write-Host "Export : $net" -ForegroundColor Yellow
      if(!(Test-path "$env:temp\networks")){new-item "$env:temp\networks" -type Directory}
  
      netsh wlan export profile "$net" key=clear folder="$env:temp\networks\" | Out-Null
          
    }
  }

  #Encript the files

  foreach($xfile in Get-ChildItem "$env:temp\"){
    $wlanfile = Get-Content $xfile.FullName
    $enc = Encrypt-Wlanexport -wlanString $wlanfile 

    $enc | out-file $($ExportPath.FullName +"\" + (Split-Path $xfile.FullName -Leaf)) -Force
    #Decrypt-Wlanfile -secstring $enc           
  }
}



if(!(Test-Path "$DestinationFolder")) {
  New-Item "$DestinationFolder" -ItemType Directory 
}

if(Test-Path "$DestinationFolder") {
  Export-WLANSettings -ExportPath "$DestinationFolder"
  
} else {
  Write-Host "Error, missing network connection or folder" -ForegroundColor Red
}



   



