# Pester tests for ZippyAgent module
Describe "ZippyAgent basic module tests" {
    It "Should import without errors" {
        { Import-Module "$PSScriptRoot/../ZippyAgent.psd1" -Force -ErrorAction Stop } | Should -Not -Throw
    }
}

