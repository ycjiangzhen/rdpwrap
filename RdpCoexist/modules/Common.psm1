Set-StrictMode -Version Latest

$script:LogPath = $null

function Initialize-Log {
    param([string]$Root)
    $dir = Join-Path $Root 'logs'
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $script:LogPath = Join-Path $dir ('rdpcoexist-{0:yyyyMMdd}.log' -f (Get-Date))
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Info', 'Warn', 'Error', 'Ok')][string]$Level = 'Info'
    )
    $stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line  = "[$stamp] [$Level] $Message"
    $color = switch ($Level) { 'Warn' { 'Yellow' } 'Error' { 'Red' } 'Ok' { 'Green' } default { 'Gray' } }
    Write-Host $line -ForegroundColor $color
    if ($script:LogPath) { Add-Content -Path $script:LogPath -Value $line -Encoding UTF8 }
}

function Assert-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $pr = New-Object Security.Principal.WindowsPrincipal($id)
    if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Administrator rights required. Launch via RdpCoexist.cmd (UAC) or an elevated shell.'
    }
}

function Test-DomainPolicyOverride {
    # fSingleSessionPerUser / fDenyTSConnections may be enforced by GPO and will
    # silently revert local changes on the next GP refresh. Warn, do not fail.
    $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services'
    if (Test-Path $p) {
        $k = Get-ItemProperty $p -ErrorAction SilentlyContinue
        foreach ($v in 'fSingleSessionPerUser', 'fDenyTSConnections') {
            if ($null -ne $k.$v) {
                Write-Log "GPO sets $v=$($k.$v); it may override local settings on GP refresh. Check with IT." 'Warn'
            }
        }
    }
}

Export-ModuleMember -Function Initialize-Log, Write-Log, Assert-Admin, Test-DomainPolicyOverride
