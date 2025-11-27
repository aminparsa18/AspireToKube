<#
.SYNOPSIS
  Transfer aspire2kube.zip to remote server

.DESCRIPTION
  Transfers the migration package to a remote server using either SCP or Croc

.PARAMETER ZipPath
  Path to the aspire2kube.zip file

.PARAMETER TransferMethod
  "scp" or "croc"

.PARAMETER ServerAddress
  SSH server address (e.g., root@84.32.22.116) - only for SCP method

.PARAMETER RemotePath
  Remote destination path - only for SCP method (default: /root/)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ZipPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet("scp", "croc")]
    [string]$TransferMethod,

    [Parameter(Mandatory = $false)]
    [string]$ServerAddress,

    [Parameter(Mandatory = $false)]
    [string]$RemotePath = "/root/"
)

Write-Host "`n================================================" -ForegroundColor Cyan
Write-Host "  File Transfer to Remote Server" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Verify the zip file exists
if (-not (Test-Path -Path $ZipPath)) {
    Write-Host "ERROR: ZIP file not found: $ZipPath" -ForegroundColor Red
    exit 1
}

$fileSize = (Get-Item $ZipPath).Length / 1MB
Write-Host "File to transfer: $ZipPath" -ForegroundColor White
Write-Host "File size: $([math]::Round($fileSize, 2)) MB" -ForegroundColor White
Write-Host ""

# Choose transfer method if not specified
if (-not $TransferMethod) {
    Write-Host "Choose transfer method:" -ForegroundColor Cyan
    Write-Host "  [1] SCP (SSH) - Direct transfer to server" -ForegroundColor White
    Write-Host "  [2] Croc - Peer-to-peer transfer with code" -ForegroundColor White
    Write-Host ""
    
    $validChoice = $false
    do {
        $methodChoice = Read-Host "Enter choice (1 or 2)"
        
        switch ($methodChoice) {
            "1" { 
                $TransferMethod = "scp"
                $validChoice = $true
            }
            "2" { 
                $TransferMethod = "croc"
                $validChoice = $true
            }
            default { 
                Write-Host "Invalid choice. Please enter 1 or 2." -ForegroundColor Yellow
                $validChoice = $false
            }
        }
    } while (-not $validChoice)
}

# ------------------------------
# SCP Transfer Method
# ------------------------------
if ($TransferMethod -eq "scp") {
    Write-Host "`n--- SCP Transfer Method ---" -ForegroundColor Cyan
    
    # Check if SCP is available
    try {
        $scpTest = Get-Command scp -ErrorAction Stop
    }
    catch {
        Write-Host "ERROR: SCP command not found!" -ForegroundColor Red
        Write-Host "Please install OpenSSH Client:" -ForegroundColor Yellow
        Write-Host "  Windows: Settings > Apps > Optional Features > Add OpenSSH Client" -ForegroundColor White
        Write-Host "  Or download from: https://github.com/PowerShell/Win32-OpenSSH/releases" -ForegroundColor White
        exit 1
    }
    
    # Get server address if not provided
    if (-not $ServerAddress) {
        Write-Host "`nEnter SSH server address (e.g., root@84.32.22.116):" -ForegroundColor Cyan
        $ServerAddress = Read-Host "Server"
        
        if ([string]::IsNullOrWhiteSpace($ServerAddress)) {
            Write-Host "ERROR: Server address is required!" -ForegroundColor Red
            exit 1
        }
    }
    
    # Get remote path if user wants to customize
    Write-Host "`nRemote destination path (press Enter for default: $RemotePath):" -ForegroundColor Cyan
    $customPath = Read-Host "Remote path"
    if (-not [string]::IsNullOrWhiteSpace($customPath)) {
        $RemotePath = $customPath
    }
    
    # Ensure remote path ends with /
    if (-not $RemotePath.EndsWith("/")) {
        $RemotePath += "/"
    }
    
    Write-Host "`nTransferring file to $ServerAddress`:$RemotePath..." -ForegroundColor Cyan
    Write-Host "You may be prompted for SSH password..." -ForegroundColor Yellow
    Write-Host ""
    
    # Execute SCP command
    $scpCommand = "scp `"$ZipPath`" ${ServerAddress}:${RemotePath}"
    Write-Host "Executing: $scpCommand" -ForegroundColor Gray
    
    & scp "$ZipPath" "${ServerAddress}:${RemotePath}"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nFile transferred successfully!" -ForegroundColor Green
        Write-Host "Location on server: ${RemotePath}aspire2kube.zip" -ForegroundColor White
        Write-Host "`nNext steps on your server:" -ForegroundColor Yellow
        Write-Host "  1. SSH into your server: ssh $ServerAddress" -ForegroundColor White
        Write-Host "  2. Extract: unzip ${RemotePath}aspire2kube.zip -d /opt/aspire-deployment" -ForegroundColor White
        Write-Host "  3. Navigate to deployment folder and apply manifests" -ForegroundColor White
    }
    else {
        Write-Host "`nERROR: File transfer failed!" -ForegroundColor Red
        Write-Host "Please check:" -ForegroundColor Yellow
        Write-Host "  - Server address is correct" -ForegroundColor White
        Write-Host "  - You have SSH access to the server" -ForegroundColor White
        Write-Host "  - Network connectivity is working" -ForegroundColor White
        exit 1
    }
}

