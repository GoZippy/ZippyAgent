#!/usr/bin/env powershell
<#
.SYNOPSIS
    Launch Bolt.new in default browser
.DESCRIPTION
    Opens Bolt.new AI-powered web development platform in the default browser
.PARAMETER Url
    Optional specific URL to open (defaults to https://bolt.new)
.PARAMETER Arguments
    Additional arguments (not used for web launcher)
.EXAMPLE
    .\Launch-Bolt.ps1
    .\Launch-Bolt.ps1 -Url "https://bolt.new/some-project"
#>

param(
    [string]$Url = "https://bolt.new",
    [string[]]$Arguments = @()
)

$ErrorActionPreference = "Stop"

try {
    Write-Host "Launching Bolt.new..." -ForegroundColor Green
    Write-Host "URL: $Url" -ForegroundColor Cyan
    
    # Use Start-Process to open URL in default browser
    Start-Process $Url
    
    Write-Host "Bolt.new launched successfully in default browser!" -ForegroundColor Green
} catch {
    Write-Error "Failed to launch Bolt.new: $($_.Exception.Message)"
    exit 1
}
