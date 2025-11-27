<#
.SYNOPSIS
  Aspire Project Migration Preparation Script

.DESCRIPTION
  Exports or pushes selected Docker images and copies Aspirate output
  into a migration folder (zip ready to move to another environment).

.PARAMETER ExportMethod
  "push" | "tar"
  If not supplied, user is prompted with arrow key selection:
    [1] Push to Docker Hub (DEFAULT)
    [2] Export as tar files

.PARAMETER AspirateOutputPath
  Path to the aspirate-output folder. If not supplied, user is prompted.

.PARAMETER Images
  Explicit list of images (e.g. "myapi:latest","myweb:latest").
  If not supplied, user gets an interactive image selection UI.

.PARAMETER DockerUsername
  Docker Hub username. If not supplied and ExportMethod = push, user is prompted.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("push", "tar")]
    [string]$ExportMethod,

    [Parameter(Mandatory = $false)]
    [string]$AspirateOutputPath,

    [Parameter(Mandatory = $false)]
    [string[]]$Images,

    [Parameter(Mandatory = $false)]
    [string]$DockerUsername
)

Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Aspire Project Migration Preparation Script" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. Check Docker
# ------------------------------
Write-Host "Checking Docker status..." -ForegroundColor Cyan
try {
    $dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrEmpty($dockerVersion)) {
        throw "Docker is not responding"
    }
    Write-Host "Docker is running (version: $dockerVersion)" -ForegroundColor Green
}
catch {
    Write-Host "`nERROR: Docker is not running or not accessible!" -ForegroundColor Red
    Write-Host "`nPlease ensure that:" -ForegroundColor Yellow
    Write-Host "  1. Docker Desktop is installed" -ForegroundColor White
    Write-Host "  2. Docker Desktop is running" -ForegroundColor White
    Write-Host "  3. You have permissions to access Docker" -ForegroundColor White
    Write-Host "`nStart Docker Desktop and try again." -ForegroundColor Yellow
    exit 1
}

# ------------------------------
# 2. Prepare migration directory
# ------------------------------
$tempPath = "C:\aspire2kube"
if (-not (Test-Path -Path $tempPath)) {
    Write-Host "Creating directory: $tempPath" -ForegroundColor Green
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
}

$tempPath = "C:\aspire2kube"
if (-not (Test-Path -Path $tempPath)) {
    Write-Host "Creating directory: $tempPath" -ForegroundColor Green
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
}

$migrationPath = Join-Path $tempPath "Aspire-Migration"

# Check if migration directory already exists
if (Test-Path -Path $migrationPath) {
    Write-Host "`nWARNING: Migration directory already exists: $migrationPath" -ForegroundColor Yellow
    Write-Host "Do you want to override the existing files? (y/n)" -ForegroundColor Cyan
    $overrideChoice = Read-Host "Override"
    
    if ($overrideChoice -eq "n" -or $overrideChoice -eq "N") {
        # Rename existing directory to -old
        $oldMigrationPath = Join-Path $tempPath "Aspire-Migration-old"
        
        # If -old already exists, remove it first
        if (Test-Path -Path $oldMigrationPath) {
            Write-Host "Removing previous old backup: $oldMigrationPath" -ForegroundColor Gray
            Remove-Item -Path $oldMigrationPath -Recurse -Force
        }
        
        Write-Host "Renaming existing directory to: Aspire-Migration-old" -ForegroundColor Green
        Rename-Item -Path $migrationPath -NewName "Aspire-Migration-old" -Force
    }
    else {
        Write-Host "Overriding existing directory..." -ForegroundColor Yellow
        Remove-Item -Path $migrationPath -Recurse -Force
    }
}

Write-Host "Creating migration directory: $migrationPath" -ForegroundColor Green
New-Item -ItemType Directory -Path $migrationPath -Force | Out-Null
Set-Location $migrationPath

# ------------------------------
# 3. Image selection
# ------------------------------
$selectedImages = @()

