Connect-MgGraph -Scopes "User.ReadWrite.All", "UserAuthenticationMethod.ReadWrite.All" -TenantId "fill in tenantID"
#Import-Module Microsoft.Graph.Users

$users = Import-Csv "C:\Exports\name.csv" -Header UserPrincipalName -Delimiter ";"
$results = @()

function Get-SimplePassword {
    param([int]$length = 8)
    if ($length -gt 8) {
        $length = 8
    }
    $upperArray = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.ToCharArray()
    $digitArray = '0123456789'.ToCharArray()
    $specialArray = '!@#$%&*'.ToCharArray()
    $lowerArray = 'abcdefghijklmnopqrstuvwxyz'.ToCharArray()

    $pwdChars = @()
    $pwdChars += ($upperArray | Get-Random -Count 1)
    $pwdChars += ($digitArray | Get-Random -Count 1)
    $pwdChars += ($specialArray | Get-Random -Count 1)

    $remaining = $length - 3
    for ($i = 1; $i -le $remaining; $i++) {
        $pwdChars += ($lowerArray | Get-Random -Count 1)
    }

    $pwdChars = $pwdChars | Sort-Object { Get-Random }
    return -join $pwdChars
}

foreach ($user in $users) {
    $password = Get-SimplePassword -length 8
    $method = "28c10230-6103-485e-b985-444c60001490"

    Reset-MgUserAuthenticationMethodPassword -UserId $user.UserPrincipalName -AuthenticationMethodId $method -NewPassword $password
    Update-MgUser -UserId $user.UserPrincipalName -PasswordProfile @{ForceChangePasswordNextSignIn = $true}

    write-host "Password reset for user $($user.UserPrincipalName)"
    $results += [PSCustomObject]@{
        UserPrincipalName = $user.UserPrincipalName
        NewPassword       = $password
    }
}

$results | Export-Csv "C:\Exports\user_passwords.csv" -NoTypeInformation -Delimiter ";"
