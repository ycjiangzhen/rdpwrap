Set-StrictMode -Version Latest

function Add-DefenderExclusion {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $cur = @((Get-MpPreference).ExclusionPath)
        if ($cur -notcontains $Path) {
            Add-MpPreference -ExclusionPath $Path
            Write-Log "Defender exclusion added: $Path" 'Ok'
        }
        else { Write-Log "Defender exclusion already present: $Path" }
    }
    catch {
        # If exclusions are locked by Intune/Tenant, only IT can add them.
        Write-Log "Could not add Defender exclusion (managed by policy?): $_" 'Warn'
    }
}

function Remove-DefenderExclusion {
    param([Parameter(Mandatory)][string]$Path)
    try { Remove-MpPreference -ExclusionPath $Path -ErrorAction SilentlyContinue }
    catch { Write-Log "Could not remove Defender exclusion: $_" 'Warn' }
}

Export-ModuleMember -Function Add-DefenderExclusion, Remove-DefenderExclusion
