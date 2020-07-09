<#
.SYNOPSIS
    Script to impor all WLAN settings for a System.
	The script must be started as adminstrator
.AUTOR
    Andreas Nick 2018 without any warranty
.EXAMPLE     

#>

#$ErrorActionPreference = "Continue"

param(
[string] $strKey = "SECRETKEY123a234", #16 Byte Key
[string] $DestinationFolder = "$env:APPDATA\WLANEXPORT" #Folder to save the encrypted settings
)

$enc = [system.text.Encoding]::UTF8
$key = $enc.GetBytes($strKey)


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





if((Test-Path "$DestinationFolder\networks")) {

  foreach($xfile in Get-ChildItem "$DestinationFolder\networks"){
    $wlanfile = Get-Content $xfile.FullName

    try {
      Decrypt-Wlanfile -secstring $wlanfile | out-File -FilePath "$env:TEMP\tempwlan.xml"  -Force
      
       
      netsh wlan add profile filename="$env:TEMP\tempwlan.xml" user=current   
    } catch {
        Write-Host "Error processing wlan import" -ForegroundColor Red
    
    }

    if(test-Path "$env:TEMP\tempwlan.xml") {
        Remove-Item  "$env:TEMP\tempwlan.xml" -Force
    }

  }
 
}

