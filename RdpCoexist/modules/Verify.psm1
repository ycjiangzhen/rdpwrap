Set-StrictMode -Version Latest

function Get-ActiveSessionCount {
    param([string]$Pattern = 'Active|使用中|アクティブ|활성')
    $out = & qwinsta.exe 2>$null
    if (-not $out) { return 0 }
    return @($out | Select-String -Pattern $Pattern).Count
}

function Test-Coexist {
    <#
      COEXIST-OK requires an actual listener AND >=2 concurrent active sessions,
      not merely the registry values. Registry-only checks lie.
    #>
    param([string]$ActiveSessionPattern = 'Active|使用中|アクティブ|활성')

    $svc     = (Get-Service TermService -ErrorAction SilentlyContinue).Status
    $listen  = @(Get-NetTCPConnection -LocalPort 3389 -State Listen -ErrorAction SilentlyContinue).Count -gt 0
    $dll     = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\TermService\Parameters' `
                   -Name ServiceDll -ErrorAction SilentlyContinue).ServiceDll
    $active  = Get-ActiveSessionCount -Pattern $ActiveSessionPattern

    $verdict =
        if ($listen -and $active -ge 2) { 'COEXIST-OK' }
        elseif ($listen)                { 'LISTENING-UNVERIFIED' }
        else                            { 'FAIL' }

    [pscustomobject]@{
        TermService    = $svc
        Listening      = $listen
        ServiceDll     = $dll
        ActiveSessions = $active
        Verdict        = $verdict
    }
}

Export-ModuleMember -Function Test-Coexist, Get-ActiveSessionCount
