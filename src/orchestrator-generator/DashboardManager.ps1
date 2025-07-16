# Register orchestrators and provide management capabilities

[CmdletBinding()]
param(
    [string]$DashboardPath = "$PSScriptRoot/dashboard-registry.json"
)

function Register-Orchestrator {
    param(
        [string]$Name,
        [string]$Path,
        [hashtable]$Metadata
    )
    
    $registry = @{
        "orchestrators" = @()
        "last_updated" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    if (Test-Path $DashboardPath) {
        $registry = Get-Content -Path $DashboardPath -Raw | ConvertFrom-Json -AsHashtable
    }
    
    $registry.orchestrators += @{
        "name" = $Name
        "path" = $Path
        "metadata" = $Metadata
    }
    
    $registry.last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    $registryJson = $registry | ConvertTo-Json -Depth 10
    Set-Content -Path $DashboardPath -Value $registryJson -Encoding UTF8
    
    Write-Host "📊 Registered orchestrator: $Name in dashboard"
}

function Get-Orchestrators {
    if (-not (Test-Path $DashboardPath)) {
        Write-Warning "Dashboard register file not found: $DashboardPath"
        return @()
    }
    
    $registry = Get-Content -Path $DashboardPath -Raw | ConvertFrom-Json -AsHashtable
    return $registry.orchestrators
}

function Edit-Orchestrator {
    param(
        [string]$Name,
        [hashtable]$NewMetadata
    )
    
    if (-not (Test-Path $DashboardPath)) {
        Write-Warning "Dashboard register file not found: $DashboardPath"
        return
    }
    
    $registry = Get-Content -Path $DashboardPath -Raw | ConvertFrom-Json -AsHashtable
    
    $orchestrator = $registry.orchestrators | Where-Object { $_.name -eq $Name }
    if (-not $orchestrator) {
        Write-Warning "Orchestrator not found: $Name"
        return
    }
    
    # Update orchestrator metadata
    foreach ($key in $NewMetadata.Keys) {
        $orchestrator.metadata.$key = $NewMetadata[$key]
    }
    
    $registryJson = $registry | ConvertTo-Json -Depth 10
    Set-Content -Path $DashboardPath -Value $registryJson -Encoding UTF8
    
    Write-Host "✏️ Edited orchestrator: $Name in dashboard"
}

function Run-Orchestrator {
    param(
        [string]$Name
    )
    
    if (-not (Test-Path $DashboardPath)) {
        Write-Warning "Dashboard register file not found: $DashboardPath"
        return
    }
    
    $registry = Get-Content -Path $DashboardPath -Raw | ConvertFrom-Json -AsHashtable
    
    $orchestrator = $registry.orchestrators | Where-Object { $_.name -eq $Name }
    if (-not $orchestrator) {
        Write-Warning "Orchestrator not found: $Name"
        return
    }
    
    $scriptPath = Join-Path $orchestrator.path "tasks.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Warning "Orchestrator script not found: $scriptPath"
        return
    }
    
    Invoke-Expression -Command "& '$scriptPath'"
    Write-Host "🚀 Running orchestrator: $Name"
}