if ($Images -and $Images.Count -gt 0) {
    Write-Host "`nUsing images passed as -Images parameter:" -ForegroundColor Cyan
    $Images | ForEach-Object { Write-Host "  $_" -ForegroundColor White }
    $selectedImages = $Images
}
else {
    Write-Host "`nRetrieving Docker images..." -ForegroundColor Cyan
    $allImages = docker images --format "{{.Repository}}:{{.Tag}}"
    $allImages = $allImages | Where-Object { $_ -notlike "*<none>*" -and $_ -ne "" }

    if (-not $allImages -or $allImages.Count -eq 0) {
        Write-Host "`nWARNING: No Docker images found!" -ForegroundColor Yellow
        Write-Host "You may need to build your images first before running this migration script." -ForegroundColor Yellow
        Write-Host "`nDo you want to continue with only copying manifest files? (y/n)" -ForegroundColor Cyan
        $continue = Read-Host "Continue"
        if ($continue -ne "y" -and $continue -ne "Y") {
            Write-Host "`nExiting..." -ForegroundColor Yellow
            exit 0
        }
    }
    else {
        Write-Host "`nAvailable Docker images:" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        for ($i = 0; $i -lt $allImages.Count; $i++) {
            Write-Host "  [$($i + 1)] $($allImages[$i])" -ForegroundColor White
        }
        Write-Host "  [A] Select all" -ForegroundColor Green
        Write-Host "  [M] Manual entry" -ForegroundColor Yellow
        Write-Host ""

        Write-Host "Enter your selection (comma-separated numbers, 'A' for all, or 'M' for manual):" -ForegroundColor Cyan
        Write-Host "Example: 1,3,5 or A or M" -ForegroundColor Gray
        $selection = Read-Host "Selection"

        if ($selection -eq "A" -or $selection -eq "a") {
            $selectedImages = $allImages
            Write-Host "`nSelected all $($selectedImages.Count) images" -ForegroundColor Green
        }
        elseif ($selection -eq "M" -or $selection -eq "m") {
            Write-Host "`nEnter image names manually (one per line, empty line to finish):" -ForegroundColor Cyan
            Write-Host "Example: myapp:latest" -ForegroundColor Gray
            do {
                $manualImage = Read-Host "Image"
                if ($manualImage -ne "") {
                    $selectedImages += $manualImage
                    Write-Host "  Added: $manualImage" -ForegroundColor Green
                }
            } while ($manualImage -ne "")
        }
        else {
            $indices = $selection -split ','
            foreach ($index in $indices) {
                $index = $index.Trim()
                if ($index -match '^\d+$') {
                    $idx = [int]$index - 1
                    if ($idx -ge 0 -and $idx -lt $allImages.Count) {
                        $selectedImages += $allImages[$idx]
                    }
                    else {
                        Write-Host "Warning: Invalid selection '$index' - skipping" -ForegroundColor Yellow
                    }
                }
            }
        }
    }
}

$selectedImages = $selectedImages | Sort-Object -Unique

if ($selectedImages.Count -eq 0) {
    Write-Host "`nNo images selected. Script will continue with manifests only." -ForegroundColor Yellow
}

# ------------------------------
# 4. Choose Export Method (push/tar) - Numbered Selection
# ------------------------------
if (-not $ExportMethod -and $selectedImages.Count -gt 0) {
    Write-Host "`nHow would you like to handle the selected images?" -ForegroundColor Cyan
    Write-Host "  [1] Push to Docker Hub (DEFAULT)" -ForegroundColor White
    Write-Host "  [2] Export as tar files" -ForegroundColor White
    Write-Host ""
    
    $validChoice = $false
    do {
        $exportChoice = Read-Host "Enter choice (1 or 2)"
        
        if ([string]::IsNullOrWhiteSpace($exportChoice)) {
            $exportChoice = "1"
        }
        
        switch ($exportChoice) {
            "1" { 
                $ExportMethod = "push"
                $validChoice = $true
            }
            "2" { 
                $ExportMethod = "tar"
                $validChoice = $true
            }
            default { 
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Yellow
                $validChoice = $false
            }
        }
    } while (-not $validChoice)

    Write-Host "Selected: $ExportMethod" -ForegroundColor Cyan
}

