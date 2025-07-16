# Zippy Repo Harvest PowerShell Module

# Helper function to parse simple YAML configuration
function Get-YamlConfig {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        return $null
    }
    
    $config = @{}
    $content = Get-Content $Path
    
    foreach ($line in $content) {
        if ($line -match '^\s*([^#:]+):\s*"?([^"#]+)"?\s*(?:#.*)?$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim().Trim('"')
            $config[$key] = $value
        }
    }
    
    return $config
}

# Configuration for organizations and explicit repo URLs
$script:DefaultOrganizations = @(
    'microsoft',
    'openai',
    'anthropic',
    'langchain-ai'
)

$script:ExplicitRepos = @(
    'https://github.com/microsoft/autogen',
    'https://github.com/microsoft/semantic-kernel',
    'https://github.com/openai/openai-cookbook',
    'https://github.com/anthropic/anthropic-sdk-python',
    'https://github.com/langchain-ai/langchain',
    'https://github.com/crewAIInc/crewAI',
    'https://github.com/phidatahq/phidata',
    'https://github.com/swarmzero/swarmzero'
)

function Get-GitRepos {
    <#
        .SYNOPSIS
        Enumerates public repositories from specified GitHub organizations and explicit URLs.

        .DESCRIPTION
        Uses GitHub REST API to discover repositories from configured organizations
        and includes explicit repository URLs. Filters for relevant repositories
        based on topics, languages, and keywords related to AI agents, orchestration,
        and blockchain.

        .PARAMETER Organizations
        Array of GitHub organization names to enumerate. Defaults to predefined list.

        .PARAMETER ExplicitUrls
        Array of explicit repository URLs to include. Defaults to predefined list.

        .PARAMETER GitHubToken
        GitHub personal access token for API authentication (optional but recommended).

        .PARAMETER FilterKeywords
        Keywords to filter repositories by (in name, description, or topics).

        .EXAMPLE
            Get-GitRepos -GitHubToken $env:GITHUB_TOKEN
    #>
    [CmdletBinding()]
    param(
        [string[]]$Organizations = $script:DefaultOrganizations,
        [string[]]$ExplicitUrls = $script:ExplicitRepos,
        [string]$GitHubToken = $env:GITHUB_TOKEN,
        [string[]]$FilterKeywords = @('agent', 'orchestration', 'blockchain', 'ai', 'llm', 'framework', 'automation', 'workflow')
    )

    $repos = @()
    $headers = @{
        'Accept' = 'application/vnd.github.v3+json'
        'User-Agent' = 'ZippyAgent-RepoHarvest/1.0'
    }

    if ($GitHubToken) {
        $headers['Authorization'] = "token $GitHubToken"
    }

    # Get repositories from organizations
    foreach ($org in $Organizations) {
        try {
            Write-Host "Fetching repositories from organization: $org" -ForegroundColor Green
            $page = 1
            do {
                $uri = "https://api.github.com/orgs/$org/repos?type=public&per_page=100&page=$page"
                $response = Invoke-RestMethod -Uri $uri -Headers $headers
                
                foreach ($repo in $response) {
                    $isRelevant = $false
                    
                    # Check if repo matches filter keywords
                    foreach ($keyword in $FilterKeywords) {
                        if ($repo.name -like "*$keyword*" -or 
                            $repo.description -like "*$keyword*" -or
                            ($repo.topics -and $repo.topics -contains $keyword)) {
                            $isRelevant = $true
                            break
                        }
                    }
                    
                    if ($isRelevant) {
                        $repos += [pscustomobject]@{
                            Name = $repo.name
                            FullName = $repo.full_name
                            Owner = $repo.owner.login
                            CloneUrl = $repo.clone_url
                            Description = $repo.description
                            Language = $repo.language
                            Topics = $repo.topics
                            License = $repo.license.name
                            DefaultBranch = $repo.default_branch
                            CreatedAt = $repo.created_at
                            UpdatedAt = $repo.updated_at
                            StarCount = $repo.stargazers_count
                            ForkCount = $repo.forks_count
                            Source = "Organization:$org"
                        }
                    }
                }
                
                $page++
            } while ($response.Count -eq 100)
        }
        catch {
            Write-Warning "Failed to fetch repositories from organization $org: $($_.Exception.Message)"
        }
    }

    # Process explicit repository URLs
    foreach ($url in $ExplicitUrls) {
        try {
            Write-Host "Fetching explicit repository: $url" -ForegroundColor Green
            
            # Parse GitHub URL to get owner and repo name
            if ($url -match 'github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$') {
                $owner = $matches[1]
                $repoName = $matches[2]
                
                $uri = "https://api.github.com/repos/$owner/$repoName"
                $repo = Invoke-RestMethod -Uri $uri -Headers $headers
                
                $repos += [pscustomobject]@{
                    Name = $repo.name
                    FullName = $repo.full_name
                    Owner = $repo.owner.login
                    CloneUrl = $repo.clone_url
                    Description = $repo.description
                    Language = $repo.language
                    Topics = $repo.topics
                    License = $repo.license.name
                    DefaultBranch = $repo.default_branch
                    CreatedAt = $repo.created_at
                    UpdatedAt = $repo.updated_at
                    StarCount = $repo.stargazers_count
                    ForkCount = $repo.forks_count
                    Source = "Explicit:$url"
                }
            }
        }
        catch {
            Write-Warning "Failed to fetch explicit repository $url: $($_.Exception.Message)"
        }
    }

    Write-Host "Found $($repos.Count) repositories" -ForegroundColor Green
    return $repos
}

