# Start-Chroma.ps1
# PowerShell script to start ChromaDB server as a background process

[CmdletBinding()]
param(
    [string]$ChromaHost = "127.0.0.1",
    [int]$Port = 8000,
    [string]$PersistDir = ".\data\vector_db",
    [switch]$Force,
    [switch]$Status,
    [switch]$Stop,
    [switch]$Restart,
    [switch]$Logs
)

# Script configuration
$script:ChromaProcessName = "chroma_server"
$script:ChromaScriptPath = Join-Path $PSScriptRoot "chroma_server.py"
$script:VenvPath = Join-Path $PSScriptRoot "venv-chroma"
$script:PythonExe = Join-Path $script:VenvPath "Scripts\python.exe"
$script:LogDir = Join-Path $PSScriptRoot "logs"
$script:LogFile = Join-Path $script:LogDir "chroma_server.log"
$script:PidFile = Join-Path $PSScriptRoot "chroma_server.pid"

# Ensure log directory exists
if (-not (Test-Path $script:LogDir)) {
    New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
}

function Test-ChromaRunning {
    # Check if ChromaDB server is running
    try {
        $response = Invoke-RestMethod -Uri "http://$ChromaHost`:$Port/health" -Method GET -TimeoutSec 5
        return $true
    }
    catch {
        return $false
    }
}

function Get-ChromaProcess {
    # Get the ChromaDB server process
    $processes = Get-Process | Where-Object { $_.ProcessName -eq "python" -and $_.CommandLine -like "*chroma_server.py*" }
    return $processes
}

function Start-ChromaServer {
    # Start the ChromaDB server
    param(
        [string]$ServerHost = "127.0.0.1",
        [int]$ServerPort = 8000,
        [string]$ServerPersistDir = ".\data\vector_db"
    )
    
    Write-Host "Starting ChromaDB server..." -ForegroundColor Green
    
    # Check if already running
    if (Test-ChromaRunning) {
        Write-Host "ChromaDB server is already running on $ServerHost`:$ServerPort" -ForegroundColor Yellow
        return
    }
    
    # Check if Python virtual environment exists
    if (-not (Test-Path $script:PythonExe)) {
        Write-Error "Python virtual environment not found at: $script:VenvPath"
        Write-Host "Please run the following commands to create the virtual environment:"
        Write-Host "  python -m venv venv-chroma"
        Write-Host "  venv-chroma\Scripts\activate"
        Write-Host "  pip install chromadb fastapi uvicorn"
        return
    }
    
    # Check if server script exists
    if (-not (Test-Path $script:ChromaScriptPath)) {
        Write-Error "ChromaDB server script not found at: $script:ChromaScriptPath"
        return
    }
    
    # Resolve persist directory path
    $ServerPersistDir = Resolve-Path $ServerPersistDir -ErrorAction SilentlyContinue
    if (-not $ServerPersistDir) {
        $ServerPersistDir = Join-Path $PSScriptRoot "data\vector_db"
        New-Item -ItemType Directory -Path $ServerPersistDir -Force | Out-Null
    }
    
    # Build command arguments
    $args = @(
        $script:ChromaScriptPath,
        "--host", $ServerHost,
        "--port", $ServerPort,
        "--persist-dir", $ServerPersistDir
    )
    
    # Start the process
    try {
        $processStartInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processStartInfo.FileName = $script:PythonExe
        $processStartInfo.Arguments = $args -join " "
        $processStartInfo.UseShellExecute = $false
        $processStartInfo.RedirectStandardOutput = $true
        $processStartInfo.RedirectStandardError = $true
        $processStartInfo.CreateNoWindow = $true
        $processStartInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
        
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processStartInfo
        
        # Set up logging
        $process.add_OutputDataReceived({
            param($sender, $e)
            if ($e.Data) {
                Add-Content -Path $script:LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [OUT] $($e.Data)"
            }
        })
        
        $process.add_ErrorDataReceived({
            param($sender, $e)
            if ($e.Data) {
                Add-Content -Path $script:LogFile -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [ERR] $($e.Data)"
            }
        })
        
        $process.Start() | Out-Null
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        
        # Save process ID
        $process.Id | Out-File -FilePath $script:PidFile -Force
        
        # Wait a moment and check if server started successfully
        Start-Sleep -Seconds 3
        
        if (Test-ChromaRunning) {
            Write-Host "ChromaDB server started successfully!" -ForegroundColor Green
            Write-Host "  Server: http://$ServerHost`:$ServerPort" -ForegroundColor Cyan
            Write-Host "  Logs: $script:LogFile" -ForegroundColor Cyan
            Write-Host "  PID: $($process.Id)" -ForegroundColor Cyan
        }
        else {
            Write-Error "ChromaDB server failed to start. Check logs: $script:LogFile"
        }
    }
    catch {
        Write-Error "Failed to start ChromaDB server: $($_.Exception.Message)"
    }
}

