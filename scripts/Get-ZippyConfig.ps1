function Get-ZippyConfig {
<#!
.SYNOPSIS
    Loads zippyagent.yaml configuration file and merges environment variable overrides.

.DESCRIPTION
    Searches for the configuration YAML file (default: "config/zippyagent.yaml" relative to the repository root),
    converts it to a PowerShell object, then applies overrides from environment variables. Supported overrides:

        ZIPPY_REPO_MIRROR_PATH  -> repoMirrorPath
        ZIPPY_VECTOR_DB_PATH    -> vectorDbPath
        ZIPPY_EMBEDDING_PROVIDER-> embeddingProvider.provider
        ZIPPY_MODEL_NAME        -> embeddingProvider.modelName
        ZIPPY_API_KEY           -> embeddingProvider.apiKey
        ZIPPY_BATCH_SIZE        -> batchSize
        ZIPPY_MAX_CHUNK_TOKENS  -> maxChunkTokens

.EXAMPLE
    $config = Get-ZippyConfig
    $config.repoMirrorPath

.NOTES
    Requires the PowerShell-Yaml module (Install-Module -Name powershell-yaml -Scope CurrentUser)
#>
    [CmdletBinding()]
    param(
        [string]$Path = (Join-Path -Path $PSScriptRoot -ChildPath '..' | 
                           Join-Path -ChildPath 'config/zippyagent.yaml' -Resolve:$false)
    )

    # Ensure powershell-yaml module is available
    if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
        Write-Verbose "powershell-yaml module not found; installing to CurrentUser..."
        try {
            Install-Module -Name powershell-yaml -Scope CurrentUser -Force -ErrorAction Stop
        } catch {
            throw "Unable to load or install 'powershell-yaml' module. Please install it manually."
        }
    }

    Import-Module powershell-yaml -ErrorAction Stop

    $config = @{}
    if (Test-Path $Path) {
        $yamlContent = Get-Content $Path -Raw
        if ($yamlContent.Trim()) {
            $config = ConvertFrom-Yaml $yamlContent -Ordered
        }
    }

    # Helper to ensure nested hashtable path exists
    function Ensure-Path {
        param([hashtable]$root, [string[]]$segments)
        $current = $root
        foreach ($seg in $segments[0..($segments.Length-2)]) {
            if (-not $current.ContainsKey($seg) -or $null -eq $current[$seg]) {
                $current[$seg] = @{}
            }
            $current = $current[$seg]
        }
        return $current
    }

    $envMap = @{
        'ZIPPY_REPO_MIRROR_PATH'     = 'repoMirrorPath'
        'ZIPPY_VECTOR_DB_PATH'       = 'vectorDbPath'
        'ZIPPY_EMBEDDING_PROVIDER'   = 'embeddingProvider.provider'
        'ZIPPY_MODEL_NAME'           = 'embeddingProvider.modelName'
        'ZIPPY_API_KEY'              = 'embeddingProvider.apiKey'
        'ZIPPY_BATCH_SIZE'           = 'batchSize'
        'ZIPPY_MAX_CHUNK_TOKENS'     = 'maxChunkTokens'
    }

    foreach ($kvp in $envMap.GetEnumerator()) {
        $envName  = $kvp.Key
        $cfgPath  = $kvp.Value.Split('.')
        $envValue = [Environment]::GetEnvironmentVariable($envName)
        if (![string]::IsNullOrEmpty($envValue)) {
            # Cast numeric fields
            if ($cfgPath[-1] -in @('batchSize','maxChunkTokens')) {
                $envValue = [int]$envValue
            }
            $target = Ensure-Path -root $config -segments $cfgPath
            $target[$cfgPath[-1]] = $envValue
        }
    }

    # Convert to PSCustomObject for more convenient dot-notation access
    return [pscustomobject]$config
}

