#!/usr/bin/env powershell
<#
.SYNOPSIS
    Launch Warp AI terminal
.DESCRIPTION
    Finds and launches Warp terminal with optional arguments
.PARAMETER WorkingDirectory
    Optional working directory to start in
.PARAMETER Arguments
    Additional arguments to pass to Warp
.EXAMPLE
    .\Launch-Warp.ps1 -WorkingDirectory "C:\Projects\MyProject"
#>

param(
    [string]$WorkingDirectory = "",
    [string[]]$Arguments = @()
)

$ErrorActionPreference = "Stop"

# Common installation paths for Warp
$WarpPaths = @(
    "$env:LOCALAPPDATA\warp\warp.exe",
    "$env:PROGRAMFILES\Warp\warp.exe",
    "$env:PROGRAMFILES(X86)\Warp\warp.exe"
)

# Find Warp executable
$WarpExe = $null
foreach ($path in $WarpPaths) {
    if (Test-Path $path) {
        $WarpExe = $path
        break
    }
}

# Try to find in PATH
if (-not $WarpExe) {
    try {
        $WarpExe = (Get-Command warp -ErrorAction Stop).Source
    } catch {
        # Not in PATH
    }
}

if (-not $WarpExe) {
    Write-Warning "Warp not found. Attempting to download and install..."
    
    # Check if we can use winget
    try {
        $winget = Get-Command winget -ErrorAction Stop
        Write-Host "Installing Warp via winget..." -ForegroundColor Yellow
        & winget install --id=Warp.Warp --silent
        
        # Try to find it again after installation
        foreach ($path in $WarpPaths) {
            if (Test-Path $path) {
                $WarpExe = $path
                break
            }
        }
    } catch {
        Write-Error "Warp not found and cannot be installed automatically. Please install Warp from https://www.warp.dev/"
        exit 1
    }
    
    if (-not $WarpExe) {
        Write-Error "Warp installation failed. Please install manually from https://www.warp.dev/"
        exit 1
    }
}

# Build arguments
$LaunchArgs = @()
if ($WorkingDirectory -and (Test-Path $WorkingDirectory)) {
    $LaunchArgs += "--working-directory", $WorkingDirectory
}
$LaunchArgs += $Arguments

try {
    Write-Host "Launching Warp..." -ForegroundColor Green
    if ($LaunchArgs.Count -gt 0) {
        Write-Host "Arguments: $($LaunchArgs -join ' ')" -ForegroundColor Cyan
        Start-Process -FilePath $WarpExe -ArgumentList $LaunchArgs -WindowStyle Normal
    } else {
        Start-Process -FilePath $WarpExe -WindowStyle Normal
    }
    Write-Host "Warp launched successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to launch Warp: $($_.Exception.Message)"
    exit 1
}