if ($selectedImages.Count -eq 0) {
    # If there are no images, skip image work
    Write-Host "`nNo images to export. Continuing with manifests only." -ForegroundColor Yellow
    $ExportMethod = $null
}

$exportedCount = 0
$pushedCount  = 0
$pushedImageInfo = @()

# ------------------------------
# 5. Export or push
# ------------------------------
if ($ExportMethod -eq "tar" -and $selectedImages.Count -gt 0) {
    Write-Host "`nExporting images as tar files..." -ForegroundColor Cyan
    foreach ($image in $selectedImages) {
        Write-Host "Exporting: $image" -ForegroundColor White
        $safeName = $image -replace '[:\/]', '_'
        $tarFile = Join-Path $migrationPath "$safeName.tar"

        docker save -o $tarFile $image
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Saved to: $tarFile" -ForegroundColor Green
            $exportedCount++
        }
        else {
            Write-Host "  Failed to export $image" -ForegroundColor Red
        }
    }
}
elseif ($ExportMethod -eq "push" -and $selectedImages.Count -gt 0) {
    if (-not $DockerUsername) {
        Write-Host "`nEnter your Docker Hub username:" -ForegroundColor Cyan
        $DockerUsername = Read-Host "Username"
    }

    if ([string]::IsNullOrWhiteSpace($DockerUsername)) {
        Write-Host "ERROR: Docker Hub username is required for push method!" -ForegroundColor Red
        exit 1
    }

    # Check if already logged in to Docker Hub
    Write-Host "`nChecking Docker Hub login status..." -ForegroundColor Cyan
    $dockerInfo = docker info 2>$null | Select-String -Pattern "Username:"
    
    $alreadyLoggedIn = $false
    if ($dockerInfo) {
        $currentUser = ($dockerInfo -replace ".*Username:\s*", "").Trim()
        if ($currentUser -eq $DockerUsername) {
            Write-Host "Already logged in to Docker Hub as: $currentUser" -ForegroundColor Green
            $alreadyLoggedIn = $true
        }
        else {
            Write-Host "Currently logged in as: $currentUser (need to login as: $DockerUsername)" -ForegroundColor Yellow
        }
    }
    
    # Only login if not already logged in with the correct username
    if (-not $alreadyLoggedIn) {
        Write-Host "Logging in to Docker Hub as: $DockerUsername" -ForegroundColor Cyan
        docker login -u $DockerUsername
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Docker Hub login failed!" -ForegroundColor Red
            exit 1
        }
        Write-Host "Successfully logged in to Docker Hub" -ForegroundColor Green
    }


    Write-Host "`nPushing images to Docker Hub..." -ForegroundColor Cyan
    foreach ($image in $selectedImages) {
        Write-Host "Processing: $image" -ForegroundColor White

        # Parse repo and tag
        if ($image -match '^([^:]+):(.+)$') {
            $repoName = $matches[1]
            $tagName  = $matches[2]
        }
        else {
            $repoName = $image
            $tagName  = "latest"
        }

        $newImageName = "$DockerUsername/$($repoName):$tagName"
        Write-Host "  Tagging as: $newImageName" -ForegroundColor Gray

        docker tag $image $newImageName
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  Pushing to Docker Hub..." -ForegroundColor Gray
            docker push $newImageName
            if ($LASTEXITCODE -eq 0) {
                Write-Host "  Successfully pushed: $newImageName" -ForegroundColor Green
                $pushedCount++

                $pushedImageInfo += @{
                    original_image = $image
                    registry_image = $newImageName
                    local_name     = $repoName
                }
            }
            else {
                Write-Host "Failed to push $newImageName" -ForegroundColor Red
            }
        }
        else {
            Write-Host "Failed to tag $image as $newImageName" -ForegroundColor Red
        }
    }

    if ($pushedImageInfo.Count -gt 0) {
        Write-Host "`nCreating image registry information file..." -ForegroundColor Cyan
        $imageRegistryInfo = @{
            registry_type = "dockerhub"
            username      = $DockerUsername
            pushed_images = $pushedImageInfo
            timestamp     = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"
        }

        $imageInfoPath = Join-Path $migrationPath "image-registry-info.json"
        $imageRegistryInfo | ConvertTo-Json -Depth 10 | Set-Content -Path $imageInfoPath
        Write-Host "Image registry info saved to: image-registry-info.json" -ForegroundColor Green
    }
}

