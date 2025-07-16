#!/usr/bin/env powershell
<#
.SYNOPSIS
    Launch Cursor AI-powered code editor
.DESCRIPTION
    Finds and launches Cursor editor with optional arguments
.PARAMETER ProjectPath
    Optional path to project directory to open
.PARAMETER Arguments
    Additional arguments to pass to Cursor
.EXAMPLE
    .\Launch-Cursor.ps1 -ProjectPath "C:\Projects\MyProject"
#>

param(
    [string]$ProjectPath = "",
    [string[]]$Arguments = @()
)

$ErrorActionPreference = "Stop"

# Common installation paths for Cursor
$CursorPaths = @(
    "$env:LOCALAPPDATA\Programs\cursor\cursor.exe",
    "$env:PROGRAMFILES\Cursor\cursor.exe",
    "$env:PROGRAMFILES(X86)\Cursor\cursor.exe"
)

# Find Cursor executable
$CursorExe = $null
foreach ($path in $CursorPaths) {
    if (Test-Path $path) {
        $CursorExe = $path
        break
    }
}

# Try to find in PATH
if (-not $CursorExe) {
    try {
        $CursorExe = (Get-Command cursor -ErrorAction Stop).Source
    } catch {
        # Not in PATH
    }
}

if (-not $CursorExe) {
    Write-Error "Cursor not found. Please install Cursor from https://cursor.sh/"
    exit 1
}

# Build arguments
$LaunchArgs = @()
if ($ProjectPath -and (Test-Path $ProjectPath)) {
    $LaunchArgs += $ProjectPath
}
$LaunchArgs += $Arguments

try {
    Write-Host "Launching Cursor..." -ForegroundColor Green
    if ($LaunchArgs.Count -gt 0) {
        Write-Host "Arguments: $($LaunchArgs -join ' ')" -ForegroundColor Cyan
        Start-Process -FilePath $CursorExe -ArgumentList $LaunchArgs -WindowStyle Normal
    } else {
        Start-Process -FilePath $CursorExe -WindowStyle Normal
    }
    Write-Host "Cursor launched successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to launch Cursor: $($_.Exception.Message)"
    exit 1
}