# ------------------------------
# Croc Transfer Method
# ------------------------------
elseif ($TransferMethod -eq "croc") {
    Write-Host "`n--- Croc Transfer Method ---" -ForegroundColor Cyan
    
    # Check if Croc is installed
    try {
        $crocTest = Get-Command croc -ErrorAction Stop
        $crocVersion = croc --version 2>&1
        Write-Host "Croc is installed: $crocVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "WARNING: Croc is not installed!" -ForegroundColor Yellow
        Write-Host "`nCroc is a tool for simple and secure file transfers between computers." -ForegroundColor White
        Write-Host "Installation options:" -ForegroundColor Cyan
        Write-Host "  1. Windows (PowerShell): " -ForegroundColor White
        Write-Host "     iwr https://getcroc.schollz.com/install.ps1 -useb | iex" -ForegroundColor Gray
        Write-Host "  2. Windows (Scoop): scoop install croc" -ForegroundColor White
        Write-Host "  3. Windows (Chocolatey): choco install croc" -ForegroundColor White
        Write-Host "  4. Download from: https://github.com/schollz/croc/releases" -ForegroundColor White
        Write-Host ""
        Write-Host "Would you like to install Croc now? (y/n)" -ForegroundColor Cyan
        $installChoice = Read-Host "Install"
        
        if ($installChoice -eq "y" -or $installChoice -eq "Y") {
            Write-Host "`nInstalling Croc..." -ForegroundColor Cyan
            try {
                Invoke-Expression (Invoke-WebRequest -Uri "https://getcroc.schollz.com/install.ps1" -UseBasicParsing).Content
                Write-Host "Croc installed successfully!" -ForegroundColor Green
            }
            catch {
                Write-Host "ERROR: Failed to install Croc automatically" -ForegroundColor Red
                Write-Host "Please install manually and run this script again." -ForegroundColor Yellow
                exit 1
            }
        }
        else {
            Write-Host "Please install Croc and run this script again." -ForegroundColor Yellow
            exit 1
        }
    }
    
    Write-Host "`nStarting Croc transfer..." -ForegroundColor Cyan
    Write-Host "A transfer code will be generated. Share this code with the receiving machine." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "On your Linux server, run:" -ForegroundColor Cyan
    Write-Host "  croc <code-shown-below>" -ForegroundColor White
    Write-Host ""
    
    # Start croc send
    croc send "$ZipPath"
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`nFile transferred successfully!" -ForegroundColor Green
        Write-Host "`nNext steps on your server:" -ForegroundColor Yellow
        Write-Host "  1. Extract: unzip aspire2kube.zip -d /opt/aspire-deployment" -ForegroundColor White
        Write-Host "  2. Navigate to deployment folder and apply manifests" -ForegroundColor White
    }
    else {
        Write-Host "`nTransfer was cancelled or failed." -ForegroundColor Yellow
    }
}

Write-Host "`nTransfer process complete." -ForegroundColor Cyan