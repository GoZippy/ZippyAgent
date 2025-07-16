# Dynamic Orchestrator Generation System
# ZippyAgent Platform - Step 5 Implementation

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Mode = "interactive",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = "",
    
    [Parameter(Mandatory = $false)]
    [string]$LLMProvider = "ollama",
    
    [Parameter(Mandatory = $false)]
    [string]$LLMEndpoint = "http://localhost:11434"
)

# Import required modules
Import-Module "$PSScriptRoot\..\ZippyAgent\Zippy.RepoHarvest.psm1" -Force
Import-Module "$PSScriptRoot\..\ZippyAgent\Zippy.Config.psm1" -Force -ErrorAction SilentlyContinue

# Define the orchestrator generation class
class OrchestratorGenerator {
    [string]$WorkingDirectory
    [string]$TemplatesPath
    [string]$GeneratedPath
    [string]$LLMProvider
    [string]$LLMEndpoint
    [hashtable]$RepoPatterns
    [hashtable]$UserIntent
    
    OrchestratorGenerator([string]$workingDir, [string]$llmProvider, [string]$llmEndpoint) {
        $this.WorkingDirectory = $workingDir
        $this.TemplatesPath = Join-Path $workingDir "templates"
        $this.GeneratedPath = Join-Path $workingDir "generated"
        $this.LLMProvider = $llmProvider
        $this.LLMEndpoint = $llmEndpoint
        $this.RepoPatterns = @{}
        $this.UserIntent = @{}
        
        # Ensure directories exist
        @($this.TemplatesPath, $this.GeneratedPath) | ForEach-Object {
            if (-not (Test-Path $_)) {
                New-Item -ItemType Directory -Path $_ -Force | Out-Null
            }
        }
        
        # Load repository patterns
        $this.LoadRepositoryPatterns()
    }
    
    [void]LoadRepositoryPatterns() {
        try {
            $repoMirrorPath = Get-ZippyConfig -Key "RepoMirrorPath" -Default "$env:USERPROFILE\ZippyAgent\repo-mirror"
            if (Test-Path $repoMirrorPath) {
                $this.RepoPatterns = $this.AnalyzeRepositoryPatterns($repoMirrorPath)
            }
        } catch {
            Write-Warning "Could not load repository patterns: $_"
        }
    }
    
    [hashtable]AnalyzeRepositoryPatterns([string]$repoPath) {
        $patterns = @{
            "orchestration" = @()
            "containerization" = @()
            "vm_management" = @()
            "local_development" = @()
            "ci_cd" = @()
            "monitoring" = @()
            "security" = @()
            "networking" = @()
        }
        
        if (-not (Test-Path $repoPath)) {
            return $patterns
        }
        
        Get-ChildItem -Path $repoPath -Directory | ForEach-Object {
            $repoName = $_.Name
            $repoFullPath = $_.FullName
            
            # Analyze repository structure and classify patterns
            $dockerFiles = Get-ChildItem -Path $repoFullPath -Filter "Dockerfile*" -Recurse -ErrorAction SilentlyContinue
            $composeFiles = Get-ChildItem -Path $repoFullPath -Filter "docker-compose*" -Recurse -ErrorAction SilentlyContinue
            $k8sFiles = Get-ChildItem -Path $repoFullPath -Filter "*.yaml" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "k8s|kube|deploy" }
            $vagrantFiles = Get-ChildItem -Path $repoFullPath -Filter "Vagrantfile" -Recurse -ErrorAction SilentlyContinue
            $terraformFiles = Get-ChildItem -Path $repoFullPath -Filter "*.tf" -Recurse -ErrorAction SilentlyContinue
            $ansibleFiles = Get-ChildItem -Path $repoFullPath -Filter "*.yml" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "ansible|playbook" }
            
            # Classify based on found files
            if ($dockerFiles -or $composeFiles) {
                $patterns["containerization"] += @{
                    "repo" = $repoName
                    "path" = $repoFullPath
                    "docker_files" = $dockerFiles.Count
                    "compose_files" = $composeFiles.Count
                }
            }
            
