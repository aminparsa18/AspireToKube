<#
.SYNOPSIS
  Aspire Project Migration Preparation Script

.DESCRIPTION
  Exports or pushes selected Docker images and copies Aspirate output
  into a migration folder (zip ready to move to another environment).

.PARAMETER ExportMethod
  "push" | "tar" | "skip"
  If not supplied, user is prompted:
    [1] Push to Docker Hub (DEFAULT)
    [2] Export as tar files
    [3] Skip

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
    [ValidateSet("push", "tar", "skip")]
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
$tempPath = "C:\Temp"
if (-not (Test-Path -Path $tempPath)) {
    Write-Host "Creating temp directory: $tempPath" -ForegroundColor Green
    New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
}

$migrationPath = Join-Path $tempPath "Aspire-Migration"
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
# 4. Choose Export Method (push/tar/skip)
# ------------------------------
if (-not $ExportMethod) {
    # Interactive: default is PUSH
    Write-Host "`nHow would you like to handle the selected images?" -ForegroundColor Cyan
    Write-Host "  [1] Push to Docker Hub (DEFAULT)" -ForegroundColor White
    Write-Host "  [2] Export as tar files" -ForegroundColor White
    Write-Host "  [3] Skip image export/push (manifests only)" -ForegroundColor White
    Write-Host ""
    $exportChoice = Read-Host "Enter choice (1, 2, or 3, default 1)"

    switch ($exportChoice) {
        "2" { $ExportMethod = "tar" }
        "3" { $ExportMethod = "skip" }
        default { $ExportMethod = "push" }
    }

    Write-Host "Using export method: $ExportMethod" -ForegroundColor Cyan
}

if ($selectedImages.Count -eq 0) {
    # If there are no images, we always skip any image work
    $ExportMethod = "skip"
}

$exportedCount = 0
$pushedCount  = 0
$pushedImageInfo = @()

if ($selectedImages.Count -gt 0 -and $ExportMethod -ne "skip") {

    if ($ExportMethod -eq "tar") {
        # ---------------- TAR EXPORT ----------------
        Write-Host "`nExporting $($selectedImages.Count) Docker image(s) as tar files..." -ForegroundColor Cyan
        Write-Host "This may take a few minutes depending on image sizes.`n" -ForegroundColor Yellow

        foreach ($image in $selectedImages) {
            $repoOnly = ($image -split ':')[0]
            $fileName = $repoOnly -replace '[\\/]', '_'
            $fileName = "$fileName.tar"

            Write-Host "Exporting $image -> $fileName" -ForegroundColor White
            docker save -o $fileName $image

            if ($LASTEXITCODE -eq 0 -and (Test-Path -Path $fileName)) {
                Write-Host "Exported $image -> $fileName" -ForegroundColor Green
                $exportedCount++
            }
            else {
                Write-Host "Failed to export $image" -ForegroundColor Red
            }
        }

        Write-Host "`nVerifying exported images:" -ForegroundColor Cyan
        $totalSize = 0
        $tarFiles = Get-ChildItem -Path $migrationPath -Filter "*.tar"
        foreach ($file in $tarFiles) {
            $sizeInMB = [math]::Round($file.Length / 1MB, 2)
            $totalSize += $sizeInMB
            Write-Host "  $($file.Name) - $sizeInMB MB" -ForegroundColor White
        }
        Write-Host "Total size: $([math]::Round($totalSize, 2)) MB" -ForegroundColor Cyan
    }
    elseif ($ExportMethod -eq "push") {
        # ---------------- PUSH TO DOCKER HUB ----------------
        Write-Host "`nPreparing to push $($selectedImages.Count) image(s) to Docker Hub..." -ForegroundColor Cyan
        Write-Host ""

        if (-not $DockerUsername) {
            Write-Host "Enter your Docker Hub username (NOT email):" -ForegroundColor Cyan
            Write-Host "Example: myusername" -ForegroundColor Gray
            $DockerUsername = Read-Host "Username"
        }

        if ([string]::IsNullOrWhiteSpace($DockerUsername)) {
            Write-Host "ERROR: Docker Hub username is required!" -ForegroundColor Red
            exit 1
        }

        if ($DockerUsername -match '[^a-z0-9_-]') {
            Write-Host "ERROR: Invalid Docker Hub username format!" -ForegroundColor Red
            Write-Host "Docker Hub usernames can only contain lowercase letters, numbers, hyphens, and underscores." -ForegroundColor Yellow
            Write-Host "Please use your Docker Hub username (e.g., 'xracer007'), not your email address." -ForegroundColor Yellow
            exit 1
        }

        Write-Host "`nChecking Docker Hub authentication..." -ForegroundColor Cyan
        $dockerInfo = docker info 2>$null | Select-String "Username"

        if (-not $dockerInfo) {
            Write-Host "You are not logged in to Docker Hub." -ForegroundColor Yellow
            Write-Host "Please log in to Docker Hub:" -ForegroundColor Cyan
            docker login

            if ($LASTEXITCODE -ne 0) {
                Write-Host "ERROR: Docker Hub login failed!" -ForegroundColor Red
                exit 1
            }
        }
        else {
            Write-Host "Already logged in to Docker Hub" -ForegroundColor Green
        }

        $pushedImageInfo = @()

        foreach ($image in $selectedImages) {
            Write-Host "`nProcessing image: $image" -ForegroundColor White

            # If image already contains a '/' assume fully-qualified (user/repo:tag)
            if ($image -like "*/*") {
                Write-Host "Image appears to already have a registry/user prefix. Pushing as-is..." -ForegroundColor Yellow
                docker push $image

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully pushed $image" -ForegroundColor Green
                    $pushedCount++

                    $imageParts  = $image -split '/'
                    $repoAndTag  = $imageParts[-1]
                    $repoParts   = $repoAndTag -split ':'
                    $repoName    = $repoParts[0]

                    $pushedImageInfo += @{
                        original_image = $image
                        registry_image = $image
                        local_name     = $repoName
                    }
                }
                else {
                    Write-Host "Failed to push $image" -ForegroundColor Red
                }
                continue
            }

            # No prefix: construct dockerhub username/image:tag
            $imageParts = $image -split ':'
            $repoName   = $imageParts[0]
            $tag        = if ($imageParts.Count -gt 1) { $imageParts[1] } else { "latest" }

            $newImageName = "$DockerUsername/$repoName`:$tag"

            Write-Host "Tagging $image as $newImageName..." -ForegroundColor White
            docker tag $image $newImageName

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Pushing $newImageName..." -ForegroundColor White
                docker push $newImageName

                if ($LASTEXITCODE -eq 0) {
                    Write-Host "Successfully pushed $newImageName" -ForegroundColor Green
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
}
elseif ($ExportMethod -eq "skip") {
    Write-Host "`nSkipping image export/push as requested." -ForegroundColor Yellow
}

# ------------------------------
# 5. Aspirate output folder
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

$manifestsPath = Join-Path $migrationPath "manifests"
Write-Host "`nCopying Aspirate manifests..." -ForegroundColor Cyan
Copy-Item -Path $AspirateOutputPath -Destination $manifestsPath -Recurse -Force

if (Test-Path -Path $manifestsPath) {
    Write-Host "Manifests copied successfully" -ForegroundColor Green
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
# 6. Create zip
# ------------------------------
$zipPath = Join-Path $tempPath "aspire2kube.zip"
if (Test-Path -Path $zipPath) {
    Remove-Item -Path $zipPath -Force
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

Write-Host "`nDone." -ForegroundColor Green
