# Import the AzureAD module
Import-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# Path to the CSV file
$csvPath = "C:\Exports\filename.csv"

# Read users from the CSV file
$users = Import-Csv -Path $csvPath -Delimiter ";" -Header userPrincipalName, displayName

# Debugging output to verify CSV import
Write-Output "Imported users from CSV:"
$users | ForEach-Object { Write-Output "userPrincipalName: $($_.userPrincipalName), displayName: $($_.displayName)" }

# Group ID
$groupId = "GroupIDname"

# Array to store user details for CSV export
$userDetails = @()

# Function to generate a password without commas
function New-SecurePassword {
    param (
        [int]$length = 12,
        [int]$nonAlphanumericCharacters = 2
    )
    $password = [System.Web.Security.Membership]::GeneratePassword($length, $nonAlphanumericCharacters)
    
    # Remove commas from the password
    $password = $password -replace ",", ""
    return $password
}

# Loop through each user
foreach ($user in $users) {
    # Check if required columns are present
    if (-not $user.PSObject.Properties.Match("displayName") -or -not $user.PSObject.Properties.Match("userPrincipalName")) {
        Write-Output "Missing required columns for user: $($user)"
        continue
    }

    # Check if displayName is not null or empty
    if ([string]::IsNullOrEmpty($user.displayName)) {
        Write-Output "displayName is null or empty for user: $($user.userPrincipalName)"
        continue
    }
    
    # Split the displayName to get GivenName and Surname
    $displayName = $user.displayName.Trim()
    Write-Output "Processing user: $($user.userPrincipalName)"
    Write-Output "DisplayName: $displayName"
    $nameParts = $displayName -split ", "
    Write-Output "Name parts: $($nameParts)"

    if ($nameParts.Length -eq 2) {
        $surname = $nameParts[0].Trim()
        $givenName = $nameParts[1].Trim()
    } else {
        Write-Output "Invalid displayName format for user: $($user.userPrincipalName)"
        continue
    }

    # Generate a new password without commas
    $newPassword = New-SecurePassword

    # Convert the password to a SecureString
    $securePassword = ConvertTo-SecureString -String $newPassword -AsPlainText -Force

    # Create the user in Azure AD
    try {
        $newUser = New-AzureADUser `
            -DisplayName $user.displayName `
            -GivenName $givenName `
            -Surname $surname `
            -UserPrincipalName $user.userPrincipalName `
            -MailNickName $user.userPrincipalName.Split('@')[0] `
            -PasswordProfile (New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile -Property @{ Password = $securePassword; ForceChangePasswordNextLogin = $true }) `
            -UsageLocation 'NL' `
            -AccountEnabled $true
    } catch {
            Write-Output "Failed to create user: $($user.userPrincipalName). Error: $_"
        continue
    }
    
    # Check if the user was created successfully
    if ($null -ne $newUser) {
        # Add the user to the group
        Add-AzureADGroupMember -ObjectId $groupId -RefObjectId $newUser.ObjectId

        # Enable the user account
        Set-AzureADUser -ObjectId $newUser.ObjectId -AccountEnabled $true

        # Store user details and new password in the array
        $userDetails += [PSCustomObject]@{
            UserPrincipalName = $newUser.UserPrincipalName
            NewPassword      = $newPassword
        }

        # Log the actions of creating users
        Write-Output "Creation of user: $($user.userPrincipalName)"
        Write-Output "DisplayName: $($user.displayName)"
    } else {
        Write-Output "Failed to create user: $($user.userPrincipalName)"
    }
}
# Export user details to a CSV file
$userDetails | Export-Csv -Path "C:\Exports\user_passwords.csv" -NoTypeInformation -Delimiter ";"

Write-Output "end script"