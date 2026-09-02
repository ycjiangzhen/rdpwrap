Set-StrictMode -Version Latest

function Resolve-Engine {
    <#
      Ensures the sergiye/rdpWrapper engine exe is present under <InstallRoot>\engine
      and its SHA256 matches the pin. The engine is downloaded from its official
      GitHub release (not redistributed in this repo, which has no license grant).
    #>
    param(
        [Parameter(Mandatory)]$Config,
        [switch]$TrustOnFirstUse
    )
    $dir = Join-Path $Config.InstallRoot 'engine'
    $exe = Join-Path $dir $Config.EngineAsset
    New-Item -ItemType Directory -Path $dir -Force | Out-Null

    if (-not (Test-Path $exe)) {
        $url = "https://github.com/$($Config.EngineRepo)/releases/download/$($Config.EngineVersion)/$($Config.EngineAsset)"
        Write-Log "Downloading engine: $url"
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $exe -UseBasicParsing
    }

    $hash = (Get-FileHash $exe -Algorithm SHA256).Hash.ToUpper()
    $pin  = ($Config.EngineSha256 | Out-String).Trim().ToUpper()

    if ([string]::IsNullOrWhiteSpace($pin)) {
        if ($TrustOnFirstUse) {
            Write-Log "TOFU pin: $hash  <-- paste into config.psd1 EngineSha256 to lock it." 'Warn'
        }
        else {
            Remove-Item $exe -Force -ErrorAction SilentlyContinue
            throw "EngineSha256 is not pinned. Verify the asset out-of-band, set the pin, or re-run with -TrustOnFirstUse. Observed: $hash"
        }
    }
    elseif ($hash -ne $pin) {
        Remove-Item $exe -Force -ErrorAction SilentlyContinue
        throw "Engine hash mismatch (deleted). expected=$pin actual=$hash"
    }
    else {
        Write-Log "Engine hash verified." 'Ok'
    }
    return $exe
}

function Invoke-Engine {
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string[]]$EngineArgs,
        [bool]$Offline = $true
    )
    $a = @($EngineArgs)
    if ($Offline) { $a += '-offline' }   # -offline must be the LAST parameter
    Write-Log "engine $($a -join ' ')"
    $p = Start-Process -FilePath $Exe -ArgumentList $a -Wait -PassThru -NoNewWindow
    Write-Log "engine exit=$($p.ExitCode)"
    return $p.ExitCode
}

function Set-PreferredWrapper {
    # The engine reads preferredWrapper from its own persistent settings; default
    # is already TermWrap. Mirror the choice into that store so -install is unattended.
    param([Parameter(Mandatory)][string]$Wrapper)
    $key = 'HKCU:\Software\rdpWrapper'
    try {
        New-Item $key -Force | Out-Null
        Set-ItemProperty $key -Name 'preferredWrapper' -Value $Wrapper
    } catch { Write-Log "Could not preset preferredWrapper: $_" 'Warn' }
}

Export-ModuleMember -Function Resolve-Engine, Invoke-Engine, Set-PreferredWrapper