function Stop-ChromaServer {
    # Stop the ChromaDB server
    Write-Host "Stopping ChromaDB server..." -ForegroundColor Yellow
    
    $stopped = $false
    
    # Try to stop via PID file
    if (Test-Path $script:PidFile) {
        try {
            $pid = Get-Content $script:PidFile
            $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($process) {
                Stop-Process -Id $pid -Force
                $stopped = $true
                Write-Host "ChromaDB server stopped (PID: $pid)" -ForegroundColor Green
            }
        }
        catch {
            Write-Warning "Could not stop process using PID file: $($_.Exception.Message)"
        }
        finally {
            Remove-Item $script:PidFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    # Try to find and stop Python processes running chroma_server.py
    $processes = Get-ChromaProcess
    foreach ($process in $processes) {
        try {
            Stop-Process -Id $process.Id -Force
            $stopped = $true
            Write-Host "ChromaDB server stopped (PID: $($process.Id))" -ForegroundColor Green
        }
        catch {
            Write-Warning "Could not stop process $($process.Id): $($_.Exception.Message)"
        }
    }
    
    if (-not $stopped) {
        Write-Host "No ChromaDB server processes found to stop" -ForegroundColor Yellow
    }
}

function Show-ChromaStatus {
    # Show the status of ChromaDB server
    Write-Host "ChromaDB Server Status:" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    
    $isRunning = Test-ChromaRunning
    $processes = Get-ChromaProcess
    
    Write-Host "Service Status: " -NoNewline
    if ($isRunning) {
        Write-Host "RUNNING" -ForegroundColor Green
        Write-Host "Server URL: http://$ChromaHost`:$Port" -ForegroundColor Cyan
    }
    else {
        Write-Host "STOPPED" -ForegroundColor Red
    }
    
    Write-Host "Processes: " -NoNewline
    if ($processes.Count -gt 0) {
        Write-Host "$($processes.Count) process(es) found" -ForegroundColor Yellow
        foreach ($process in $processes) {
            Write-Host "  PID: $($process.Id), Start: $($process.StartTime)" -ForegroundColor Yellow
        }
    }
    else {
        Write-Host "No processes found" -ForegroundColor Red
    }
    
    Write-Host "Log File: $script:LogFile"
    Write-Host "PID File: $script:PidFile"
    Write-Host "Python Exe: $script:PythonExe"
}

function Show-ChromaLogs {
    # Show recent ChromaDB server logs
    if (Test-Path $script:LogFile) {
        Write-Host "Recent ChromaDB Server Logs:" -ForegroundColor Cyan
        Write-Host "=============================" -ForegroundColor Cyan
        Get-Content $script:LogFile -Tail 20
    }
    else {
        Write-Host "No log file found at: $script:LogFile" -ForegroundColor Yellow
    }
}

function Test-ChromaHealth {
    # Test ChromaDB server health and show details
    try {
        $response = Invoke-RestMethod -Uri "http://$ChromaHost`:$Port/health" -Method GET -TimeoutSec 5
        Write-Host "ChromaDB Server Health Check:" -ForegroundColor Green
        Write-Host "============================" -ForegroundColor Green
        Write-Host "Status: $($response.status)"
        Write-Host "Persist Dir: $($response.persist_dir)"
        
        # Get collections info
        try {
            $collections = Invoke-RestMethod -Uri "http://$ChromaHost`:$Port/collections" -Method GET -TimeoutSec 5
            Write-Host "Collections: $($collections.Count)"
            foreach ($collection in $collections) {
                Write-Host "  - $($collection.name): $($collection.count) documents"
            }
        }
        catch {
            Write-Warning "Could not retrieve collections info: $($_.Exception.Message)"
        }
        
        return $true
    }
    catch {
        Write-Host "ChromaDB Server Health Check: FAILED" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main script logic
switch ($true) {
    $Status {
        Show-ChromaStatus
        Test-ChromaHealth
    }
    $Stop {
        Stop-ChromaServer
    }
    $Restart {
        Stop-ChromaServer
        Start-Sleep -Seconds 2
        Start-ChromaServer -ServerHost $ChromaHost -ServerPort $Port -ServerPersistDir $PersistDir
    }
    $Logs {
        Show-ChromaLogs
    }
    default {
        # Default action is to start the server
        if ($Force -or -not (Test-ChromaRunning)) {
            if ($Force) {
                Stop-ChromaServer
                Start-Sleep -Seconds 2
            }
            Start-ChromaServer -ServerHost $ChromaHost -ServerPort $Port -ServerPersistDir $PersistDir
        }
        else {
            Write-Host "ChromaDB server is already running. Use -Force to restart or -Status to check status." -ForegroundColor Yellow
        }
    }
}
