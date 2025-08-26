# Define the filter for archived users in the Archived OU
$ArchivedOU = "OU=Archived,DC=*,DC=*,DC=*,DC=*" # Replace with your actual Archived OU path
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

# Define registry paths for TLS 1.1 and TLS 1.2
$protocols = @("TLS 1.1", "TLS 1.2")
$basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols"

foreach ($protocol in $protocols) {
    $clientPath = Join-Path -Path $basePath -ChildPath "$protocol\Client"
    $serverPath = Join-Path -Path $basePath -ChildPath "$protocol\Server"
    Write-Host "Checking $protocol settings..."

    foreach ($path in @($clientPath, $serverPath)) {
        if (Test-Path $path) {
            $enabled = Get-ItemProperty -Path $path -Name "Enabled" -ErrorAction SilentlyContinue
            $disabledByDefault = Get-ItemProperty -Path $path -Name "DisabledByDefault" -ErrorAction SilentlyContinue
            $lastPart = $path.Split('\')[-1]

            write-host $lastPart $protocol
            Write-Host "  Enabled: $($enabled.Enabled)"
            Write-Host "  DisabledByDefault: $($disabledByDefault.DisabledByDefault)"
        } else {
            Write-Host "$path does not exist."
        }
    }
}

######

# Define file paths
$etlFile = "C:\Temp\TLS_traffic.etl"
$csvFile = "C:\Temp\TLS_traffic.csv"

# Ensure Temp directory exists
if (-not (Test-Path "C:\Temp")) {
    New-Item -Path "C:\" -Name "Temp" -ItemType Directory | Out-Null
}

try {
    Write-Host "Starting netsh trace..."
    netsh trace start capture=yes tracefile="$etlFile" maxSize=512

    $durationSeconds = 60
    Write-Host "Capturing traffic for $durationSeconds seconds..."
    Start-Sleep -Seconds $durationSeconds

    Write-Host "Stopping netsh trace..."
    netsh trace stop

    Write-Host "Converting ETL to CSV..."
    tracerpt "$etlFile" -o "$csvFile" -of CSV

    Write-Host "Searching for TLS 1.0 and TLS 1.1 usage..."
    $tlsPatterns = @("TLS 1.0", "TLS 1.1", "0x0301", "0x0302")
    $matches = Select-String -Path $csvFile -Pattern $tlsPatterns

    if ($matches) {
        Write-Host "`nTLS 1.0 or TLS 1.1 usage detected:`n"
        $matches | ForEach-Object { $_.Line }
    } else {
        Write-Host "`nNo TLS 1.0 or TLS 1.1 usage found in captured traffic."
    }
}
catch {
    Write-Host "An error occurred: $_"
}
finally {
    if (Test-Path $etlFile) {
        Remove-Item $etlFile -Force
    }
    Write-Host "Cleanup complete."
}

