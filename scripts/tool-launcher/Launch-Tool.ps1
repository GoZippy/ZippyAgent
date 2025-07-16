#!/usr/bin/env powershell
<#
.SYNOPSIS
    Launch any tool defined in tools.json
.DESCRIPTION
    Generic launcher that reads tools.json and launches the specified tool
.PARAMETER ToolName
    Name of the tool to launch (as defined in tools.json)
.PARAMETER Arguments
    Additional arguments to pass to the tool
.PARAMETER ProjectPath
    Optional project path for applicable tools
.EXAMPLE
    .\Launch-Tool.ps1 -ToolName "cursor" -ProjectPath "C:\Projects\MyProject"
    .\Launch-Tool.ps1 -ToolName "bolt"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$ToolName,
    [string]$ProjectPath = "",
    [string[]]$Arguments = @()
)

$ErrorActionPreference = "Stop"

# Get the script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ToolsConfigPath = Join-Path $RootDir "tools.json"

if (-not (Test-Path $ToolsConfigPath)) {
    Write-Error "Tools configuration not found at: $ToolsConfigPath"
    exit 1
}

try {
    $ToolsConfig = Get-Content $ToolsConfigPath -Raw | ConvertFrom-Json
} catch {
    Write-Error "Failed to parse tools configuration: $($_.Exception.Message)"
    exit 1
}

if (-not $ToolsConfig.tools.$ToolName) {
    Write-Error "Tool '$ToolName' not found in configuration. Available tools: $($ToolsConfig.tools.PSObject.Properties.Name -join ', ')"
    exit 1
}

$Tool = $ToolsConfig.tools.$ToolName

# Determine the platform
$Platform = "windows"
if ($IsMacOS) {
    $Platform = "macos"
} elseif ($IsLinux) {
    $Platform = "linux"
}

Write-Host "Launching $($Tool.name)..." -ForegroundColor Green

# Handle web-based tools
if ($Tool.url) {
    try {
        Start-Process $Tool.url
        Write-Host "$($Tool.name) launched successfully in default browser!" -ForegroundColor Green
        return
    } catch {
        Write-Error "Failed to launch $($Tool.name): $($_.Exception.Message)"
        exit 1
    }
}

# Handle desktop applications
$ExecutableName = $Tool.executable.$Platform
if (-not $ExecutableName) {
    Write-Error "No executable defined for platform: $Platform"
    exit 1
}

# Find the executable
$ExecutablePath = $null

# Check install paths
if ($Tool.install_paths.$Platform) {
    foreach ($path in $Tool.install_paths.$Platform) {
        # Expand environment variables
        $expandedPath = [System.Environment]::ExpandEnvironmentVariables($path)
        if (Test-Path $expandedPath) {
            $ExecutablePath = $expandedPath
            break
        }
    }
}

# Try to find in PATH
if (-not $ExecutablePath) {
    try {
        $cmd = Get-Command $ExecutableName -ErrorAction Stop
        $ExecutablePath = $cmd.Source
    } catch {
        # Not in PATH
    }
}

if (-not $ExecutablePath) {
    Write-Error "$($Tool.name) not found. Please install it or check the configuration."
    exit 1
}

# Build arguments
$LaunchArgs = @()
if ($Tool.launch_args) {
    $LaunchArgs += $Tool.launch_args
}
if ($ProjectPath -and (Test-Path $ProjectPath)) {
    $LaunchArgs += $ProjectPath
}
$LaunchArgs += $Arguments

try {
    Write-Host "Executable: $ExecutablePath" -ForegroundColor Cyan
    if ($LaunchArgs.Count -gt 0) {
        Write-Host "Arguments: $($LaunchArgs -join ' ')" -ForegroundColor Cyan
        Start-Process -FilePath $ExecutablePath -ArgumentList $LaunchArgs -WindowStyle Normal
    } else {
        Start-Process -FilePath $ExecutablePath -WindowStyle Normal
    }
    Write-Host "$($Tool.name) launched successfully!" -ForegroundColor Green
} catch {
    Write-Error "Failed to launch $($Tool.name): $($_.Exception.Message)"
    exit 1
}
