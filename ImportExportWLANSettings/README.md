# PowerShell to Import and Export WLAN settings
Some time ago we had a notebook migration and the customer wanted WLAN data to be automatically transferred to the new environment.
Unfortunately this data is fixed to the machine. Therefore these scripts will probably not work in the user context. We did this ourselves back then with RES ONE Workspace and today Ivanti Workspace Control.

The passwords are simply encrypted with a key and can therefore not be read directly at first.

Please send me a feedback if this still works under the current systems.


```powershell
param(
  [string] $strKey = 'SECRETKEY123a234', #16 Byte Key
  [string] $DestinationFolder = $($env:APPDATA + '\WLANEXPORT')  #Folder to save the encrypted settings
)

````

```powershell
param(
[string] $strKey = "SECRETKEY123a234", #16 Byte Key
[string] $DestinationFolder = "$env:APPDATA\WLANEXPORT" #Folder to save the encrypted settings
)


````