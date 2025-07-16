# Test loading the module
Write-Host "Testing ZippyAgent module loading..." -ForegroundColor Green

try {
    Import-Module ./scripts/Zippy.RepoHarvest.psm1 -Force
    Write-Host "✅ Module loaded successfully!" -ForegroundColor Green
    
    # Test basic functionality
    Write-Host "Testing Get-YamlConfig..." -ForegroundColor Yellow
    $config = Get-YamlConfig -Path "./config/zippyagent.yaml"
    if ($config) {
        Write-Host "✅ Config loaded: $($config.Keys -join ', ')" -ForegroundColor Green
    } else {
        Write-Host "❌ Config not found" -ForegroundColor Red
    }
    
    # Test repo embedding pipeline
    Write-Host "Testing Invoke-RepoEmbed..." -ForegroundColor Yellow
    $result = Invoke-RepoEmbed -MaxTokens 100
    Write-Host "✅ Embedding result: $($result | ConvertTo-Json -Depth 2)" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
}
