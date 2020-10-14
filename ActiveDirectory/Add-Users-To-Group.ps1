function Get-Path {
    
    $global:CSVPath = Read-Host "Bitte den vollständigen Pfad zur CSV angeben: "
    if ( ( Test-Path -Path $CSVPath ) -eq $false) {
        Write-Host "Pfad ist nicht richtig, bitte erneut eingeben!"
        Write-Host
        Get-Path
    }
}
function Import-CSVUser {
    $global:CSVUsers = Import-CSV -Path $CSVPath
    Write-Host "Benutzer wurden importiert"
}
function Get-Group {
    Write-Host "Bitte Search-Term der Gruppe eingeben:"
    $GroupSearch = Read-Host
    $SearchOut = Get-ADGroup -Filter "name -like '*$GroupSearch*'"
    switch (($SearchOut | Measure-Object).Count) {
        0 { Write-Host "Kein Eintrag gefunden, bitte erneut eingeben."; Get-Group }
        1 { Write-Host "Nur einen Eintrag gefunden, fahre fort." }
        Default {
            Write-Host ( $SearchOut | Format-Table -AutoSize -Property Name,DistinguishedName | Out-String )
            Write-Host "Bitte nun den vollständigen Namen kopieren und unten einfügen:"
            $GroupSearch = Read-Host
            $SearchOut = Get-ADGroup -Filter "name -eq '$GroupSearch'"
    
            if ( ($SearchOut | Measure-Object).Count -ne 1) {
    
                Write-Host "Fehler, bitte erneut durchführen."
                Get-Group
            }
        }
    }
    $global:Group = $SearchOut
}
function Add-ToGroup {
    $Users = $CSVUsers.UserPrincipalName
    $Users | ForEach-Object -Process {
        Write-Host "Hinzufügen von: $_"
        $User = Get-ADUser -Filter {UserPrincipalName -eq $_}
        Add-ADGroupMember -Identity $Group -Members $User
    }
    exit
}

Get-Path
Import-CSVUser
Get-Group
Add-ToGroup