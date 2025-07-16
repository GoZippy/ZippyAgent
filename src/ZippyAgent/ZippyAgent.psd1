@{
    # Script module or binary module file associated with this manifest.
    RootModule = 'ZippyAgent.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0'

    # Prerelease tag (handled by PowerShellGet v3+). Remove or set to '' for stable releases.
    Prerelease = 'alpha'

    # ID used to uniquely identify this module
    GUID = 'd2f9c7e0-8a18-4e2f-9b2a-6e6b3d8b1234'

    # Author information
    Author = 'ZippyAgent Team'
    CompanyName = 'Zippy'
    Copyright = '(c) ZippyAgent Team. All rights reserved.'

    # Minimum version of the PowerShell engine required
    PowerShellVersion = '5.1'
    CompatiblePSEditions = @('Desktop','Core')

    # External module dependencies required at import time.
    RequiredModules = @(
        @{ ModuleName = 'Microsoft.PowerShell.SecretManagement'; ModuleVersion = '1.1.0' },
        @{ ModuleName = 'Microsoft.PowerShell.SecretStore'; ModuleVersion = '1.0.5' }
    )

    # Functions to export from this module. Leave empty to export all public functions dynamically.
    FunctionsToExport = @()
    CmdletsToExport   = @()
    VariablesToExport = '*'
    AliasesToExport   = @()

    PrivateData = @{
        PSData = @{
            Tags        = @('Zippy','Agent','Automation','Module')
            LicenseUri  = 'https://github.com/zippyagent/zippyagent/blob/main/LICENSE'
            ProjectUri  = 'https://github.com/zippyagent/zippyagent'
            ReleaseNotes = 'Initial alpha release of ZippyAgent PowerShell module.'
        }
    }
}

