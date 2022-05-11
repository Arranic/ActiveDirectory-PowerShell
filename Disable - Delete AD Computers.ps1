##### A1C Robert Griffn, 83 NOS - Directory Services
##### robert.griffin.23@us.af.mil
##### DSN: 764-7663 or 574-7663

$windowsId = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$windowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($windowsId)
$adminRole=[System.Security.Principal.WindowsBuiltInRole]::Administrator
if (!($windowsPrincipal.IsInRole($adminRole))) {
    $scriptpath = "'" + $MyInvocation.MyCommand.Definition + "'"
    Start-Process -FilePath PowerShell.exe -Verb runAs -ArgumentList "& $scriptPath"
    exit
}

$runningSid = get-aduser $env:USERNAME | select -ExpandProperty SID

###Script needs to be run on an Administrative Account, but does not need an elevated shell window.
Add-Type -AssemblyName PresentationFramework
$msgBoxInput =  [System.Windows.MessageBox]::Show('Are you sure you would like to run the script?','Script Confirmation','YesNo','Warning')
switch  ($msgBoxInput) {
    'Yes' {$run = $true}
    'No' {$run = $false}
}

$timer=[system.diagnostics.stopwatch]::StartNew()
"Beginning process..."

$fileLoc = [Environment]::GetFolderPath('Desktop')

if ($run) {
    [array]$comps = @()
    $comps += Import-Csv "$fileLoc\NonCompliantComputers.csv" -Header A | Select-Object -Unique A
    $badHosts = @()
    $goodHosts = @()
    ForEach ($comp in $comps) {
        try {
            Get-ADComputer $comp.A -ErrorAction Stop -Properties Name,IPv4Address | Out-Null
            Write-Host "Will remove $($comp.A) from directory..." -ForegroundColor Green
            Write-Host "====================================="
            $worked = $true
            }
        catch {
            $worked = $false
            Write-Host "$($comp.A) does not exist" -ForegroundColor Yellow
            $badHosts += $($comp.A)
            }
        if ($worked) {
            $goodHosts += $($comp.A)
            }
    }
    $runningSid = get-aduser $env:USERNAME | select -ExpandProperty SID
    foreach ($comp in $goodHosts) {
        #Get our subobjects
        $compAD = get-adcomputer $comp
        $compDN = $compAD.distinguishedname
        $subObjs = Get-ADObject -SearchBase $compDN -Filter * -SearchScope Subtree | Where {$_.distinguishedname -ne $compDN}

        #Delete the subobjects manually
        #Because subtree control in the GUI, and the -recursive switch in remove-adobject
        foreach ($item in $subObjs) {
            #Have to manually give us delete permissions for scripted deletion because reasons
            $acl = Get-Acl -path "AD:\$($item.DistinguishedName)"
            $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule(
                     $runningSid,
                     [System.DirectoryServices.ActiveDirectoryRights]::DeleteTree,
                     [System.Security.AccessControl.AccessControlType]::Allow,
                     "573a1e20-51bb-4501-9b5d-16333efdcd4e",
                     [DirectoryServices.ActiveDirectorySecurityInheritance]::All
                     )
            $acl.AddAccessRule($ace)
            Set-Acl -Path "AD:\$($item.DistinguishedName)" -AclObject $acl
        $item.DistinguishedName | Set-ADObject -ProtectedFromAccidentalDeletion:$false -PassThru | Remove-ADObject -Confirm:$false -recursive
        $badHosts | Out-File "$fileLoc\BadHosts.txt" -Force
        }
    }
}

"Finished in " + [math]::Round($stopwatch.Elapsed.TotalMinutes,2) + " minutes"
Read-Host -Prompt "Press Enter to close window"