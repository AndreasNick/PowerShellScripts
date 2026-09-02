function Get-InstalledKB {
    $cbsKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Packages'
    $stateMap = @{
        0='Absent'; 5='Resolved'; 10='Staged'; 20='Resolving'; 30='Resolved'
        32='Staged'; 35='Superseded'; 40='Installing'; 50='PartiallyInstalled'
        60='Resolved'; 64='Resolved'; 65='Resolved'; 70='Installed'; 80='Superseded'
        90='PartiallyResolved'; 100='PartiallyResolved'; 112='Installed'  # 112 = permanent/MSU
    }

    Get-ChildItem $cbsKey -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '_for_(KB\d{6,})' } |
        ForEach-Object {
            $null = $_.PSChildName -match '_for_(KB\d{6,})'
            $kb = $Matches[1]
            $p  = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $st = if ($stateMap.ContainsKey([int]$p.CurrentState)) { $stateMap[[int]$p.CurrentState] } else { "Code-$($p.CurrentState)" }
            $time = $null
            if ($p.InstallTimeHigh) {
                $time = [DateTime]::FromFileTime((([int64]$p.InstallTimeHigh) -shl 32) -bor ([int64]$p.InstallTimeLow))
            }
            [pscustomobject]@{
                KB          = $kb
                State       = $st
                InstallTime = $time
                Package     = $_.PSChildName
            }
        } |
        Group-Object KB |
        ForEach-Object {
            # Pro KB nur den neuesten/wichtigsten Eintrag (kommt oft mehrfach vor — pro Sub-Komponente)
            $_.Group | Sort-Object InstallTime -Descending | Select-Object -First 1
        } |
        Sort-Object InstallTime -Descending
}

# Tabellarisch
Get-InstalledKB | Format-Table -AutoSize KB, State, InstallTime

# Komplett mit langem Package-Namen
#Get-InstalledKB | Format-List
