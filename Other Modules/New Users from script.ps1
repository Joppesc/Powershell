# Import the AzureAD module
Import-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# Function to generate a random password
function New-SecureRandomPassword {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([System.Security.SecureString])]
    param (
        [int]$length = 12
    )

    if ($PSCmdlet.ShouldProcess("Generating a new secure random password")) {
        $chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()"
        $password = -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
        $securePassword = New-Object -TypeName System.Security.SecureString
        $password.ToCharArray() | ForEach-Object { $securePassword.AppendChar($_) }
        return $securePassword
    }
}

# List of new users to create
$newUsers = @(
    @{
        UserPrincipalName = "Insert UPN"
        DisplayName = "fill in"
        GivenName = "fill in"
        Surname = "fill in"
        UsageLocation = "NL"  # Set to Netherlands
        MailNickname = "fill in"
    },
    # Add more users as needed
)

#Create new users in Azure AD
foreach ($user in $newUsers)
{
    $securePassword = New-SecureRandomPassword

    New-AzureADUser -UserPrincipalName $user.UserPrincipalName `
                    -DisplayName $user.DisplayName `
                    -GivenName $user.GivenName `
                    -Surname $user.Surname `
                    -PasswordProfile @{ Password = $securePassword; ForceChangePasswordNextLogin = $true } `
                    -AccountEnabled $false `
                    -UsageLocation $user.UsageLocation `
                    -MailNickname $user.MailNickname `

    Write-Output "Created user: $($user.UserPrincipalName)"
}
    # Log the actions of creating users
    Write-Output "Simulating creation of user: $($user.UserPrincipalName)"
    Write-Output "DisplayName: $($user.DisplayName)"
    Write-Output "GivenName: $($user.GivenName)"
    Write-Output "Surname: $($user.Surname)"
    Write-Output "UsageLocation: $($user.UsageLocation)"
    Write-Output "Mail: $($user.Mail)"
    Write-Output "MailNickname: $($user.MailNickname)"
    Write-Output "Password: $securePassword"
    Write-Output "----------------------------------------"