# ------------------------------
# 6. Aspirate output folder and state file
# ------------------------------
Write-Host ""
if (-not $AspirateOutputPath) {
    Write-Host "Please enter the full path to your aspirate-output folder" -ForegroundColor Cyan
    Write-Host "Example: C:\Users\You\source\repos\YourHost\aspirate-output" -ForegroundColor Gray
    $AspirateOutputPath = Read-Host "Path"
}
else {
    Write-Host "Using Aspirate output path from parameter: $AspirateOutputPath" -ForegroundColor Cyan
}

if (-not (Test-Path -Path $AspirateOutputPath)) {
    Write-Host "`nERROR: The specified path does not exist: $AspirateOutputPath" -ForegroundColor Red
    Write-Host "Please verify the path and run the script again." -ForegroundColor Yellow
    exit 1
}

# Copy aspirate-output directory
$manifestsPath = Join-Path $migrationPath "manifests"
Write-Host "`nCopying Aspirate manifests..." -ForegroundColor Cyan
Copy-Item -Path $AspirateOutputPath -Destination $manifestsPath -Recurse -Force

if (Test-Path -Path $manifestsPath) {
    Write-Host "Manifests copied successfully" -ForegroundColor Green
}

# Copy aspirate-state.json if it exists
$aspirateStateSource = Join-Path (Split-Path $AspirateOutputPath -Parent) "aspirate-state.json"
if (Test-Path -Path $aspirateStateSource) {
    Write-Host "Copying aspirate-state.json..." -ForegroundColor Cyan
    $aspirateStateDest = Join-Path $migrationPath "aspirate-state.json"
    Copy-Item -Path $aspirateStateSource -Destination $aspirateStateDest -Force
    Write-Host "aspirate-state.json copied successfully" -ForegroundColor Green
}
else {
    Write-Host "WARNING: aspirate-state.json not found at: $aspirateStateSource" -ForegroundColor Yellow
    Write-Host "Continuing without it..." -ForegroundColor Yellow
}

# Optional: update deployment YAMLs if we pushed images and have mapping
if ($ExportMethod -eq "push" -and $pushedCount -gt 0 -and $pushedImageInfo.Count -gt 0) {
    Write-Host "`nUpdating manifest files with Docker Hub image references..." -ForegroundColor Cyan

    $deploymentFiles = Get-ChildItem -Path $manifestsPath -Recurse -Filter "*deployment.yaml"
    $updatedCount = 0

    foreach ($deploymentFile in $deploymentFiles) {
        $fileContent = Get-Content -Path $deploymentFile.FullName -Raw
        $modified = $false

        foreach ($imageInfo in $pushedImageInfo) {
            $orig = $imageInfo.original_image
            $reg  = $imageInfo.registry_image

            if ($fileContent -match "image:\s+$([regex]::Escape($orig))") {
                $fileContent = $fileContent -replace "image:\s+$([regex]::Escape($orig))", "image: $reg"
                $modified = $true
            }
        }

        if ($modified) {
            Set-Content -Path $deploymentFile.FullName -Value $fileContent -NoNewline
            $updatedCount++
        }
    }

    Write-Host "Updated $updatedCount deployment file(s)" -ForegroundColor Green
}

# ------------------------------
# 7. Create zip
# ------------------------------
$zipPath = Join-Path $tempPath "aspire2kube.zip"