function Invoke-GitSync {
    <#
        .SYNOPSIS
        Clones or updates repositories and maintains metadata index.

        .DESCRIPTION
        Clones new repositories or pulls updates for existing ones into the
        configured mirror path. Updates the repository index with metadata
        including sync timestamps, branch info, languages, and license.

        .PARAMETER RepoMirrorPath
        Base path where repositories will be cloned. Defaults to config value.

        .PARAMETER Repositories
        Array of repository objects to sync. If not provided, discovers using Get-GitRepos.

        .PARAMETER Force
        Force re-clone of repositories even if they already exist.

        .PARAMETER Since
        Only sync repositories updated since this date/time.

        .PARAMETER IndexType
        Type of index to maintain: 'json' or 'sqlite'. Defaults to 'json'.

        .PARAMETER GitHubToken
        GitHub personal access token for API authentication.

        .EXAMPLE
            Invoke-GitSync -Force
            Invoke-GitSync -Since (Get-Date).AddDays(-7) -GitHubToken $env:GITHUB_TOKEN
    #>
    [CmdletBinding()]
    param(
        [string]$RepoMirrorPath,
        [object[]]$Repositories,
        [switch]$Force,
        [datetime]$Since,
        [ValidateSet('json', 'sqlite')]$IndexType = 'json',
        [string]$GitHubToken = $env:GITHUB_TOKEN
    )

    # Load configuration if RepoMirrorPath not provided
    if (-not $RepoMirrorPath) {
        $configPath = Join-Path (Get-Location) 'config/zippyagent.yaml'
        if (Test-Path $configPath) {
            $config = Get-YamlConfig -Path $configPath
            $RepoMirrorPath = $config['repoMirrorPath']
        }
        else {
            $RepoMirrorPath = './data/repos'
        }
    }

    # Resolve to absolute path
    $RepoMirrorPath = Resolve-Path $RepoMirrorPath -ErrorAction SilentlyContinue
    if (-not $RepoMirrorPath) {
        $RepoMirrorPath = Join-Path (Get-Location) 'data/repos'
    }

    # Ensure mirror directory exists
    if (-not (Test-Path $RepoMirrorPath)) {
        New-Item -ItemType Directory -Path $RepoMirrorPath -Force | Out-Null
    }

    # Get repositories if not provided
    if (-not $Repositories) {
        Write-Host "Discovering repositories..." -ForegroundColor Yellow
        $Repositories = Get-GitRepos -GitHubToken $GitHubToken
    }

    # Filter by Since parameter if provided
    if ($Since) {
        $Repositories = $Repositories | Where-Object { [datetime]$_.UpdatedAt -gt $Since }
        Write-Host "Filtered to $($Repositories.Count) repositories updated since $Since" -ForegroundColor Yellow
    }

    # Load existing index
    $indexPath = Join-Path $RepoMirrorPath "repos.$IndexType"
    $index = @{}
    
    if (Test-Path $indexPath) {
        if ($IndexType -eq 'json') {
            $index = Get-Content $indexPath | ConvertFrom-Json -AsHashtable
        }
        # SQLite support could be added here
    }

    $syncResults = @()
    
    foreach ($repo in $Repositories) {
        $repoKey = "$($repo.Owner)_$($repo.Name)"
        $repoPath = Join-Path $RepoMirrorPath $repoKey
        $needsClone = $false
        $syncStatus = "Unknown"
        
        try {
            Write-Host "Processing: $($repo.FullName)" -ForegroundColor Cyan
            
            # Check if repository exists locally
            if (Test-Path $repoPath) {
                if ($Force) {
                    Write-Host "  Force flag set, removing existing directory" -ForegroundColor Yellow
                    Remove-Item -Path $repoPath -Recurse -Force
                    $needsClone = $true
                }
                else {
                    # Pull updates
                    Write-Host "  Pulling updates..." -ForegroundColor Green
                    Push-Location $repoPath
                    try {
                        $gitResult = git pull origin $repo.DefaultBranch 2>`&1
                        if ($LASTEXITCODE -eq 0) {
                            $syncStatus = "Updated"
                        }
                        else {
                            $syncStatus = "Pull Failed: $gitResult"
                            Write-Warning "Git pull failed: $gitResult"
                        }
                    }
                    finally {
                        Pop-Location
                    }
                }
            }
            else {
                $needsClone = $true
            }
            
            # Clone if needed
            if ($needsClone) {
                Write-Host "  Cloning repository..." -ForegroundColor Green
                $gitResult = git clone $repo.CloneUrl $repoPath 2>`&1
                if ($LASTEXITCODE -eq 0) {
                    $syncStatus = "Cloned"
                }
                else {
                    $syncStatus = "Clone Failed: $gitResult"
                    Write-Warning "Git clone failed: $gitResult"
                }
            }
            
            # Update index with metadata
            $index[$repoKey] = @{
                Name = $repo.Name
                FullName = $repo.FullName
                Owner = $repo.Owner
                CloneUrl = $repo.CloneUrl
                Description = $repo.Description
                Language = $repo.Language
                Topics = $repo.Topics
                License = $repo.License
                DefaultBranch = $repo.DefaultBranch
                CreatedAt = $repo.CreatedAt
                UpdatedAt = $repo.UpdatedAt
                StarCount = $repo.StarCount
                ForkCount = $repo.ForkCount
                Source = $repo.Source
                LocalPath = $repoPath
                LastSync = Get-Date -Format o
                SyncStatus = $syncStatus
            }
            
            $syncResults += [pscustomobject]@{
                Repository = $repo.FullName
                Status = $syncStatus
                LocalPath = $repoPath
                LastSync = $index[$repoKey].LastSync
            }
        }
        catch {
            Write-Warning "Failed to sync repository $($repo.FullName): $($_.Exception.Message)"
            $syncResults += [pscustomobject]@{
                Repository = $repo.FullName
                Status = "Error: $($_.Exception.Message)"
                LocalPath = $repoPath
                LastSync = Get-Date -Format o
            }
        }
    }
    
    # Save updated index
    if ($IndexType -eq 'json') {
        $index | ConvertTo-Json -Depth 10 | Set-Content $indexPath
    }
    # SQLite support could be added here
    
    Write-Host "\nSync Summary:" -ForegroundColor Green
    $syncResults | Group-Object Status | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Count)" -ForegroundColor Yellow
    }
    
    return $syncResults
}

