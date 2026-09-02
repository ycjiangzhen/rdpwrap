@{
    # =========================================================================
    #  RdpCoexist configuration
    #  Values below are neutral defaults / placeholders. Fill EngineSha256
    #  before the first -Apply (or use -TrustOnFirstUse to pin interactively).
    # =========================================================================

    # ---- Engine: sergiye/rdpWrapper (used as-is; not redistributed here) ----
    EngineRepo    = 'sergiye/rdpWrapper'
    EngineVersion = '2.15'            # pin ONE vetted release; never float to "latest"
    EngineAsset   = 'rdpWrapper_x64.exe'

    # REQUIRED before first Apply. SHA256 of the vetted asset, uppercase hex.
    # Empty => -Apply refuses unless you pass -TrustOnFirstUse (prints the hash
    # so you can paste it back here and re-run).
    EngineSha256  = ''

    # ---- Paths ----
    InstallRoot   = 'C:\ProgramData\RdpCoexist'

    # ---- Behaviour ----
    PreferredWrapper     = 'TermWrap'   # TermWrap = offset-engine backend, no ini/offset dance
    AlwaysOffline        = $true        # always pass -offline so the engine never phones home
    AddDefenderExclusion = $true        # engine dll is commonly flagged HackTool:Win32/RDPWrap
    RegisterHealTask     = $true        # self-heal after Windows Update (re-install if listener drops)
    HealTaskName         = 'RdpCoexist-Heal'

    # ---- Optional: dedicated local account for RDP (avoids same-user dual-session
    #      license traps in OneDrive/Outlook/Office). Off by default. ----
    CreateRdpUser = $false
    RdpUserName   = 'rdpuser'           # placeholder; change before enabling

    # ---- Verify: locales that render session state as "Active" in qwinsta ----
    ActiveSessionPattern = 'Active|使用中|アクティブ|활성'
}
