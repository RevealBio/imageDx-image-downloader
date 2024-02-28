Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()
# Function to check gcloud installation
function Check-GcloudInstallation {
    try {
        & gcloud --version | Out-Null
        return $true
    } catch {
        return $false
    }
}
# Check for gcloud installation
if (-not (Check-GcloudInstallation)) {
    [System.Windows.Forms.MessageBox]::Show(
        "gcloud is not installed. Please install Google Cloud SDK from https://cloud.google.com/sdk/install",
        "Installation Required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Exclamation
    )
    return
}
# Define the path for the log file
$logFilePath = Join-Path $PSScriptRoot "UserActivityLog.txt"

# Function to append log with timestamp
function Append-LogWithTimestamp {
    param(
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $logFilePath -Value $logMessage
}
# Validation Function
function Validate-GcsPath($path) {
    $isValid = $path -match '^gs://[^/]+/[^/]+(/[^/]*)*$'
    if ($isValid) {
        $OutputBox.AppendText("Validating $path`r`n")
        Append-LogWithTimestamp "Validating $path"
    } else {
        $OutputBox.AppendText("Invalid GCS path: $path`r`n")
        Append-LogWithTimestamp "Invalid GCS path: $path"
    }
    return $isValid
}

function Get-ValidPaths {
    $inputLines = $InputTextBox.Text -split "`r`n" | Where-Object { $_ -ne "" }
    $paths = @()
    foreach ($line in $inputLines) {
        if ($line -match '"?gs://[^"]+"?') {
            $match = $line -match '"?(gs://[^"]+)"?'
            if ($match) {
                $path = $matches[1].Trim()
                $paths += $path
                Append-LogWithTimestamp "Extracted GCS path: $path"
            }
        }
    }
    $validPaths = $paths | Where-Object { Validate-GcsPath $_ }
    return $validPaths
}

function Verify-Checksums {
    param(
        [string]$localDirectoryPath,
        [string]$gcsPath
    )
    try {
        $OutputBox.AppendText("`r`nStarting checksum verification...`r`n")
        Append-LogWithTimestamp "Starting checksum verification..."

        # Get all files in the local directory, including nested ones
        $localFiles = Get-ChildItem -Path $localDirectoryPath -File -Recurse
        foreach ($file in $localFiles) {
            # Calculate the relative path of the file with respect to the local directory
            $relativePath = $file.FullName.Substring($localDirectoryPath.Length).TrimStart('\')
            
            # Remove the parent directory from $relativePath
            $relativePathComponents = $relativePath -split '\\'
            if ($relativePathComponents.Length -gt 1) {
                $relativePath = [System.IO.Path]::Combine($relativePathComponents[1..($relativePathComponents.Length - 1)] -join '\')
            }
            # Replace backslashes with forward slashes for GCS path compatibility
            $relativePath = $relativePath -replace '\\', '/'
            # Construct the full GCS path for the file
            $remoteFilePath = "$gcsPath/$relativePath"

            $OutputBox.AppendText("`r`nVerifying $relativePath...`r`n")

            # Compute the MD5 hash of the local file
            $localHashOutput = & cmd /c gsutil hash -h $file.FullName
            $localHash = ($localHashOutput | Where-Object { $_ -match "md5" } | ForEach-Object { $_ -split "\s+" })[-1]

            # Compute the MD5 hash of the corresponding remote file
            $remoteHashOutput = & cmd /c gsutil hash -h $remoteFilePath
            $remoteHash = ($remoteHashOutput | Where-Object { $_ -match "md5" } | ForEach-Object { $_ -split "\s+" })[-1]

            # Compare the hashes
            if ($localHash -eq $remoteHash) {
                $OutputBox.AppendText("`r`nChecksum match confirmed for $relativePath`r`n")
                Append-LogWithTimestamp "Checksum match confirmed for $relativePath"
            } else {
                $OutputBox.AppendText("`r`nChecksum mismatch detected for $relativePath. Please verify the files.`r`n")
                Append-LogWithTimestamp "Checksum mismatch detected for $relativePath"
            }
        }
        $OutputBox.AppendText("`r`nChecksum verification complete for all downloaded files.`r`n")
        Append-LogWithTimestamp "Checksum verification complete for all downloaded files."
    } catch {
        $errorMessage = $_.Exception.Message
        $OutputBox.AppendText("Error during checksum verification: $errorMessage`r`n")
        Append-LogWithTimestamp "Error during checksum verification: $errorMessage"
    }
}



# GUI Elements
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'GSUtil Command Executor for Multiple Folders'
$Form.Size = New-Object System.Drawing.Size(480,480)
$Form.StartPosition = 'CenterScreen'
$Label = New-Object System.Windows.Forms.Label
$Label.Location = New-Object System.Drawing.Point(10,20)
$Label.Size = New-Object System.Drawing.Size(280,20)
$Label.Text = 'Enter GCS paths (one per line):'
$Form.Controls.Add($Label)
$InputTextBox = New-Object System.Windows.Forms.TextBox
$InputTextBox.Location = New-Object System.Drawing.Point(10,40)
$InputTextBox.Size = New-Object System.Drawing.Size(420,200)
$InputTextBox.Multiline = $true
$InputTextBox.ScrollBars = 'Vertical'
$Form.Controls.Add($InputTextBox)
$ExecuteButton = New-Object System.Windows.Forms.Button
$ExecuteButton.Location = New-Object System.Drawing.Point(10,250)
$ExecuteButton.Size = New-Object System.Drawing.Size(75,23)
$ExecuteButton.Text = 'Download'
$Form.Controls.Add($ExecuteButton)
$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Location = New-Object System.Drawing.Point(10,280)
$OutputBox.Size = New-Object System.Drawing.Size(420,100)
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = 'Vertical'
$Form.Controls.Add($OutputBox)
# Add a new button for Service Account Authentication
$ServiceAccountButton = New-Object System.Windows.Forms.Button
$ServiceAccountButton.Location = New-Object System.Drawing.Point(95,250) # Adjusted position
$ServiceAccountButton.Size = New-Object System.Drawing.Size(180,23)
$ServiceAccountButton.Text = 'Auth with Service Account'
$Form.Controls.Add($ServiceAccountButton)
# Create a new button for checksum verification
$ChecksumButton = New-Object System.Windows.Forms.Button
$ChecksumButton.Location = New-Object System.Drawing.Point(280,250) # Adjust position as needed
$ChecksumButton.Size = New-Object System.Drawing.Size(150,23)
$ChecksumButton.Text = 'Verify Checksums'
$Form.Controls.Add($ChecksumButton)


$userInput = Get-Content 'gcsPaths.txt' -Raw  # Use -Raw if you expect a single block of text
$InputTextBox.Text = $userInput

# Event Handlers for the Service Account Button
$ServiceAccountButton.Add_Click({
    Append-LogWithTimestamp "Service Account Authentication initiated."
    # Use $PSScriptRoot to get the directory of the current script
    $serviceAccountKeyPath = Join-Path $PSScriptRoot "service_key.json"
    # Check if the service account key file exists
    if (-not (Test-Path $serviceAccountKeyPath)) {
        # Create an OpenFileDialog to select the service account key file
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.InitialDirectory = $PSScriptRoot
        $openFileDialog.Filter = "JSON files (*.json)|*.json"
        $openFileDialog.Title = "Select the service account key file"
        # Show the OpenFileDialog
        $result = $openFileDialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $serviceAccountKeyPath = $openFileDialog.FileName
        } else {
            [System.Windows.Forms.MessageBox]::Show("No file selected. Service account authentication aborted.", "File Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
    }
    # Assuming the selected service_key.json contains the necessary project and service account information
    $serviceAccountData = Get-Content $serviceAccountKeyPath -Raw | ConvertFrom-Json
    $serviceAccountEmail = $serviceAccountData.client_email
    $projectName = $serviceAccountData.project_id
    # Set account and activate service account
    & cmd /c gcloud config set account $serviceAccountEmail
    & cmd /c gcloud auth activate-service-account --key-file=$serviceAccountKeyPath --project=$projectName
    # Change button color to green if authentication successful
    $ServiceAccountButton.BackColor = [System.Drawing.Color]::Green
})

$ChecksumButton.Add_Click({
    Append-LogWithTimestamp "Checksum verification initiated."
    $OutputBox.AppendText("ValidPaths: $validPaths`r`n")
    $validPaths = Get-ValidPaths
    foreach ($path in $validPaths) {
        # Assuming $localDirectoryPath is constructed similarly to before
        $localDirectoryPath = $path -replace '^gs://[^/]+/', '' -replace '/', '\' # Convert GCS path to a local path format
        $localDirectoryFullPath = Join-Path $PWD "Images\$localDirectoryPath"

        # Call the checksum verification function
        $OutputBox.AppendText("localDirectoryPath: $localDirectoryPath`r`n")
        $OutputBox.AppendText("gcsPath: $path`r`n")
        Verify-Checksums -localDirectoryPath $localDirectoryFullPath -gcsPath $path
    }
})

$ExecuteButton.Add_Click({
    $OutputBox.Clear()
    Append-LogWithTimestamp "Download command initiated."
    $inputLines = $InputTextBox.Text -split "`r`n" | Where-Object { $_ -ne "" }
    $paths = @()
    foreach ($line in $inputLines) {
        if ($line -match '"?gs://[^"]+"?') {
            $match = $line -match '"?(gs://[^"]+)"?'
            if ($match) {
                $path = $matches[1].Trim()
                $paths += $path
                Append-LogWithTimestamp "Extracted GCS path: $path"
            }
        }
    }
    $validPaths = $paths | Where-Object { Validate-GcsPath $_ }
    if ($validPaths) {
        # Ensure the Images directory exists
        $imagesDir = Join-Path $PWD "Images"
        if (-not (Test-Path $imagesDir)) {
            New-Item -ItemType Directory -Path $imagesDir
            Append-LogWithTimestamp "Created Images directory."
        }
        foreach ($path in $validPaths) {
            $OutputBox.AppendText("Downloading $path`r`n")
            Append-LogWithTimestamp "Downloading $path"
            #$localPath = $path -replace '^gs://', '' -replace '/', '\' # Convert GCS path to a local path format for checking
            $localPath = $path -replace '^gs://[^/]+/', '' -replace '/', '\' # Convert GCS path to a local path format for checking
            $localDirectoryPath = Join-Path $PWD "Images\$localPath"
            # Ensure the local directory exists
            if (-not (Test-Path $localDirectoryPath)) {
                New-Item -ItemType Directory -Path $localDirectoryPath -Force
                Append-LogWithTimestamp "Created directory structure for $pathStructure."
            }
            $command = "gsutil -m cp -r `"$path`" `"${localDirectoryPath}`""
            try {
                $output = & cmd /c $command
                if ($output) {
                    $OutputBox.AppendText($output)
                    Append-LogWithTimestamp "Output: $output"
                }
                # Validate the existence of the downloaded file or directory
                Append-LogWithTimestamp "PWD: $PWD"
                Append-LogWithTimestamp "localPath: $localPath"
                Append-LogWithTimestamp "LocalDirPath: $localDirectoryPath"
                if (Test-Path $localDirectoryPath) {
                    $OutputBox.AppendText("`r`nDownload Complete for $path`r`n")
                    Append-LogWithTimestamp "Download Complete for $path"
                } else {
                    $OutputBox.AppendText("`r`nDownload failed or file does not exist for $path`r`n")
                    Append-LogWithTimestamp "Download failed or file does not exist for $path"
                }
            } catch {
                $errorMessage = $_.Exception.Message
                $OutputBox.AppendText("Error: $errorMessage`r`n")
                Append-LogWithTimestamp "Error executing command for ${path}: ${errorMessage}"
            }
        }
        $OutputBox.AppendText("`r`nAll downloads complete.`r`n")
    } else {
        $OutputBox.AppendText("No valid GCS paths found. Please check your input.`r`n")
        Append-LogWithTimestamp "No valid GCS paths found."
    }
})
# Show the main form
$Form.ShowDialog()