function Invoke-RepoHarvest {
    <#
        .SYNOPSIS
        Harvests metadata and statistics from a git repository.

        .DESCRIPTION
        This is a lightweight placeholder implementation that will be
        extended during future development steps.  For now it simply
        resolves the repository root and writes a summary object with
        a timestamp.

        .PARAMETER Path
        Path to the git repository whose information should be harvested.
        Defaults to the current directory.

        .EXAMPLE
            Invoke-RepoHarvest -Path "C:\src\my-project"
    #>
    [CmdletBinding()]
    param(
        [string]$Path = (Get-Location)
    )

    if (-not (Test-Path $Path)) {
        throw "Provided path '$Path' does not exist."
    }

    # Resolve absolute path
    $repoRoot = Resolve-Path $Path

    $result = [pscustomobject]@{
        Repository = $repoRoot
        Harvested  = Get-Date -Format o
        Notes      = "Repo harvesting placeholder – extend in future steps."
    }

    return $result
}

function Start-ChromaDBIfNeeded {
    <#
        .SYNOPSIS
        Ensures ChromaDB server is running, starting it if necessary.

        .DESCRIPTION
        Checks if ChromaDB server is running on the specified host and port.
        If not running, executes the Start-Chroma.ps1 script to launch it.

        .PARAMETER Host
        Host address for ChromaDB server. Defaults to 127.0.0.1.

        .PARAMETER Port
        Port for ChromaDB server. Defaults to 8000.

        .EXAMPLE
            Start-ChromaDBIfNeeded -Host "127.0.0.1" -Port 8000
    #>
    [CmdletBinding()]
    param(
        [string]$Host = "127.0.0.1",
        [int]$Port = 8000
    )

    # Test if ChromaDB is running
    try {
        $response = Invoke-RestMethod -Uri "http://$Host`:$Port/health" -Method GET -TimeoutSec 5
        Write-Host "✅ ChromaDB server is already running on $Host`:$Port" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "⚠️  ChromaDB server not running, starting it..." -ForegroundColor Yellow
    }

    # Find and execute Start-Chroma.ps1
    $startChromaScript = Join-Path (Get-Location) "Start-Chroma.ps1"
    if (-not (Test-Path $startChromaScript)) {
        Write-Error "Start-Chroma.ps1 script not found at: $startChromaScript"
        return $false
    }

    try {
        # Execute Start-Chroma.ps1
        & $startChromaScript -Host $Host -Port $Port
        
        # Wait and verify it started
        Start-Sleep -Seconds 5
        $response = Invoke-RestMethod -Uri "http://$Host`:$Port/health" -Method GET -TimeoutSec 10
        Write-Host "✅ ChromaDB server started successfully on $Host`:$Port" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Failed to start ChromaDB server: $($_.Exception.Message)"
        return $false
    }
}

