#Powershell-Script als Admin ausführen
if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    if ([int](Get-CimInstance -Class Win32_OperatingSystem | Select-Object -ExpandProperty BuildNumber) -ge 6000) {
     $CommandLine = "-File `"" + $MyInvocation.MyCommand.Path + "`" " + $MyInvocation.UnboundArguments
     Start-Process -FilePath PowerShell.exe -Verb Runas -ArgumentList $CommandLine
     Exit
    }
}

$ScriptPath = ($MyInvocation.MyCommand.Path).replace("Install.ps1", "")
Set-Location $ScriptPath

Write-Host "Welche Linux-Distro soll installiert werden?"
Write-Host "1. Ubuntu 20.04"
Write-Host "2. Ubuntu 18.04"
Write-Host "3. Debian 10"
Write-Host "4. Kali Linux"
Write-Host "5. OpenSuse Leap 42"
Write-Host "6. Fedora Remix (considered BETA)"
$DISTRO = Read-Host

switch ($DISTRO) {
    1 { $URI = "https://aka.ms/wslubuntu2004" }
    2 { $URI = "https://aka.ms/wslubuntu1804" }
    3 { $URI = "https://aka.ms/wsl-debian-gnulinux" }
    4 { $URI = "https://aka.ms/wsl-kali-linux-new" }
    5 { $URI = "https://aka.ms/wsl-opensuse-42" }
    6 { $FEDORA = $True; $URI = "https://github.com/WhitewaterFoundry/Fedora-Remix-for-WSL/releases/download/31.5.0/Fedora-Remix-for-WSL_31.5.0.0_x64_arm64.appxbundle" }
}

Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux

if ( $FEDORA -eq $True ) {
    Invoke-WebRequest -Uri $URI -OutFile FedoraRemix.appxbundle -UseBasicParsing
    Add-AppxPackage .\FedoraRemix.appxbundle
}
else {
    curl.exe -L $URI -o Linux-Distro.appx 
    Add-AppxPackage .\Linux-Distro.appx
}

Write-Host "Die ausgewählte WSL1-Distro wurde erfolgreich installiert. Hinweis: Es wird geraten, auf WSL2 upzugraden, ist aber für den Zweck nicht notwendig https://aka.ms/wsl2-install"
Write-Host "Bevor das Deployment-Script genutzt werden kann, muss jedoch zunächst erst die Erst-Einrichtung durchgeführt werden, sprich einfach die Distro aus dem Startmenü öffnen und den Anweisungen folgen."
Write-Host "Nach der Einrichtung kann einfach im Ordner ein Shift-Rechtsklick ausgeführt werden, um an der Stelle eine Linux-Shell zu öffnen und das deploy.sh Script auszuführen."
Read-Host "Press Enter to Exit..."