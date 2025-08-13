# Get the current date and time
[datetime]$dtToday = [datetime]::NOW
$strCurrentMonth = $dtToday.Month.ToString()
$strCurrentYear = $dtToday.Year.ToString()

# Set the date to the first day of the current month
[datetime]$dtMonth = $strCurrentMonth + '/1/' + $strCurrentYear

# Find the first Tuesday of the month
while ($dtMonth.DayofWeek -ne 'Tuesday') { 
      $dtMonth = $dtMonth.AddDays(1) 
}

# Calculate the second Tuesday of the month (Patch Tuesday)
$strPatchTuesday = $dtMonth.AddDays(7)
$intOffSet = 1

# Check if the current date is within the Patch Tuesday week
if ([datetime]::NOW -lt $strPatchTuesday -or [datetime]::NOW -ge $strPatchTuesday.AddDays($intOffSet)) {
    # Create an update session and searcher
    $objUpdateSession = New-Object -ComObject Microsoft.Update.Session
    $objUpdateSearcher = $objUpdateSession.CreateupdateSearcher()
    
    # Search for available updates
    $arrAvailableUpdates = @($objUpdateSearcher.Search("IsAssigned=1 and IsHidden=0 and IsInstalled=0").Updates)
    
    # Filter for cumulative updates
    $strAvailableCumulativeUpdates = $arrAvailableUpdates | Where-Object {$_.title -like "*cumulative*"}
    
    # Determine update status
    if ($strAvailableCumulativeUpdates -eq $null) {
        $strUpdateStatus = @{"Update status" = "Up-to-date"}
    } 
    else {
        $strUpdateStatus = @{"Update status" = "Not up-to-date"}
    }
} 
else {
    $strUpdateStatus = @{"Update status" = "Up-to-date"}
}

# Return the update status as a JSON object
return $strUpdateStatus | ConvertTo-Json -Compress