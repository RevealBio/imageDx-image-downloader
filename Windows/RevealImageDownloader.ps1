Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.Application]::EnableVisualStyles()

# Utility Functions
function Check-GcloudInstallation {
    try {
        & gcloud --version | Out-Null
        return $true
    } catch {
        return $false
    }
}

function Append-LogWithTimestamp {
    param([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $global:logFilePath -Value "$timestamp - $message"
}

function Validate-GcsPath {
    param([string]$path)
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

function Sanitize-Path {
    param ([string]$path)
    return ($path -replace '\*', '').Replace('[*:?"><|]', '_')
}

function Get-ValidPaths {
    $inputLines = $InputTextBox.Text -split "`r`n" | Where-Object { $_ -ne "" }
    $paths = @()
    foreach ($line in $inputLines) {
        if ($line -match '"?gs://[^"]+"?') {
            $match = $line -match '"?(gs://[^"]+)"?'
            if ($match) {
                $paths += $matches[1].Trim()
            }
        }
    }
    return $paths | Where-Object { Validate-GcsPath $_ }
}

# Checksum Verification Function
function Verify-Checksums {
    param(
        [string]$localDirectoryPath,
        [string]$gcsPath
    )
    try {
        $OutputBox.AppendText("`r`nStarting checksum verification for $localDirectoryPath...`r`n")
        Append-LogWithTimestamp "Starting checksum verification for $localDirectoryPath..."

        $localFiles = Get-ChildItem -Path $localDirectoryPath -File -Recurse
        foreach ($file in $localFiles) {
            $relativePath = $file.FullName.Substring($localDirectoryPath.Length).TrimStart('\')
            $remoteFilePath = "$gcsPath/$relativePath".Replace('\', '/')
            $remoteFilePath = $remoteFilePath.Replace('*','**')
            Append-LogWithTimestamp "`r`nRelative File Path $($remoteFilePath.Replace('"',''''))...`r`n"

            $OutputBox.AppendText("`r`nVerifying $($file.FullName)`r`n")
            Append-LogWithTimestamp "`r`nVerifying $($file.FullName)`r`n"

            # Compute the local file hash
            $localHashOutput = & cmd /c gcloud storage hash $($file.FullName).Replace('"','''') --skip-crc32c --hex
            if ($localHashOutput -and $localHashOutput[2] -match "md5_hash:\s*(\w+)") {
                $localHash = $matches[1]
            } else {
                $OutputBox.AppendText("Failed to compute local hash for $($file.FullName).`r`n")
                Append-LogWithTimestamp "Failed to compute local hash for $($file.FullName).`r`n"
                continue
            }

            $OutputBox.AppendText("`r`nVerifying $($remoteFilePath)...`r`n")
            Append-LogWithTimestamp "`r`nVerifying $($remoteFilePath)...`r`n"

            # Compute the remote file hash
            $remoteHashOutput = & cmd /c gcloud storage hash $remoteFilePath.Replace('"','''') --skip-crc32c --hex
            if ($remoteHashOutput -and $remoteHashOutput[2] -match "md5_hash:\s*(\w+)") {
                $remoteHash = $matches[1]
            } else {
                $OutputBox.AppendText("Failed to compute remote hash for $remoteFilePath.`r`n")
                Append-LogWithTimestamp "Failed to compute remote hash for $remoteFilePath.`r`n"
                continue
            }

            # Compare hashes
            if ($localHash -eq $remoteHash) {
                $OutputBox.AppendText("`r`nChecksum match confirmed for $($file.Name)`r`n")
                Append-LogWithTimestamp "Checksum match confirmed for $($file.Name)"
            } else {
                $OutputBox.AppendText("`r`nChecksum mismatch detected for $($file.Name). Please verify the files.`r`n")
                Append-LogWithTimestamp "Checksum mismatch detected for $($file.Name)"
            }
        }
        $OutputBox.AppendText("`r`nChecksum verification complete for all files in $localDirectoryPath.`r`n")
        Append-LogWithTimestamp "Checksum verification complete for all files in $localDirectoryPath."
    } catch {
        $errorMessage = $_.Exception.Message
        $OutputBox.AppendText("Error during checksum verification: $errorMessage`r`n")
        Append-LogWithTimestamp "Error during checksum verification: $errorMessage"
    }
}




function Download-Files {
    param($validPaths)
    foreach ($path in $validPaths) {
        $OutputBox.AppendText("Downloading $path`r`n")
        Append-LogWithTimestamp "Downloading $path"
        $sanitizedPath = Sanitize-Path -path ($path -replace '^gs://[^/]+/', '' -replace '/', '\')
        $localDirectoryPath = Join-Path $global:imagesDir $sanitizedPath

        # Ensure no trailing slash in the local directory path
        $localDirectoryPath = $localDirectoryPath.TrimEnd('\')

        if (-not (Test-Path $localDirectoryPath)) {
            New-Item -ItemType Directory -Path $localDirectoryPath -Force
        }

        # Replace ternary operator with if-else statement
        $sourcePath = $path
        if (-not $path.EndsWith('/*')) {
            $sourcePath = "$path/*"
        }

        $command = "gcloud storage cp -r `"$sourcePath`" `"$localDirectoryPath`""
        Write-Host $command
        Append-LogWithTimestamp "Executing command: $command"

        try {
            $output = & cmd /c $command
            $OutputBox.AppendText("`r`nDownload Complete for $sourcePath`r`n")
            Append-LogWithTimestamp "Download Complete for $sourcePath"
        } catch {
            $errorMessage = $_.Exception.Message
            $OutputBox.AppendText("Error: $errorMessage`r`n")
            Append-LogWithTimestamp "Error executing command for ${sourcePath}: ${errorMessage}"
        }
    }
    $OutputBox.AppendText("`r`nAll downloads complete.`r`n")
}



# Service Account Authentication
function ServiceAccountAuthHandler {
    Append-LogWithTimestamp "Service Account Authentication initiated."
    $serviceAccountKeyPath = Join-Path $PSScriptRoot "service_key.json"
    if (-not (Test-Path $serviceAccountKeyPath)) {
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.InitialDirectory = $PSScriptRoot
        $openFileDialog.Filter = "JSON files (*.json)|*.json"
        $openFileDialog.Title = "Select the service account key file"
        $result = $openFileDialog.ShowDialog()
        if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
            $serviceAccountKeyPath = $openFileDialog.FileName
        } else {
            [System.Windows.Forms.MessageBox]::Show("No file selected. Service account authentication aborted.", "File Selection", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return
        }
    }
    $serviceAccountData = Get-Content $serviceAccountKeyPath -Raw | ConvertFrom-Json
    $serviceAccountEmail = $serviceAccountData.client_email
    $projectName = $serviceAccountData.project_id
    & cmd /c gcloud config set account $serviceAccountEmail
    & cmd /c gcloud auth activate-service-account --key-file=$serviceAccountKeyPath --project=$projectName
    $ServiceAccountButton.BackColor = [System.Drawing.Color]::Green
}

# Checksum Verification
function VerifyChecksumsHandler {
    $OutputBox.AppendText("`r`nInitiating checksum verification...`r`n")
    Append-LogWithTimestamp "Checksum verification initiated."
    $validPaths = Get-ValidPaths
    foreach ($path in $validPaths) {
        $sanitizedPath = Sanitize-Path -path ($path -replace '^gs://[^/]+/', '' -replace '/', '\')
        $localDirectoryPath = Join-Path $global:imagesDir $sanitizedPath

        # Call the checksum verification function
        $OutputBox.AppendText("localDirectoryPath: $localDirectoryPath`r`n")
        $OutputBox.AppendText("gcsPath: $path`r`n")
        Verify-Checksums -localDirectoryPath $localDirectoryPath -gcsPath $path
    }
}

# Global Variables
$global:logFilePath = Join-Path $PSScriptRoot "UserActivityLog.txt"
$global:imagesDir = Join-Path $PWD "Images"

# Main Form
$Form = New-Object System.Windows.Forms.Form
$Form.Text = 'GSUtil Command Executor for Multiple Folders'
$Form.Size = New-Object System.Drawing.Size(480,480)
$Form.StartPosition = 'CenterScreen'

# Label
$Label = New-Object System.Windows.Forms.Label
$Label.Location = New-Object System.Drawing.Point(10,20)
$Label.Size = New-Object System.Drawing.Size(280,20)
$Label.Text = 'Enter GCS paths (one per line):'
$Form.Controls.Add($Label)

# Input TextBox
$InputTextBox = New-Object System.Windows.Forms.TextBox
$InputTextBox.Location = New-Object System.Drawing.Point(10,40)
$InputTextBox.Size = New-Object System.Drawing.Size(420,200)
$InputTextBox.Multiline = $true
$InputTextBox.ScrollBars = 'Vertical'
$Form.Controls.Add($InputTextBox)

# Execute Button
$ExecuteButton = New-Object System.Windows.Forms.Button
$ExecuteButton.Location = New-Object System.Drawing.Point(10,250)
$ExecuteButton.Size = New-Object System.Drawing.Size(75,23)
$ExecuteButton.Text = 'Download'
$Form.Controls.Add($ExecuteButton)

# Auth with Service Account Button
$ServiceAccountButton = New-Object System.Windows.Forms.Button
$ServiceAccountButton.Location = New-Object System.Drawing.Point(95,250)
$ServiceAccountButton.Size = New-Object System.Drawing.Size(180,23)
$ServiceAccountButton.Text = 'Auth with Service Account'
$ServiceAccountButton.Add_Click({ ServiceAccountAuthHandler })
$Form.Controls.Add($ServiceAccountButton)

# Verify Checksums Button
$ChecksumButton = New-Object System.Windows.Forms.Button
$ChecksumButton.Location = New-Object System.Drawing.Point(280,250)
$ChecksumButton.Size = New-Object System.Drawing.Size(150,23)
$ChecksumButton.Text = 'Verify Checksums'
$ChecksumButton.Add_Click({ VerifyChecksumsHandler })
$Form.Controls.Add($ChecksumButton)

# Output Box
$OutputBox = New-Object System.Windows.Forms.TextBox
$OutputBox.Location = New-Object System.Drawing.Point(10,280)
$OutputBox.Size = New-Object System.Drawing.Size(420,100)
$OutputBox.Multiline = $true
$OutputBox.ScrollBars = 'Vertical'
$Form.Controls.Add($OutputBox)

# Handlers
$ExecuteButton.Add_Click({
    $OutputBox.Clear()
    Append-LogWithTimestamp "Download command initiated."
    $validPaths = Get-ValidPaths
    if ($validPaths) {
        Download-Files -validPaths $validPaths
    } else {
        $OutputBox.AppendText("No valid GCS paths found. Please check your input.`r`n")
        Append-LogWithTimestamp "No valid GCS paths found."
    }
})

# Initialization and Start
if (-not (Check-GcloudInstallation)) {
    [System.Windows.Forms.MessageBox]::Show("gcloud is not installed. Please install Google Cloud SDK from https://cloud.google.com/sdk/install", "Installation Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Exclamation)
    return
}
if (-not (Test-Path $global:imagesDir)) {
    New-Item -ItemType Directory -Path $global:imagesDir
}

$Form.ShowDialog()
