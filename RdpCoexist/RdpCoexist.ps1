<#
.SYNOPSIS
    Portable AnyDesk + RDP coexistence orchestrator (governance shell around
    sergiye/rdpWrapper). Enables concurrent RDP sessions without touching
    System32\termsrv.dll on disk (ServiceDll redirection + TermWrap backend).

.DESCRIPTION
    This shell adds the operational pieces the engine does not provide:
      1. Engine is fetched from its official release and SHA256-pinned (no
         redistribution here; upstream has no license grant).
      2. Post-Windows-Update self-heal via a SYSTEM startup scheduled task.
      3. A machine-checkable verdict (listener + >=2 active sessions), not GUI.
      4. The engine is always run with -offline (no phone-home / version drift).
      5. Windows Defender exclusion handled idempotently.

.EXAMPLE
    RdpCoexist.cmd -Apply
    RdpCoexist.cmd -Verify
    RdpCoexist.cmd -Revert
#>
[CmdletBinding(DefaultParameterSetName = 'Verify')]
param(
    [Parameter(ParameterSetName = 'Apply')]  [switch]$Apply,
    [Parameter(ParameterSetName = 'Revert')] [switch]$Revert,
    [Parameter(ParameterSetName = 'Verify')] [switch]$Verify,
    [Parameter(ParameterSetName = 'Heal')]   [switch]$Heal,
    [Parameter(ParameterSetName = 'Status')] [switch]$Status,
    [switch]$TrustOnFirstUse
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path

Import-Module (Join-Path $here 'modules\Common.psm1')    -Force
Import-Module (Join-Path $here 'modules\Engine.psm1')    -Force
Import-Module (Join-Path $here 'modules\Defender.psm1')  -Force
Import-Module (Join-Path $here 'modules\Verify.psm1')    -Force
Import-Module (Join-Path $here 'modules\Heal.psm1')      -Force
Import-Module (Join-Path $here 'modules\LocalUser.psm1') -Force

$cfg = Import-PowerShellDataFile (Join-Path $here 'config.psd1')
New-Item -ItemType Directory -Path $cfg.InstallRoot -Force | Out-Null
Initialize-Log -Root $cfg.InstallRoot

function Do-Apply {
    Assert-Admin
    Test-DomainPolicyOverride
    if ($cfg.AddDefenderExclusion) { Add-DefenderExclusion -Path (Join-Path $cfg.InstallRoot 'engine') }

    $exe = Resolve-Engine -Config $cfg -TrustOnFirstUse:$TrustOnFirstUse
    Set-PreferredWrapper -Wrapper $cfg.PreferredWrapper
    $rc = Invoke-Engine -Exe $exe -EngineArgs @('-install') -Offline:$cfg.AlwaysOffline
    if ($rc -ne 0) { throw "Engine install failed (exit=$rc)." }

    if ($cfg.CreateRdpUser) { New-RdpLocalUser -UserName $cfg.RdpUserName }
    if ($cfg.RegisterHealTask) { Register-HealTask -Config $cfg -ScriptPath $PSCommandPath }

    $v = Test-Coexist -ActiveSessionPattern $cfg.ActiveSessionPattern
    $v | Format-List | Out-String | Write-Host
    if ($v.Verdict -eq 'FAIL') { Write-Log 'Apply finished but listener is down.' 'Error' }
    elseif ($v.Verdict -eq 'LISTENING-UNVERIFIED') {
        Write-Log 'Listener up. Open a second concurrent session to confirm COEXIST-OK.' 'Warn'
    }
    else { Write-Log 'COEXIST-OK.' 'Ok' }
}

function Do-Revert {
    Assert-Admin
    $exe = Join-Path (Join-Path $cfg.InstallRoot 'engine') $cfg.EngineAsset
    if (Test-Path $exe) { Invoke-Engine -Exe $exe -EngineArgs @('-uninstall') -Offline:$cfg.AlwaysOffline | Out-Null }
    Unregister-HealTask -Config $cfg
    if ($cfg.AddDefenderExclusion) { Remove-DefenderExclusion -Path (Join-Path $cfg.InstallRoot 'engine') }
    if ($cfg.CreateRdpUser) { Write-Log "Local user '$($cfg.RdpUserName)' left intact; remove manually if desired." 'Warn' }
    Write-Log 'Revert complete.' 'Ok'
}

function Do-Heal {
    Assert-Admin
    $v = Test-Coexist -ActiveSessionPattern $cfg.ActiveSessionPattern
    if ($v.Verdict -ne 'FAIL') { Write-Log "Heal: healthy ($($v.Verdict)); nothing to do." 'Ok'; return }
    Write-Log 'Heal: listener down (likely post-update). Re-installing engine.' 'Warn'
    $exe = Resolve-Engine -Config $cfg -TrustOnFirstUse:$TrustOnFirstUse
    Set-PreferredWrapper -Wrapper $cfg.PreferredWrapper
    Invoke-Engine -Exe $exe -EngineArgs @('-install') -Offline:$cfg.AlwaysOffline | Out-Null
    (Test-Coexist -ActiveSessionPattern $cfg.ActiveSessionPattern) | Format-List | Out-String | Write-Host
}

switch ($PSCmdlet.ParameterSetName) {
    'Apply'  { Do-Apply }
    'Revert' { Do-Revert }
    'Heal'   { Do-Heal }
    default  { (Test-Coexist -ActiveSessionPattern $cfg.ActiveSessionPattern) | Format-List }
}
