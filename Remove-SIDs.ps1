<#
Title:          Remove-SIDS
Version:        1.0 (18 OCT 21)
Author:         A1C Robert Griffin, robert.griffin.23@us.af.mil
Co-Author:      N/A
Description:    This script searches for and removes orphaned SIDS for whatever path strings are fed to it.
#>

param (
    [Parameter(Mandatory = $True)]    
    [string]
    $FilePath
)

# Function Definitions :::::::::::::::::::::::::
function Remove-SIDs {
    # This path is a path to a file that specifies the paths of the folders we are attempting to check and remove orphaned SIDs from.
    param (
        [Parameter(Mandatory = $True)]
        [string]
        $FilePath
    )

    # Import the path content as array. This input path will be provided when running from the command line and also expects a .txt file. Casting as array so even if the file of paths has only 1 path, the script doesn't die.
    [array]$path_array = Get-Content $FilePath

    # Recon the ACL to gather the empty SIDS
    foreach ($p in $path_array) {
        if (Test-Path $p) {
            $acl = Get-Acl -Path $p
            $acl_List = $acl.Access
            foreach ($rule in $acl_List) {
                $value = $rule.IdentityReference.value
                $ADObj = ([adsisearcher]"objectSid=value").findone()
                if ($value -match "^S-1-5" -and $ADObj -eq $null) {
                    # Show in console what SID was found
                    Write-Host "Orphaned SID found: $value in $p `n......removing SID....." -ForegroundColor Yellow

                    # Remove the orphaned SID
                    $acl.RemoveAccessRuleAll($rule)
                    Start-Sleep -Seconds 1
                }
            }
            # Set the ACL in the loop
            Set-Acl -Path $p -AclObject $acl
            Start-Sleep -Seconds 1

            # Check if remove process was successful
            $checkAcl = Get-acl -path $p
            $remaining_SIDs = $checkAcl.Access.IdentityReference.value | Where-Object {$_ -like "S-1-5*"}
            if ($remaining_SIDs) {
                Write-Host "Removal of $($remaining_SIDs -join ',') was unsuccessful" -ForegroundColor Red
            }
            else {
                Write-Host "No more orphaned SIDs exist for $p" -ForegroundColor Green
            }
        }
        Else {
            Write-Host "$p cannot be found. Please make sure the path is correct." -ForegroundColor Red
        }
    }
}

Remove-SIDS -FilePath $FilePath