# Check if zip file already exists
if (Test-Path -Path $zipPath) {
    Write-Host "`nWARNING: ZIP file already exists: $zipPath" -ForegroundColor Yellow
    Write-Host "Do you want to override the existing ZIP file? (y/n)" -ForegroundColor Cyan
    $overrideZipChoice = Read-Host "Override"
    
    if ($overrideZipChoice -eq "n" -or $overrideZipChoice -eq "N") {
        # Rename existing zip to -old
        $oldZipPath = Join-Path $tempPath "aspire2kube-old.zip"
        
        # If -old already exists, remove it first
        if (Test-Path -Path $oldZipPath) {
            Write-Host "Removing previous old backup: aspire2kube-old.zip" -ForegroundColor Gray
            Remove-Item -Path $oldZipPath -Force
        }
        
        Write-Host "Renaming existing ZIP to: aspire2kube-old.zip" -ForegroundColor Green
        Rename-Item -Path $zipPath -NewName "aspire2kube-old.zip" -Force
    }
    else {
        Write-Host "Overriding existing ZIP file..." -ForegroundColor Yellow
        Remove-Item -Path $zipPath -Force
    }
}

Write-Host "`nCreating ZIP archive..." -ForegroundColor Cyan
Compress-Archive -Path $migrationPath\* -DestinationPath $zipPath -Force
Write-Host "ZIP archive: $zipPath" -ForegroundColor Cyan

if ($ExportMethod -eq "tar" -and $exportedCount -gt 0) {
    Write-Host "`nExported $exportedCount image(s) as tar files" -ForegroundColor White
}
elseif ($ExportMethod -eq "push" -and $pushedCount -gt 0) {
    Write-Host "`nPushed $pushedCount image(s) to Docker Hub" -ForegroundColor White
}

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Transfer the 'aspire2kube.zip' to your target environment" -ForegroundColor White

if ($ExportMethod -eq "tar" -and $exportedCount -gt 0) {
    Write-Host "2. Extract the ZIP and load Docker images using: docker load -i image-name.tar" -ForegroundColor White
    Write-Host "3. Deploy using the manifests in the manifests folder" -ForegroundColor White
}
elseif ($ExportMethod -eq "push" -and $pushedCount -gt 0) {
    Write-Host "2. Ensure your manifests point to the Docker Hub images ($DockerUsername/...)" -ForegroundColor White
    Write-Host "3. Deploy using the manifests in the manifests folder" -ForegroundColor White
}
else {
    Write-Host "2. Deploy using the manifests in the manifests folder" -ForegroundColor White
}

# ------------------------------
# 8. Optional: Transfer to server
# ------------------------------
Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "Would you like to transfer the ZIP file to your server now? (y/n)" -ForegroundColor Cyan
$transferChoice = Read-Host "Transfer"

if ($transferChoice -eq "y" -or $transferChoice -eq "Y") {
    # Check if transfer script exists in the same directory
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    $transferScriptPath = Join-Path $scriptDir "transfer-to-server.ps1"
    
    if (Test-Path -Path $transferScriptPath) {
        Write-Host "Launching transfer script..." -ForegroundColor Green
        & $transferScriptPath -ZipPath $zipPath
    }
    else {
        Write-Host "`nWARNING: transfer-to-server.ps1 not found in script directory!" -ForegroundColor Yellow
        Write-Host "Expected location: $transferScriptPath" -ForegroundColor Gray
        Write-Host "`nYou can manually transfer using:" -ForegroundColor Cyan
        Write-Host "  SCP: scp `"$zipPath`" user@server:/path/" -ForegroundColor White
        Write-Host "  Croc: croc send `"$zipPath`"" -ForegroundColor White
    }
}
else {
    Write-Host "`nSkipping transfer. You can manually transfer the file later." -ForegroundColor Yellow
    Write-Host "ZIP location: $zipPath" -ForegroundColor White
}

Write-Host "`nDone." -ForegroundColor Green