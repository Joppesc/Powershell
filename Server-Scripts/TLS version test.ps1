# Define the filter for archived users in the Archived OU
$ArchivedOU = "OU=Archived,DC=lab,DC=corp,DC=loyens,DC=nl" # Replace with your actual Archived OU path
$ArchivedUsers = Get-ADUser -SearchBase $ArchivedOU -Filter * -Properties EmployeeID
 
# Update the employeeID attribute for each archived user
foreach ($User in $ArchivedUsers) {
    try {
        $OldEmployeeID = $User.EmployeeID
        if ([string]::IsNullOrWhiteSpace($OldEmployeeID)) {
            Write-Warning "User '$($User.SamAccountName)' does not have an existing Employee ID. Skipping."
            continue
        }
        $NewEmployeeID = "$OldEmployeeID.A"
        Set-ADUser -Identity $User.SamAccountName -EmployeeID $NewEmployeeID
        Write-warning "Employee ID for user '$($User.SamAccountName)' has been updated to '$NewEmployeeID'."
    } catch {
        Write-Error "Failed to update Employee ID for user '$($User.SamAccountName)': $_"
    }
}