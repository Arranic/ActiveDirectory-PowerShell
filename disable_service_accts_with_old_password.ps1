# populate default vars to use later
$desktop = [environment]::GetFolderPath('Desktop')
$targets = Import-Csv "$desktop\svc_acct_strikes.csv" # pull targets from file
$measure_date = (Get-Date).AddDays(-365) # date to compare password last set props against
$bad_targets = @()

foreach ($acct in $targets.SamAccountName){
    Try {
        # pull the password last set date on the svc acct in the loop for use later
        $validate = Get-ADUser $acct -Properties passwordlastset -ErrorAction stop | select passwordlastset

        # validate the password last set date against the measure date. If the password last set date is older than the measure date, disabled the account and set the description.
        if ($validate.passwordlastset -lt $measure_date) {
            Write-Host "$($acct) has not had its password reset in over 1 year. Disabling..." -ForegroundColor Yellow
            # Remove-ADUser $acct -Confirm:$false -WhatIf # Only use when OC wants to delete the accounts
            Set-ADUser $acct -Enabled:$false -Description "Disabled per 616 OC CTO due to old password. Please contact the 616 OC at VOSIP 302-969-1246" -ErrorAction Stop -Confirm:$false -WhatIf
        }
        else {
            # no need to change password
            Write-Host "$($acct) has a password that has been reset in the past year and does not need to be disabled." -ForegroundColor Green
        }
    }
    Catch {
        # catch error
        Write-Host "$($acct) was not found in the directory." -ForegroundColor Red
        $bad_targets += $acct
    }
}
