Set-StrictMode -Version Latest

function Register-HealTask {
    <#
      Windows Update replaces termsrv.dll, which can break memory offsets and drop
      the listener. This registers a SYSTEM startup task that runs -Heal: verify,
      and only if not COEXIST-OK re-run the engine install (offset engine re-adapts).
    #>
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)][string]$ScriptPath
    )
    $arg = '-NoProfile -ExecutionPolicy Bypass -File "{0}" -Heal' -f $ScriptPath
    $action    = New-ScheduledTaskAction   -Execute 'powershell.exe' -Argument $arg
    $trigger   = New-ScheduledTaskTrigger  -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
                    -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $Config.HealTaskName -Action $action -Trigger $trigger `
        -Principal $principal -Settings $settings -Force | Out-Null
    Write-Log "Heal task registered: $($Config.HealTaskName)" 'Ok'
}

function Unregister-HealTask {
    param([Parameter(Mandatory)]$Config)
    Unregister-ScheduledTask -TaskName $Config.HealTaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Log "Heal task removed: $($Config.HealTaskName)"
}

Export-ModuleMember -Function Register-HealTask, Unregister-HealTask
