#!/usr/bin/env powershell

# Simple test orchestrator for ZippyCoin Agent Monitor
# This script simulates agent processes for testing purposes

param(
    [string]$LLMProvider = "ollama",
    [string]$LLMEndpoint = "http://localhost:11434",
    [string]$LLMApiKey = $null
)

Write-Host "Starting ZippyCoin Agent Orchestrator..."
Write-Host "LLM Provider: $LLMProvider"
Write-Host "LLM Endpoint: $LLMEndpoint"

# Define agents
$agents = @(
    "CoreBlockchain",
    "SDK", 
    "SmartContracts",
    "TestingQA",
    "TrustEngine"
)

# Create log directory if it doesn't exist
$logDir = "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force
}

# Function to simulate agent activity
function Start-AgentSimulation {
    param($AgentName)
    
    $logFile = "$logDir\${AgentName}_$(Get-Date -Format 'yyyy-MM-dd').log"
    
    # Create initial log entries
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$AgentName] Starting agent..." | Out-File -FilePath $logFile -Append
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$AgentName] Initializing connection to $LLMEndpoint..." | Out-File -FilePath $logFile -Append
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$AgentName] Agent ready and operational" | Out-File -FilePath $logFile -Append
    
    # Simulate ongoing activity
    $counter = 0
    while ($true) {
        $counter++
        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        
        # Different types of log messages
        $messages = @(
            "Processing task batch #$counter",
            "Analyzing data chunk $counter",
            "Communicating with LLM provider",
            "Updating internal state",
            "Completing transaction validation",
            "Synchronizing with peer nodes"
        )
        
        $randomMessage = $messages | Get-Random
        "$timestamp - [$AgentName] $randomMessage" | Out-File -FilePath $logFile -Append
        
        # Occasionally simulate being held/paused
        if ($counter % 20 -eq 0) {
            "$timestamp - [$AgentName] HELD - Waiting for user input" | Out-File -FilePath $logFile -Append
            Start-Sleep -Seconds 5
            "$timestamp - [$AgentName] Resuming operations" | Out-File -FilePath $logFile -Append
        }
        
        Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 8)
    }
}

# Start each agent in a background job
Write-Host "Starting agents in background processes..."
foreach ($agent in $agents) {
    Write-Host "Starting $agent..."
    Start-Job -Name "${agent}_script" -ScriptBlock {
        param($AgentName, $LogDir, $LLMEndpoint)
        
        $logFile = "$LogDir\${AgentName}_$(Get-Date -Format 'yyyy-MM-dd').log"
        
        # Create initial log entries
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$AgentName] Starting agent..." | Out-File -FilePath $logFile -Append
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$AgentName] Initializing connection to $LLMEndpoint..." | Out-File -FilePath $logFile -Append
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - [$AgentName] Agent ready and operational" | Out-File -FilePath $logFile -Append
        
        # Simulate ongoing activity
        $counter = 0
        while ($true) {
            $counter++
            $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            
            # Different types of log messages
            $messages = @(
                "Processing task batch #$counter",
                "Analyzing data chunk $counter", 
                "Communicating with LLM provider",
                "Updating internal state",
                "Completing transaction validation",
                "Synchronizing with peer nodes"
            )
            
            $randomMessage = $messages | Get-Random
            "$timestamp - [$AgentName] $randomMessage" | Out-File -FilePath $logFile -Append
            
            # Occasionally simulate being held/paused
            if ($counter % 20 -eq 0) {
                "$timestamp - [$AgentName] HELD - Waiting for user input" | Out-File -FilePath $logFile -Append
                Start-Sleep -Seconds 5
                "$timestamp - [$AgentName] Resuming operations" | Out-File -FilePath $logFile -Append
            }
            
            Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 8)
        }
    } -ArgumentList $agent, $logDir, $LLMEndpoint
}

Write-Host "All agents started successfully!"
Write-Host "Press Ctrl+C to stop all agents..."

# Keep the orchestrator running
try {
    while ($true) {
        $runningJobs = Get-Job | Where-Object { $_.State -eq "Running" }
        Write-Host "$(Get-Date -Format 'HH:mm:ss') - $($runningJobs.Count) agents running"
        Start-Sleep -Seconds 30
    }
} finally {
    Write-Host "Stopping all agents..."
    Get-Job | Stop-Job
    Get-Job | Remove-Job
    Write-Host "All agents stopped."
}
