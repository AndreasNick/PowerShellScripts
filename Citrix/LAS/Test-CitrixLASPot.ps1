<#
.SYNOPSIS
    Tests connectivity to Citrix License Administration Service (LAS) endpoints.

.DESCRIPTION
    This script performs DNS resolution and TCP connectivity tests against
    Citrix cloud service endpoints required for License Administration Service.
    It validates that all necessary endpoints are reachable on the specified port.

.PARAMETER Endpoints
    Array of hostnames to test. Defaults to standard Citrix LAS endpoints.

.PARAMETER Port
    TCP port to test connectivity on. Defaults to 443 (HTTPS).

.PARAMETER TimeoutSeconds
    Timeout in seconds for each connection test. Defaults to 5.

.EXAMPLE
    .\Test-CitrixLASPot.ps1
    Tests all default Citrix LAS endpoints on port 443.

.EXAMPLE
    .\Test-CitrixLASPot.ps1 -Port 8443
    Tests all default endpoints on a custom port.

.EXAMPLE
    .\Test-CitrixLASPot.ps1 -Endpoints @('las.cloud.com', 'cis.citrix.com')
    Tests only the specified endpoints.

.NOTES
    Author: IT Administration
    Version: 1.0
    Requires: PowerShell 5.1 or later
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$Endpoints = @(
        'cis.citrix.com',
        'core.citrixworkspacesapi.net',
        'customers.citrixworkspacesapi.net',
        'las.cloud.com',
        'licensing.citrixworkspacesapi.net',
        'notifications.citrixworkspacesapi.net',
        'trust.citrixnetworkapi.net',
        'trust.citrixworkspacesapi.net'
    ),

    [Parameter()]
    [ValidateRange(1, 65535)]
    [int]$Port = 443,

    [Parameter()]
    [ValidateRange(1, 60)]
    [int]$TimeoutSeconds = 5
)

$uniqueEndpoints = $Endpoints | Sort-Object -Unique

$results = foreach ($hostname in $uniqueEndpoints) {
    Write-Verbose "Testing endpoint: $hostname"

    try {
        $dnsRecords = Resolve-DnsName -Name $hostname -Type A -ErrorAction Stop
        $ipAddresses = $dnsRecords |
            Where-Object { $_.QueryType -eq 'A' } |
            Select-Object -ExpandProperty IPAddress

        $primaryIP = $ipAddresses | Select-Object -First 1

        $tcpTest = Test-NetConnection -ComputerName $hostname -Port $Port `
            -InformationLevel Quiet -WarningAction SilentlyContinue

        [PSCustomObject]@{
            Hostname         = $hostname
            Port             = $Port
            TcpTestSucceeded = $tcpTest
            ResolvedIP       = if ($primaryIP) { $primaryIP } else { 'No A records' }
            AllIPs           = ($ipAddresses -join ', ')
        }
    }
    catch {
        [PSCustomObject]@{
            Hostname         = $hostname
            Port             = $Port
            TcpTestSucceeded = $false
            ResolvedIP       = 'DNS resolution failed'
            AllIPs           = 'DNS resolution failed'
        }
    }
}

$results | Format-Table -AutoSize
