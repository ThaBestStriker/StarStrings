$ErrorActionPreference = "Stop"
$DebugPreference = "Continue"     
$VerbosePreference = "Continue" 

Write-Host "Current Time          : $(Get-Date)" -ForegroundColor DarkGray
Write-Host "PowerShell Version    : $($PSVersionTable.PSVersion)" -ForegroundColor DarkGray
Write-Host "Running as Administrator     : $((whoami /groups | Select-String -Pattern 'S-1-5-32-544').Matches.Success)" -ForegroundColor DarkGray
Write-Host ""

$livePath      = "C:\Program Files\Roberts Space Industries\StarCitizen\LIVE"
$userCfgTarget = Join-Path $livePath "USER.cfg"
$dataTarget    = Join-Path $livePath "data"

$repoZipUrl    = "https://github.com/MrKraken/StarStrings/archive/refs/heads/master.zip"

$tempDir       = Join-Path $env:TEMP "StarStrings_DebugInstall_$(Get-Date -Format 'yyyyMMdd_HHmmss')"

Write-Debug "[DEBUG] Live path set to       : $livePath"
Write-Debug "[DEBUG] Target USER.cfg path   : $userCfgTarget"
Write-Debug "[DEBUG] Target data path       : $dataTarget"
Write-Debug "[DEBUG] Temp working directory : $tempDir"
Write-Host ""

function Write-DebugAction {
    param(
        [string]$Step,
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host "[DEBUG] $Step - $Message" -ForegroundColor $Color
}

# tmp dir
Write-DebugAction "Step 1" "Creating temporary working directory" "Cyan"
try {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-DebugAction "Step 1" "Temporary directory created successfully at: $tempDir" "Green"
} catch {
    Write-Error "Failed to create temporary directory: $_"
    exit 1
}

# clone w/o git
Write-DebugAction "Step 2" "Downloading StarStrings package from GitHub" "Cyan"
$zipPath = Join-Path $tempDir "StarStrings.zip"

try {
    Invoke-WebRequest -Uri $repoZipUrl -OutFile $zipPath -UseBasicParsing
    $fileSizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-DebugAction "Step 2" "Download completed successfully ($fileSizeMB MB)" "Green"
} catch {
    Write-Error "CRITICAL: Failed to download the package. Error: $_"
    exit 1
}

# dpkg
Write-DebugAction "Step 3" "Unpacking (extracting) the downloaded ZIP" "Cyan"
try {
    Expand-Archive -Path $zipPath -DestinationPath $tempDir -Force
    Write-DebugAction "Step 3" "Package successfully unpacked" "Green"
} catch {
    Write-Error "Failed to extract the ZIP file: $_"
    exit 1
}


$extractPath = Get-ChildItem -Path $tempDir -Directory |
               Where-Object { Test-Path (Join-Path $_.FullName "USER.cfg") } |
               Select-Object -First 1

if (-not $extractPath) {
    Write-Error "CRITICAL: Could not find the unpacked StarStrings folder containing USER.cfg"
    exit 1
}
$extractPath = $extractPath.FullName
Write-DebugAction "Step 3" "Extracted package located at: $extractPath" "Green"


# Verify LIVE dir struct
Write-DebugAction "Step 4" "Verifying StarCitizen LIVE directory exists" "Cyan"
if (-not (Test-Path $livePath)) {
    Write-Error @"
CRITICAL ERROR: LIVE directory not found!
Expected path: $livePath
The script cannot continue. Please verify your Star Citizen installation is at the exact location you specified.
"@
    exit 1
}
Write-DebugAction "Step 4" "LIVE directory confirmed: $livePath" "Green"

Write-DebugAction "Step 5" "Ensuring target data directory exists" "Cyan"
if (-not (Test-Path $dataTarget)) {
    New-Item -ItemType Directory -Path $dataTarget -Force | Out-Null
    Write-DebugAction "Step 5" "Created missing data directory: $dataTarget" "Yellow"
} else {
    Write-DebugAction "Step 5" "Data directory already exists: $dataTarget" "Green"
}


# Test usr cfg path
$packageUserCfg = Join-Path $extractPath "USER.cfg"
Write-DebugAction "Step 6" "Processing USER.cfg from package" "Cyan"

if (Test-Path $userCfgTarget) {
    Write-DebugAction "Step 6" "USER.cfg already exists → appending package contents" "Yellow"
    try {
        Get-Content -Path $packageUserCfg -Encoding UTF8 | Add-Content -Path $userCfgTarget -Encoding UTF8 -Force
        Write-DebugAction "Step 6" "Successfully appended contents to existing USER.cfg" "Green"
    } catch {
        Write-Error "Failed to append to USER.cfg: $_"
        exit 1
    }
} else {
    Write-DebugAction "Step 6" "USER.cfg does not exist → copying from package" "Yellow"
    try {
        Copy-Item -Path $packageUserCfg -Destination $userCfgTarget -Force
        Write-DebugAction "Step 6" "USER.cfg copied successfully" "Green"
    } catch {
        Write-Error "Failed to copy USER.cfg: $_"
        exit 1
    }
}

# cp over and error checks
$packageData = Join-Path $extractPath "Data"
Write-DebugAction "Step 7" "Starting recursive copy of package Data folder" "Cyan"

if (Test-Path $packageData) {
    try {
        Copy-Item -Path "$packageData\*" -Destination $dataTarget -Recurse -Force
        Write-DebugAction "Step 7" "Recursive copy of Data contents completed successfully" "Green"
    } catch {
        Write-Error "Failed during recursive Data copy: $_"
        exit 1
    }
} else {
    Write-Warning "WARNING: 'Data' folder not found in the downloaded package (expected at $packageData)"
}

# Suc install
Write-Host ""
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "          INSTALLATION COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor Green
Write-Host "All actions logged in DEBUG mode." -ForegroundColor Green
Write-Host "Target LIVE path used : $livePath" -ForegroundColor Green
Write-Host "USER.cfg location     : $userCfgTarget" -ForegroundColor Green
Write-Host "Data folder location  : $dataTarget" -ForegroundColor Green
Write-Host ""
Write-Host "You can now launch Star Citizen." -ForegroundColor White
Write-Host "Temporary files are located at: $tempDir" -ForegroundColor DarkGray
Write-Host "(You may delete the temp folder manually if desired)" -ForegroundColor DarkGray
Write-Host "=================================================================" -ForegroundColor Green

# Reivew changes
Write-Host ""
Write-Host "Press [Enter] to close this window..." -ForegroundColor Cyan
Read-Host | Out-Null