param (
    [Parameter(Mandatory=$true)]
    [String]$ScriptPath
)

$ODT = "Office365 Business Premium"

#Install Office 365
Write-Host "Downloade Office 365..."
Start-Process -WorkingDirectory "$ScriptPath\Programme\odt" -FilePath "setup.exe" -Wait -ArgumentList "/download $ScriptPath\office\$ODT.xml"
Write-Host "Fertig"
Write-Host "Installiere O365"
Start-Process -WorkingDirectory "$ScriptPath\Programme\odt" -FilePath "setup.exe" -Wait -ArgumentList "/configure $ScriptPath\office\$ODT.xml"
