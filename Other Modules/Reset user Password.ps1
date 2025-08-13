# Import the AzureAD module
Import-Module AzureAD

# Connect to Azure AD
Connect-AzureAD

# List of users to add to the group
$newUsers = @(





)

# Array to store user details for CSV export
$userDetails = @()

# Loop through each user
foreach ($user in $newUsers) {

    # Get the user object
    $userObject = Get-AzureADUser -ObjectId $user

    # Enable the user account
    Set-AzureADUser -ObjectId $userObject.ObjectId -AccountEnabled $true

    # Generate a new password
    $newPassword = [System.Web.Security.Membership]::GeneratePassword(12, 2)
    $newPassword = $newPassword -replace ","

    # Convert the password to a SecureString
    $securePassword = ConvertTo-SecureString -String $newPassword -AsPlainText -Force
    
    # Reset the user's password
    Set-AzureADUserPassword -ObjectId $userObject.ObjectId -Password $securePassword
    
    # Store user details and new password in the array
    $userDetails += [PSCustomObject]@{
    UserPrincipalName = $userObject.UserPrincipalName
    NewPassword      = $newPassword
    }
}