function Invoke-RepoEmbed {
    <#
        .SYNOPSIS
        Embeds repository content into vector database with change detection.

        .DESCRIPTION
        Walks through repository files respecting .gitignore, chunks content,
        and generates embeddings for storage in Chroma DB. Implements change
        detection via git diff and file hashes to optimize re-embedding.
        Ensures ChromaDB server is running before processing.

        .PARAMETER RepoPath
        Path to the git repository to embed. Defaults to current directory.

        .PARAMETER MaxTokens
        Maximum tokens per chunk. Defaults to config value.

        .PARAMETER OverlapTokens
        Token overlap between chunks. Defaults to 50.

        .PARAMETER ChromaHost
        Host address for ChromaDB server. Defaults to 127.0.0.1.

        .PARAMETER ChromaPort
        Port for ChromaDB server. Defaults to 8000.

        .EXAMPLE
            Invoke-RepoEmbed -RepoPath "./my-repo"
    #>
    [CmdletBinding()]
    param(
        [string]$RepoPath = (Get-Location),
        [int]$MaxTokens = 400,
        [int]$OverlapTokens = 50,
        [string]$ChromaHost = "127.0.0.1",
        [int]$ChromaPort = 8000
    )

    Write-Host "🚀 Starting ZippyAgent Repository Embedding Pipeline" -ForegroundColor Green
    
    # Ensure ChromaDB server is running
    if (-not (Start-ChromaDBIfNeeded -Host $ChromaHost -Port $ChromaPort)) {
        throw "ChromaDB server could not be started. Embedding pipeline cannot proceed."
    }

    # Validate and resolve repository path
    if (-not (Test-Path $RepoPath)) {
        throw "Repository path '$RepoPath' does not exist."
    }
    $repoRoot = Resolve-Path $RepoPath

    # Load configuration
    $configPath = Join-Path (Get-Location) 'config/zippyagent.yaml'
    if (-not (Test-Path $configPath)) {
        throw "Configuration file not found at $configPath"
    }
    $config = Get-YamlConfig -Path $configPath
    
    # Override with config values if available
    if ($config['maxChunkTokens']) { $MaxTokens = [int]$config['maxChunkTokens'] }
    
    Write-Host "📁 Processing repository: $repoRoot" -ForegroundColor Cyan
    Write-Host "🔧 Config: MaxTokens=$MaxTokens, Provider=$($config['embeddingProvider']), VectorDB=$($config['vectorDbPath'])" -ForegroundColor Yellow

    # Ensure vector DB directory exists
    if (-not (Test-Path $config['vectorDbPath'])) {
        New-Item -ItemType Directory -Path $config['vectorDbPath'] -Force | Out-Null
        Write-Host "📂 Created vector DB directory: $($config['vectorDbPath'])" -ForegroundColor Green
    }

    # Get files respecting .gitignore
    $validExtensions = @('*.md', '*.txt', '*.py', '*.ts', '*.rs', '*.js', '*.go', '*.java', '*.cpp', '*.c', '*.h')
    $files = Get-ChildItem -Path $repoRoot -Recurse -Include $validExtensions | 
        Where-Object { Test-ShouldProcessFile -File $_ -RepoRoot $repoRoot }

    Write-Host "📋 Found $($files.Count) files to process" -ForegroundColor Yellow

    $processedFiles = 0
    $totalChunks = 0
    $embeddedChunks = 0

    # Process each file
    foreach ($file in $files) {
        $processedFiles++
        $relativePath = $file.FullName.Substring($repoRoot.Length + 1)
        Write-Host "[$processedFiles/$($files.Count)] Processing: $relativePath" -ForegroundColor Cyan
        
        try {
            # Read file content
            $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            if (-not $content) { continue }
            
            # Chunk the content
            $chunks = Split-ContentIntoChunks -Content $content -MaxTokens $MaxTokens -OverlapTokens $OverlapTokens
            $totalChunks += $chunks.Count
            
            Write-Host "  📄 Created $($chunks.Count) chunks" -ForegroundColor White
            
            # Process each chunk
            for ($i = 0; $i -lt $chunks.Count; $i++) {
                $chunk = $chunks[$i]
                
                # Generate chunk ID
                $chunkId = "$($file.BaseName)_chunk_$i"
                
                # Check if chunk needs embedding (change detection)
                if (Test-ChunkNeedsEmbedding -File $file -ChunkId $chunkId -Content $chunk.Content -VectorDbPath $config['vectorDbPath']) {
                    # Get embedding
                    $embedding = Get-ContentEmbedding -Content $chunk.Content -Config $config
                    
                    if ($embedding) {
                        # Store in vector DB
                        Save-ChunkEmbedding -ChunkId $chunkId -File $file -Chunk $chunk -Embedding $embedding -VectorDbPath $config['vectorDbPath']
                        $embeddedChunks++
                        Write-Host "    ✅ Embedded chunk $($i + 1)/$($chunks.Count)" -ForegroundColor Green
                    } else {
                        Write-Warning "    ❌ Failed to embed chunk $($i + 1)/$($chunks.Count)"
                    }
                } else {
                    Write-Host "    ⏭️  Skipped chunk $($i + 1)/$($chunks.Count) (no changes)" -ForegroundColor Gray
                }
            }
        }
        catch {
            Write-Warning "❌ Failed to process file $relativePath`: $($_.Exception.Message)"
        }
    }

    # Summary
    Write-Host "\n🎉 Embedding Pipeline Complete!" -ForegroundColor Green
    Write-Host "📊 Summary:" -ForegroundColor Yellow
    Write-Host "  - Files processed: $processedFiles" -ForegroundColor White
    Write-Host "  - Total chunks: $totalChunks" -ForegroundColor White
    Write-Host "  - Embedded chunks: $embeddedChunks" -ForegroundColor White
    Write-Host "  - Skipped chunks: $($totalChunks - $embeddedChunks)" -ForegroundColor White
    
    return @{
        ProcessedFiles = $processedFiles
        TotalChunks = $totalChunks
        EmbeddedChunks = $embeddedChunks
        SkippedChunks = $totalChunks - $embeddedChunks
    }
}

