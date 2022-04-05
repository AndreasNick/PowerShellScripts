
#Abfragen
Get-WindowsCapability -Online | Where-Object {$_.Name -like "RSAT*"}

#Eins installieren
Add-WindowsCapability -Online -Name Rsat.Dns.Tools~~~~0.0.1.0

#Alle  installieren

Get-WindowsCapability -Online | Where-Object {$_.Name -like "RSAT*"} | ForEach-Object {Add-WindowsCapability -Online -Name $_.Name}