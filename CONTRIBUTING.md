# Contributing to ZippyAgent

Thank you for considering contributing to ZippyAgent! This document describes the layout of the PowerShell module and guidelines for adding code, tests and docs.

## Repository layout

```
src/
  ZippyAgent/               # PowerShell module root
    ZippyAgent.psd1         # Module manifest
    ZippyAgent.psm1         # Root module script
    Public/                 # Exported functions (dot-sourced automatically)
    Private/                # Internal helper functions (not exported)
    Tests/                  # Pester test files
    Docs/                   # platyPS markdown help output
```

### Public vs Private

* **Public** – Any `.ps1` placed in `Public/` is treated as a cmdlet‐style function and automatically exported. Use PowerShell approved verb-noun naming (e.g. `Get-AgentStatus.ps1`).
* **Private** – Internal helper functions live in `Private/`. They are dot-sourced but not exported.

### Tests

Add Pester tests under `Tests/` matching the function or feature you are introducing. New Public functions **must** ship with tests.

### Docs

Cmdlet help is generated with platyPS. Run:

```powershell
Update-MarkdownHelp -Path src/ZippyAgent/Docs -ModuleManifest src/ZippyAgent/ZippyAgent.psd1
```

### Coding standards

1. Follow PowerShell best practices and script-analyzer recommendations.
2. Use approved verbs and singular nouns.
3. Include comment-based help in every public function.

### Workflow

1. Fork and create a feature branch.
2. Add or modify code in `src/ZippyAgent` following the layout above.
3. Add/adjust Pester tests.
4. Update docs with platyPS.
5. Submit a pull request.

We appreciate your contribution ❤️

