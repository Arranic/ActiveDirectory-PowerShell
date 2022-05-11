$regFile = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP]
"Type"=dword:00000010
"Start"=dword:00000002
"ErrorControl"=dword:00000001
"ImagePath"=hex(2):25,00,53,00,79,00,73,00,74,00,65,00,6d,00,52,00,6f,00,6f,00,\
  74,00,25,00,5c,00,53,00,79,00,73,00,74,00,65,00,6d,00,33,00,32,00,5c,00,73,\
  00,6e,00,6d,00,70,00,2e,00,65,00,78,00,65,00,00,00
"DisplayName"="@%SystemRoot%\\system32\\snmp.exe,-3"
"ObjectName"="LocalSystem"
"Description"="@%SystemRoot%\\system32\\snmp.exe,-4"
"ServiceSidType"=dword:00000001
"RequiredPrivileges"=hex(7):53,00,65,00,43,00,68,00,61,00,6e,00,67,00,65,00,4e,\
  00,6f,00,74,00,69,00,66,00,79,00,50,00,72,00,69,00,76,00,69,00,6c,00,65,00,\
  67,00,65,00,00,00,53,00,65,00,53,00,65,00,63,00,75,00,72,00,69,00,74,00,79,\
  00,50,00,72,00,69,00,76,00,69,00,6c,00,65,00,67,00,65,00,00,00,53,00,65,00,\
  44,00,65,00,62,00,75,00,67,00,50,00,72,00,69,00,76,00,69,00,6c,00,65,00,67,\
  00,65,00,00,00,00,00
"FailureActions"=hex:80,51,01,00,00,00,00,00,01,00,00,00,03,00,00,00,14,00,00,\
  00,01,00,00,00,60,ea,00,00,01,00,00,00,60,ea,00,00,00,00,00,00,00,00,00,00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters]
"NameResolutionRetries"=dword:00000010
"EnableAuthenticationTraps"=dword:00000000

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ExtensionAgents]
"MCVSSNMP"="SOFTWARE\\McAfee\\SystemCore\\VSCore\\MCVSSNMP"
"WINSMibAgent"="SOFTWARE\\Microsoft\\WINSMibAgent\\CurrentVersion"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\PermittedManagers]
"1"="localhost"
"2"="131.9.22.200"
"3"="131.9.22.201"
"4"="131.9.22.202"
"5"="131.27.56.123"
"6"="131.27.56.125"
"7"="131.27.56.119"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\RFC1156Agent]
"sysServices"=dword:0000004f
"sysLocation"=""
"sysContact"="CSCS Directory Services"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration]

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration\C40col@t3]
"1"="131.27.56.123"
"2"="131.27.56.125"
"3"="131.27.56.119"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\TrapConfiguration\R3@dAFN3Tonly!]
"1"="131.9.22.200"
"2"="131.9.22.201"
"3"="131.9.22.202"

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\SNMP\Parameters\ValidCommunities]
"C40col@t3"=dword:00000004
"R3@dAFN3Tonly!"=dword:00000004
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