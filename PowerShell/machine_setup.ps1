function Set-MouseWheelInverted {
    Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Enum\HID\*\*\Device` Parameters | ForEach-Object { Set-ItemProperty $_.PSPath FlipFlopWheel 1 }
}

Set-Alias FlipFlopWheel Set-MouseWheelInverted

# https://superuser.com/questions/949385/map-capslock-to-control-in-windows-10
function Set-CapsLockMappedToControl {
    $hexified = "00,00,00,00,00,00,00,00,02,00,00,00,1d,00,3a,00,00,00,00,00".Split(',') | % { "0x$_"};
    $kbLayout = 'HKLM:\System\CurrentControlSet\Control\Keyboard Layout';
    New-ItemProperty -Path $kbLayout -Name "Scancode Map" -PropertyType Binary -Value ([byte[]]$hexified);
}

function Set-PowerShellProfileDirectory {
    param(
        # The directory to set as the root for PowerShell profile; underneath this will be PowerShell/profile.ps1
        [Parameter(position = 0, Mandatory = $True)][string] $Directory
    )
    New-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name Personal -Value $Directory -Type ExpandString -Force
}