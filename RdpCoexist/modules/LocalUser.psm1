Set-StrictMode -Version Latest

function New-RdpLocalUser {
    <#
      Optional: a dedicated local account for RDP so the interactive (console)
      user and the RDP user are different principals. Avoids single-session
      license locks in OneDrive/Outlook/Office. Prompts for the password; this
      tool never bakes or transmits credentials.
    #>
    param([Parameter(Mandatory)][string]$UserName)

    if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
        Write-Log "Local user '$UserName' already exists." ; return
    }
    $sec = Read-Host "Set password for new RDP user '$UserName'" -AsSecureString
    New-LocalUser -Name $UserName -Password $sec -PasswordNeverExpires:$true `
        -Description 'RdpCoexist dedicated RDP account' | Out-Null
    Add-LocalGroupMember -Group 'Remote Desktop Users' -Member $UserName -ErrorAction SilentlyContinue
    Write-Log "Local user '$UserName' created and added to Remote Desktop Users." 'Ok'
}

function Remove-RdpLocalUser {
    param([Parameter(Mandatory)][string]$UserName)
    if (Get-LocalUser -Name $UserName -ErrorAction SilentlyContinue) {
        Remove-LocalUser -Name $UserName
        Write-Log "Local user '$UserName' removed."
    }
}

Export-ModuleMember -Function New-RdpLocalUser, Remove-RdpLocalUser