# Helper function to check if file should be processed (respects .gitignore)
function Test-ShouldProcessFile {
    param(
        [System.IO.FileInfo]$File,
        [string]$RepoRoot
    )
    
    $gitignorePath = Join-Path $RepoRoot '.gitignore'
    if (-not (Test-Path $gitignorePath)) {
        return $true
    }
    
    $relativePath = $File.FullName.Substring($RepoRoot.Length + 1).Replace('\', '/')
    $gitignorePatterns = Get-Content $gitignorePath | Where-Object { $_ -and -not $_.StartsWith('#') }
    
    foreach ($pattern in $gitignorePatterns) {
        $pattern = $pattern.Trim()
        if ($relativePath -like $pattern -or $relativePath -like "*/$pattern" -or $relativePath -like "$pattern/*") {
            return $false
        }
    }
    
    return $true
}

# Helper function to split content into chunks
function Split-ContentIntoChunks {
    param(
        [string]$Content,
        [int]$MaxTokens = 400,
        [int]$OverlapTokens = 50
    )
    
    $chunks = @()
    $lines = $Content -split "`n"
    $currentChunk = ""
    $currentTokenCount = 0
    $startLine = 0
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineTokens = ($line -split '\s+').Count
        
        if ($currentTokenCount + $lineTokens -gt $MaxTokens -and $currentChunk) {
            # Create chunk
            $chunks += @{
                Content = $currentChunk.Trim()
                StartLine = $startLine + 1
                EndLine = $i
                TokenCount = $currentTokenCount
            }
            
            # Start new chunk with overlap
            $overlapLines = [Math]::Min($OverlapTokens, $i - $startLine)
            $overlapStart = [Math]::Max(0, $i - $overlapLines)
            $currentChunk = ($lines[$overlapStart..($i-1)] -join "`n") + "`n"
            $currentTokenCount = ($currentChunk -split '\s+').Count
            $startLine = $overlapStart
        }
        
        $currentChunk += $line + "`n"
        $currentTokenCount += $lineTokens
    }
    
    # Add final chunk if any content remains
    if ($currentChunk.Trim()) {
        $chunks += @{
            Content = $currentChunk.Trim()
            StartLine = $startLine + 1
            EndLine = $lines.Count
            TokenCount = $currentTokenCount
        }
    }
    
    return $chunks
}