            if ($k8sFiles -or $terraformFiles) {
                $patterns["orchestration"] += @{
                    "repo" = $repoName
                    "path" = $repoFullPath
                    "k8s_files" = $k8sFiles.Count
                    "terraform_files" = $terraformFiles.Count
                }
            }
            
            if ($vagrantFiles -or $ansibleFiles) {
                $patterns["vm_management"] += @{
                    "repo" = $repoName
                    "path" = $repoFullPath
                    "vagrant_files" = $vagrantFiles.Count
                    "ansible_files" = $ansibleFiles.Count
                }
            }
            
            # Check for development patterns
            $packageFiles = Get-ChildItem -Path $repoFullPath -Filter "package.json" -Recurse -ErrorAction SilentlyContinue
            $requirementsFiles = Get-ChildItem -Path $repoFullPath -Filter "requirements*.txt" -Recurse -ErrorAction SilentlyContinue
            $makeFiles = Get-ChildItem -Path $repoFullPath -Filter "Makefile" -Recurse -ErrorAction SilentlyContinue
            
            if ($packageFiles -or $requirementsFiles -or $makeFiles) {
                $patterns["local_development"] += @{
                    "repo" = $repoName
                    "path" = $repoFullPath
                    "package_files" = $packageFiles.Count
                    "requirements_files" = $requirementsFiles.Count
                    "make_files" = $makeFiles.Count
                }
            }
        }
        
        return $patterns
    }
    
    [hashtable]RunUIWizard() {
        Write-Host "🚀 Dynamic Orchestrator Generation Wizard" -ForegroundColor Cyan
        Write-Host "==========================================" -ForegroundColor Cyan
        Write-Host ""
        
        $intent = @{}
        
        # Step 1: Project Type
        Write-Host "1. What type of project do you want to orchestrate?" -ForegroundColor Yellow
        Write-Host "   [1] Container Orchestration (Docker/Kubernetes)"
        Write-Host "   [2] VM Setup and Management"
        Write-Host "   [3] Local Development Environment"
        Write-Host "   [4] CI/CD Pipeline"
        Write-Host "   [5] Monitoring and Observability"
        Write-Host "   [6] Custom/Hybrid Solution"
        Write-Host ""
        
        do {
            $projectType = Read-Host "Enter choice (1-6)"
        } while ($projectType -notmatch '^[1-6]$')
        
        $intent["project_type"] = switch ($projectType) {
            "1" { "container_orchestration" }
            "2" { "vm_management" }
            "3" { "local_development" }
            "4" { "ci_cd" }
            "5" { "monitoring" }
            "6" { "custom" }
        }
        
        # Step 2: Scale and Complexity
        Write-Host ""
        Write-Host "2. What scale are you targeting?" -ForegroundColor Yellow
        Write-Host "   [1] Single Developer (1-3 services)"
        Write-Host "   [2] Small Team (4-10 services)"
        Write-Host "   [3] Medium Team (11-50 services)"
        Write-Host "   [4] Enterprise (50+ services)"
        Write-Host ""
        
        do {
            $scale = Read-Host "Enter choice (1-4)"
        } while ($scale -notmatch '^[1-4]$')
        
        $intent["scale"] = switch ($scale) {
            "1" { "single_developer" }
            "2" { "small_team" }
            "3" { "medium_team" }
            "4" { "enterprise" }
        }
        
        # Step 3: Technology Stack
        Write-Host ""
        Write-Host "3. Primary technology stack?" -ForegroundColor Yellow
        Write-Host "   [1] Node.js/JavaScript"
        Write-Host "   [2] Python"
        Write-Host "   [3] .NET/C#"
        Write-Host "   [4] Java/JVM"
        Write-Host "   [5] Go"
        Write-Host "   [6] Rust"
        Write-Host "   [7] Mixed/Polyglot"
        Write-Host ""
        
        do {
            $tech = Read-Host "Enter choice (1-7)"
        } while ($tech -notmatch '^[1-7]$')
        
        $intent["technology"] = switch ($tech) {
            "1" { "nodejs" }
            "2" { "python" }
            "3" { "dotnet" }
            "4" { "java" }
            "5" { "go" }
            "6" { "rust" }
            "7" { "mixed" }
        }
        
        # Step 4: Environment
        Write-Host ""
        Write-Host "4. Target deployment environment?" -ForegroundColor Yellow
        Write-Host "   [1] Local Development"
        Write-Host "   [2] Cloud (AWS/Azure/GCP)"
        Write-Host "   [3] On-Premises"
        Write-Host "   [4] Hybrid (Cloud + On-Prem)"
        Write-Host "   [5] Edge Computing"
        Write-Host ""
        
        do {
            $env = Read-Host "Enter choice (1-5)"
        } while ($env -notmatch '^[1-5]$')
        
        $intent["environment"] = switch ($env) {
            "1" { "local" }
            "2" { "cloud" }
            "3" { "on_premises" }
            "4" { "hybrid" }
            "5" { "edge" }
        }
        
        # Step 5: Required Features
        Write-Host ""
        Write-Host "5. Required features (separate multiple with commas):" -ForegroundColor Yellow
        Write-Host "   - monitoring: Prometheus/Grafana monitoring"
        Write-Host "   - logging: Centralized logging (ELK/Loki)"
        Write-Host "   - security: Security scanning and hardening"
        Write-Host "   - backup: Automated backup and restore"
        Write-Host "   - scaling: Auto-scaling capabilities"
        Write-Host "   - networking: Custom network configuration"
        Write-Host "   - storage: Persistent storage management"
        Write-Host "   - secrets: Secret management integration"
        Write-Host ""
        
        $features = Read-Host "Enter features"
        $intent["features"] = $features -split "," | ForEach-Object { $_.Trim() }
        
        # Step 6: Project Name and Description
        Write-Host ""
        Write-Host "6. Project Details:" -ForegroundColor Yellow
        $intent["project_name"] = Read-Host "Project name"
        $intent["description"] = Read-Host "Brief description"
        
        # Step 7: Advanced Options
        Write-Host ""
        Write-Host "7. Advanced Options:" -ForegroundColor Yellow
        $intent["use_existing_templates"] = (Read-Host "Use existing repository templates? (y/n)") -eq 'y'
        $intent["generate_tests"] = (Read-Host "Generate test configurations? (y/n)") -eq 'y'
        $intent["include_docs"] = (Read-Host "Include documentation templates? (y/n)") -eq 'y'
        
        return $intent
    }
    
    [string]GenerateSystemPrompt([hashtable]$userIntent) {
        $repoContext = ""
        if ($this.RepoPatterns.Count -gt 0) {
            $repoContext = "Available repository patterns:`n"
            $this.RepoPatterns.Keys | ForEach-Object {
                $patterns = $this.RepoPatterns[$_]
                if ($patterns.Count -gt 0) {
                    $repoContext += "- ${_}: $($patterns.Count) examples`n"
                }
            }
        }
        
        $systemPrompt = @"
You are an expert DevOps orchestration architect for the ZippyAgent platform. You specialize in generating production-ready orchestration configurations based on user requirements and existing repository patterns.

CONTEXT:
$repoContext

USER REQUIREMENTS:
- Project Type: $($userIntent.project_type)
- Scale: $($userIntent.scale)
- Technology: $($userIntent.technology)
- Environment: $($userIntent.environment)
- Features: $($userIntent.features -join ", ")
- Project Name: $($userIntent.project_name)
- Description: $($userIntent.description)

TASK:
Generate a complete orchestration configuration that includes:
1. orchestrator.json - Main configuration file
2. tasks.ps1 - PowerShell orchestration script
3. README.md - Documentation and setup instructions
4. Additional configuration files as needed

REQUIREMENTS:
- Follow ZippyAgent platform conventions
- Include error handling and logging
- Support both local and cloud deployment
- Include monitoring and health checks
- Generate production-ready configurations
- Include security best practices
- Support the specified technology stack and scale

RESPONSE FORMAT:
Provide the complete file contents for each generated file, clearly separated and labeled.
"@
        
        return $systemPrompt
    }
    
    [hashtable]CallLLM([string]$systemPrompt, [string]$userPrompt) {
        try {
            if ($this.LLMProvider -eq "ollama") {
                return $this.CallOllama($systemPrompt, $userPrompt)
            } elseif ($this.LLMProvider -eq "openai") {
                return $this.CallOpenAI($systemPrompt, $userPrompt)
            } else {
                throw "Unsupported LLM provider: $($this.LLMProvider)"
            }
        } catch {
            throw "LLM call failed: $_"
        }
    }
    
    [hashtable]CallOllama([string]$systemPrompt, [string]$userPrompt) {
        $requestBody = @{
            model = "llama3.1:latest"
            messages = @(
                @{
                    role = "system"
                    content = $systemPrompt
                },
                @{
                    role = "user"
                    content = $userPrompt
                }
            )
            stream = $false
            options = @{
                temperature = 0.7
                top_p = 0.9
                max_tokens = 4096
            }
        } | ConvertTo-Json -Depth 10
        
        try {
            Write-Host "🤖 Calling Ollama LLM..." -ForegroundColor Green
            $response = Invoke-RestMethod -Uri "$($this.LLMEndpoint)/api/chat" -Method POST -Body $requestBody -ContentType "application/json" -TimeoutSec 300
            
            return @{
                "success" = $true
                "content" = $response.message.content
                "model" = $response.model
                "total_duration" = $response.total_duration
            }
        } catch {
            throw "Ollama API call failed: $_"
        }
    }
    
    [hashtable]CallOpenAI([string]$systemPrompt, [string]$userPrompt) {
        # Placeholder for OpenAI integration
        throw "OpenAI integration not yet implemented"
    }
    
    [void]GenerateProjectFiles([hashtable]$userIntent, [string]$llmResponse) {
        $projectName = $userIntent.project_name -replace '[^a-zA-Z0-9\-_]', '_'
        $projectPath = Join-Path $this.GeneratedPath $projectName
        
        if (Test-Path $projectPath) {
            Write-Host "⚠️  Project directory already exists. Backing up..." -ForegroundColor Yellow
            $backupPath = "${projectPath}_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            Move-Item -Path $projectPath -Destination $backupPath
        }
        
        New-Item -ItemType Directory -Path $projectPath -Force | Out-Null
        
        # Parse LLM response and extract files
        $files = $this.ParseLLMResponse($llmResponse)
        
        foreach ($file in $files) {
            $filePath = Join-Path $projectPath $file.Name
            $fileDir = Split-Path $filePath -Parent
            
            if (-not (Test-Path $fileDir)) {
                New-Item -ItemType Directory -Path $fileDir -Force | Out-Null
            }
            
            Set-Content -Path $filePath -Value $file.Content -Encoding UTF8
            Write-Host "✅ Generated: $($file.Name)" -ForegroundColor Green
        }
        
        # Generate additional metadata
        $metadata = @{
            "generated_at" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            "user_intent" = $userIntent
            "llm_provider" = $this.LLMProvider
            "version" = "1.0"
        } | ConvertTo-Json -Depth 10
        
        Set-Content -Path (Join-Path $projectPath "metadata.json") -Value $metadata -Encoding UTF8
        
        Write-Host ""
        Write-Host "🎉 Project generated successfully!" -ForegroundColor Green
        Write-Host "📁 Location: $projectPath" -ForegroundColor Cyan
        Write-Host ""
        
        # Register in dashboard
        $this.RegisterInDashboard($projectName, $projectPath, $userIntent)
    }
    
    [array]ParseLLMResponse([string]$response) {
        $files = @()
        $lines = $response -split "`n"
        $currentFile = $null
        $currentContent = @()
        $inCodeBlock = $false
        
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            
            # Detect file headers
            if ($line -match '^(#+\s*)?([a-zA-Z0-9_\-\.]+\.(json|ps1|md|yml|yaml|txt|sh|bat|dockerfile))') {
                if ($currentFile) {
                    $files += @{
                        Name = $currentFile
                        Content = ($currentContent -join "`n").Trim()
                    }
                }
                $currentFile = $Matches[2]
                $currentContent = @()
                $inCodeBlock = $false
                continue
            }
            
            # Handle code blocks
            if ($line -match '^```') {
                $inCodeBlock = -not $inCodeBlock
                if (-not $inCodeBlock) {
                    continue
                }
            }
            
            # Add content if we're in a file
            if ($currentFile) {
                $currentContent += $line
            }
        }
        
        # Add the last file
        if ($currentFile) {
            $files += @{
                Name = $currentFile
                Content = ($currentContent -join "`n").Trim()
            }
        }
        
        return $files
    }
    
    [void]RegisterInDashboard([string]$projectName, [string]$projectPath, [hashtable]$userIntent) {
        try {
            $dashboardPath = Join-Path $this.WorkingDirectory "dashboard-registry.json"
            
            $registry = @{
                "orchestrators" = @()
                "last_updated" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            
            if (Test-Path $dashboardPath) {
                $registry = Get-Content -Path $dashboardPath -Raw | ConvertFrom-Json -AsHashtable
            }
            
            # Remove existing entry if it exists
            $registry.orchestrators = $registry.orchestrators | Where-Object { $_.name -ne $projectName }
            
            # Add new entry
            $registry.orchestrators += @{
                "name" = $projectName
                "path" = $projectPath
                "type" = $userIntent.project_type
                "scale" = $userIntent.scale
                "technology" = $userIntent.technology
                "environment" = $userIntent.environment
                "features" = $userIntent.features
                "created_at" = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                "status" = "generated"
            }
            
            $registry.last_updated = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            
            $registryJson = $registry | ConvertTo-Json -Depth 10
            Set-Content -Path $dashboardPath -Value $registryJson -Encoding UTF8
            
            Write-Host "📊 Registered in dashboard: $dashboardPath" -ForegroundColor Blue
        } catch {
            Write-Warning "Failed to register in dashboard: $_"
        }
    }
    
    [void]RunGeneration([hashtable]$userIntent = $null) {
        try {
            if (-not $userIntent) {
                $userIntent = $this.RunUIWizard()
            }
            
            $this.UserIntent = $userIntent
            
            Write-Host ""
            Write-Host "🔄 Generating orchestration configuration..." -ForegroundColor Yellow
            
            $systemPrompt = $this.GenerateSystemPrompt($userIntent)
            $userPrompt = "Generate a complete orchestration configuration for the project '$($userIntent.project_name)' with the specified requirements."
            
            $llmResult = $this.CallLLM($systemPrompt, $userPrompt)
            
            if ($llmResult.success) {
                $this.GenerateProjectFiles($userIntent, $llmResult.content)
            } else {
                throw "LLM generation failed"
            }
            
        } catch {
            Write-Error "Generation failed: $_"
            throw
        }
    }
}

# Main execution
function Main {
    param(
        [string]$Mode,
        [string]$ConfigFile,
        [string]$OutputPath,
        [string]$LLMProvider,
        [string]$LLMEndpoint
    )
    
    try {
        $workingDir = if ($OutputPath) { $OutputPath } else { $PSScriptRoot }
        $generator = [OrchestratorGenerator]::new($workingDir, $LLMProvider, $LLMEndpoint)
        
        if ($Mode -eq "interactive") {
            $generator.RunGeneration()
        } elseif ($Mode -eq "config" -and $ConfigFile) {
            if (-not (Test-Path $ConfigFile)) {
                throw "Config file not found: $ConfigFile"
            }
            $userIntent = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json -AsHashtable
            $generator.RunGeneration($userIntent)
        } else {
            throw "Invalid mode or missing config file"
        }
        
    } catch {
        Write-Error "Orchestrator generation failed: $_"
        exit 1
    }
}

# Execute if run directly
if ($MyInvocation.InvocationName -ne '.') {
    Main -Mode $Mode -ConfigFile $ConfigFile -OutputPath $OutputPath -LLMProvider $LLMProvider -LLMEndpoint $LLMEndpoint
}
