# Test-CitrixLASPot

A PowerShell script to verify network connectivity to Citrix License Administration Service (LAS) cloud endpoints.

## Description

This diagnostic tool performs DNS resolution and TCP connectivity tests against all Citrix cloud service endpoints required for the License Administration Service. It helps identify network or firewall issues that may prevent Citrix licensing from functioning correctly.

## Requirements

- PowerShell 5.1 or later
- Windows operating system (uses `Test-NetConnection` and `Resolve-DnsName`)
- Network access to Citrix cloud endpoints

## Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Endpoints` | string[] | Citrix LAS endpoints | Array of hostnames to test |
| `Port` | int | 443 | TCP port to test (1-65535) |
| `TimeoutSeconds` | int | 5 | Connection timeout in seconds (1-60) |

## Default Endpoints

The script tests the following Citrix endpoints by default:

- `cis.citrix.com`
- `core.citrixworkspacesapi.net`
- `customers.citrixworkspacesapi.net`
- `las.cloud.com`
- `licensing.citrixworkspacesapi.net`
- `notifications.citrixworkspacesapi.net`
- `trust.citrixnetworkapi.net`
- `trust.citrixworkspacesapi.net`

## Usage

### Basic Usage

```powershell
.\Test-CitrixLASPot.ps1
```

### With Verbose Output

```powershell
.\Test-CitrixLASPot.ps1 -Verbose
```

### Custom Port

```powershell
.\Test-CitrixLASPot.ps1 -Port 8443
```

### Test Specific Endpoints

```powershell
.\Test-CitrixLASPot.ps1 -Endpoints @('las.cloud.com', 'cis.citrix.com')
```

### Export Results to CSV

```powershell
.\Test-CitrixLASPot.ps1 | Export-Csv -Path "results.csv" -NoTypeInformation
```

## Output

The script returns objects with the following properties:

| Property | Description |
|----------|-------------|
| `Hostname` | The tested endpoint hostname |
| `Port` | The TCP port tested |
| `TcpTestSucceeded` | `True` if TCP connection succeeded, `False` otherwise |
| `ResolvedIP` | Primary resolved IP address or error message |
| `AllIPs` | Comma-separated list of all resolved IP addresses |

### Example Output

```
Hostname                          Port TcpTestSucceeded ResolvedIP      AllIPs
--------                          ---- ---------------- ----------      ------
cis.citrix.com                     443             True 162.221.194.10  162.221.194.10, 162.221.194.11
las.cloud.com                      443             True 13.107.246.42   13.107.246.42
licensing.citrixworkspacesapi.net  443             True 52.165.156.32   52.165.156.32, 52.165.156.33
```

## Troubleshooting

| Issue | Possible Cause | Solution |
|-------|----------------|----------|
| `TcpTestSucceeded = False` | Firewall blocking port 443 | Check firewall rules for outbound HTTPS |
| `DNS resolution failed` | DNS server cannot resolve hostname | Verify DNS settings, try external DNS (8.8.8.8) |
| `No A records` | DNS returns non-A records only | Check for CNAME-only responses, verify DNS health |

## References

- [Citrix LAS Documentation](https://docs.citrix.com/en-us/citrix-cloud/citrix-cloud-management/license-usage-insights.html)
- [Citrix Cloud Connectivity Requirements](https://docs.citrix.com/en-us/citrix-cloud/overview/requirements/internet-connectivity-requirements.html)
