$regFile = @"
<registry info>
"@

# Get all DCs to action
$DC52 = Get-ADDomainController | select -ExpandProperty hostname
$DCAFNO = Get-ADDomainController -Server afnoapps.usaf.mil | select -ExpandProperty hostname
[array]$DCsToCheck = Get-ADDomainController -Server $DC52 -Filter * | select -ExpandProperty hostname | sort
$DCsToCheck += Get-ADDomainController -Server $DCAFNO -Filter * | select -ExpandProperty hostname | sort
#[array]$DCsToCheck = "muhj-dc-005p","muhj-dc-006p"
$fltrArr = @()
foreach ($dc in $DCsToCheck) {
  $fltrArr += "name -eq `"$($dc.split(".")[0])`""
}
$fltr = $fltrArr -join " -or "
[array]$DCs = Get-ADComputer -Server $DC52 -Filter $fltr -SearchBase "OU=Domain Controllers,DC=AREA52,DC=AFNOAPPS,DC=USAF,DC=MIL" -Properties description | select name,description
$DCs += Get-ADComputer -Server $DCAFNO -Filter $fltr -SearchBase "OU=Domain Controllers,DC=AFNOAPPS,DC=USAF,DC=MIL" -Properties description | select name,description

# Now that we have our DCs, lets create a loop to target each DC.
foreach ($dc in $DCs) {
  $base = $dc.description
  # Invoke the ScriptBlock section remotely on the DC that is in the loop currently
  Invoke-Command -ComputerName $dc.name -ScriptBlock {
    #Clear out old managers (reg values)
    (Get-Item "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers").property | foreach {
        Remove-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\SNMP\Parameters\PermittedManagers" -Name $_
        }
    Write-Host "Old Permitted Managers cleared" -ForegroundColor Cyan
    #Remove old communities and settings (reg keys)
    Get-ChildItem "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\TrapConfiguration" | foreach {
        Remove-Item $_.pspath -Force
        }
    Write-Host "Old Communities and Settings cleared" -ForegroundColor Cyan
    #Remove ValidCommunities subkeys (reg values)
    (Get-Item "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities").property | foreach {
        Remove-ItemProperty -Path "registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\services\SNMP\Parameters\ValidCommunities" -Name $_
        }
    Write-Host "Old ValidCommunities subkeys cleared" -ForegroundColor Cyan

    
    Add-WindowsFeature SNMP-Service,SNMP-WMI-Provider | Out-Null

    # Make reg file, and then import it
    Write-Host "Making the new Registry File" -ForegroundColor Yellow
    $using:regFile | out-file $env:temp\snmp.reg
    Write-Host "Importing the new Registry File" -ForegroundColor Yellow
    reg.exe import $env:temp\snmp.reg
    Remove-Item $env:temp\snmp.reg

    #Set missing base name reg value
    reg add "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent" /v sysLocation /t REG_SZ /d $using:base /f
  }
  Write-Host "Final step completed::::`"$($DC.Name)`" has finished its SNMP update" -ForegroundColor Green
}
