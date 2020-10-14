param (
    [Parameter(Mandatory=$true)]
    [String]$ScriptPath,

    [Parameter(Mandatory=$false)]
    [Int]$Reboot
)

function Start-PreFlight {

    $global:TempPath = "C:\Temp"


    #Run Script as Admin
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
        if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
            $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
            Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
            Exit
        }
    }

    #Set Script-Location
    $global:ScriptPath = $ScriptPath.replace("\Install.ps1", "")
    Set-Location $ScriptPath

    $PathExists = Test-Path $TempPath
    If ( $PathExists -eq $false )
    {
        New-Item -ItemType "directory" -Path $TempPath > $null
    }
}

function Write-Script {
    "@echo off" | Out-File -FilePath "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\helper.bat"
    "`"$ScriptPath\Elevate.exe`" powershell.exe -ExecutionPolicy Bypass -File `"$ScriptPath\Install.ps1`" -Reboot 1 -ScriptPath `"$ScriptPath\Install.ps1`"" | Out-File -Append -FilePath "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\helper.bat"
}

function Remove-Script {
    Remove-Item -Force "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\helper.bat" > $null
}

function Join-Domain {
    Write-Host "F�r wen wird der Rechner eingerichtet?"
    $User = Read-Host
    Write-Host "In welcher Gesellschaft arbeitet $User?"
    $Abbreviation = Read-Host
    Write-Host "Der wieviele Rechner von $User ist es?"
    [String]$Count = Read-Host

    if ( ($Count.Length) -eq 1) {
        $Count = "0$Count"
    }

    $Abbreviation = $Abbreviation.ToUpper()
    $User = $User.ToUpper()

    $ComputerName = "$Abbreviation-C-$User-$Count"
    Write-Host "Stimmt $ComputerName?"

    $Answer = Read-Host "(y/N): "

    switch ($Answer) {
        Y { Write-Host "Nun wird nach dem Admin-Account gefragt, um das System in die Dom�ne zu heben" }
        N { Write-Host "Sequenz wird neugestartet"; Join-Domain }
        Default { Write-Host "Error, Neustart, entweder Y/y oder N/n"; Join-Domain }
    }

    $Credentials = Get-Credential

    Add-Computer  -DomainName DOMAIN -NewName $ComputerName -OUPath "OU=Clients,OU=Computer,OU=_$Abbreviation,OU=CompanyName,DC=domain,DC=local"
}

function Get-Chocolatey {
    if (!(Test-Path "$($env:ProgramData)\chocolatey\choco.exe")) {
        Write-Host "Installiere Chocolatey..."
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression -ErrorAction Stop ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    } else {
        Write-Host "Chocolatey wurde bereits installiert, fahre fort."
    }
}

function Install-ChocoPackages {
    $Packages = "vcredist140 firefox googlechrome 7zip notepadplusplus vlc citrix-workspace keepass teamviewer"
    Write-Host "Sollen zus�tzlich zu den folgenden Paketen (adobereader $PACKAGES) noch etwas installiert werden? (Die eingebenen Namen m�ssen denen bei Chocolatey.org entsprechen und mit Leerzeichen getrennt sein.)"

    choco install -y adobereader -params '"/EnableUpdateService /UpdateMode:3"'

    try {
        choco install -y --force $Packages $EXTRA
    }
    catch {
        Write-Host "Chocolatey konnte die Pakete nicht erfolgreich installieren. Exit now."
        exit
    }
}

function Install-Packages {
    
    $Folder = Get-ChildItem -Name -Path "$ScriptPath\Programme"
    $Folder | ForEach-Object -Process { powershell.exe -ExecutionPolicy Bypass -File "$ScriptPath\$_\Install.ps1" -ScriptPath $ScriptPath }
    
}

Start-PreFlight

if ( $Reboot -eq 1) {
    Remove-Script
    Get-Chocolatey
    Install-ChocoPackages
    Install-Packages
} else {
    Join-Domain
    Write-Script
    shutdown.exe /r /t 5
    exit
}

Read-Host -Prompt "Press Enter to exit. . ."