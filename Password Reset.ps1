#this script generates random passwords for multiple users/service accounts

#Password command forces 2 sym / 2 num / 2 UPPER / 2 lower and randomizes last 8 
#Common error digits have been removed ex: oO0 ,. :;
Function Generate-Password {
    param ([Int]$numPasswords = 1)

    1..$numPasswords | ForEach-Object {
        $CharsD = [Char[]]"123456789" 
        $CharsL = [Char[]]"abcdefghjkmnpqrstuvxyz"
        $CharsU = [Char[]]"ABCDEFGHJKLMNPQRSTUVXYZ"
        $CharsS = [Char[]]"!@#$%^&*+=?"
        $CharsA = [Char[]]"!@#$%^&*+=?ABCDEFGHJKLMNPQRSTUVXYZabcdefghjkmnpqrstuvxyz123456789"
        $Password = ""
        $Password += ($CharsD | Get-Random -Count 2) -join ""
        $Password += ($CharsL | Get-Random -Count 2) -join ""
        $Password += ($CharsU | Get-Random -Count 2) -join ""
        $Password += ($CharsS | Get-Random -Count 2) -join ""
        $Password += ($CharsA | Get-Random -Count (8..12 | Get-Random)) -join ""
        $Password = ($Password.ToCharArray()| Sort-Object {Get-Random}) -join ""
        Write-Output $Password
        #$Password #| clip.exe
        Add-Type -Assembly PresentationCore
        $clipText = $Password | Out-String -Stream
        [Windows.Clipboard]::SetText($clipText)
    }
}

#Change path to match the file
$desktop = [Environment]::GetFolderPath("Desktop")
$accounts = Import-Csv "$desktop\Service Account Reset.csv" -Header Account

foreach ($account in $accounts.Account) {
    $pass = Generate-Password
    Get-ADUser "$account" | `
    Set-ADAccountPassword -Reset -NewPassword (ConvertTo-SecureString -AsPlainText $pass -Force)

    $line = [Ordered]@{"Account Name"="$account";"Password"="$pass"}
    $export = New-Object -TypeName psobject -Property $line
    $export | Export-csv -NoTypeInformation -Append "$desktop\SVCpasswords.csv"
}