# Helper function to check if chunk needs embedding
function Test-ChunkNeedsEmbedding {
    param(
        [System.IO.FileInfo]$File,
        [string]$ChunkId,
        [string]$Content,
        [string]$VectorDbPath
    )
    
    $hashPath = Join-Path $VectorDbPath "hashes.json"
    $hashes = @{}
    
    if (Test-Path $hashPath) {
        $hashes = Get-Content $hashPath | ConvertFrom-Json -AsHashtable
    }
    
    $contentHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Content))
    $contentHashString = [System.BitConverter]::ToString($contentHash).Replace('-', '')
    
    $key = "$($File.FullName)_$ChunkId"
    $lastHash = $hashes[$key]
    
    return $lastHash -ne $contentHashString
}

# Helper function to get content embedding
function Get-ContentEmbedding {
    param(
        [string]$Content,
        [hashtable]$Config
    )
    
    try {
        switch ($Config['embeddingProvider']) {
            "ollama" {
                $body = @{
                    model = $Config['modelName']
                    prompt = $Content
                } | ConvertTo-Json
                
                $response = Invoke-RestMethod -Uri "http://localhost:11434/api/embeddings" -Method Post -Body $body -ContentType "application/json"
                return $response.embedding
            }
            "openai" {
                $headers = @{
                    "Authorization" = "Bearer $($Config['apiKey'])"
                    "Content-Type" = "application/json"
                }
                $body = @{
                    model = $Config['modelName']
                    input = $Content
                } | ConvertTo-Json
                
                $response = Invoke-RestMethod -Uri "https://api.openai.com/v1/embeddings" -Method Post -Body $body -Headers $headers
                return $response.data[0].embedding
            }
            default {
                Write-Warning "Unsupported embedding provider: $($Config['embeddingProvider'])"
                return $null
            }
        }
    }
    catch {
        Write-Warning "Failed to get embedding: $($_.Exception.Message)"
        return $null
    }
}

# Helper function to save chunk embedding
function Save-ChunkEmbedding {
    param(
        [string]$ChunkId,
        [System.IO.FileInfo]$File,
        [hashtable]$Chunk,
        [array]$Embedding,
        [string]$VectorDbPath
    )
    
    # Save embedding to Chroma DB format (simplified JSON for now)
    $embeddingData = @{
        id = $ChunkId
        content = $Chunk.Content
        embedding = $Embedding
        metadata = @{
            file = $File.FullName
            fileName = $File.Name
            startLine = $Chunk.StartLine
            endLine = $Chunk.EndLine
            tokenCount = $Chunk.TokenCount
            timestamp = Get-Date -Format o
        }
    }
    
    $embeddingPath = Join-Path $VectorDbPath "$ChunkId.json"
    $embeddingData | ConvertTo-Json -Depth 10 | Set-Content $embeddingPath
    
    # Update hash tracking
    $hashPath = Join-Path $VectorDbPath "hashes.json"
    $hashes = @{}
    
    if (Test-Path $hashPath) {
        $hashes = Get-Content $hashPath | ConvertFrom-Json -AsHashtable
    }
    
    $contentHash = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Chunk.Content))
    $contentHashString = [System.BitConverter]::ToString($contentHash).Replace('-', '')
    $key = "$($File.FullName)_$ChunkId"
    
    $hashes[$key] = $contentHashString
    $hashes | ConvertTo-Json -Depth 10 | Set-Content $hashPath
}

Export-ModuleMember -Function Get-GitRepos, Invoke-GitSync, Invoke-RepoHarvest, Invoke-RepoEmbed

