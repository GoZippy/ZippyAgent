@{
    # Script module or binary module file associated with this manifest.
    RootModule        = 'Zippy.RepoHarvest.psm1'

    # Version number of this module.
    ModuleVersion     = '0.1.0'

    # Supported PSEditions
    CompatiblePSEditions = @('Core')

    # ID used to uniquely identify this module.
    GUID              = 'a1b2c3d4-5e6f-4701-9abc-def012345678'

    # Author of this module
    Author            = 'ZippyAgent'

    # Company or vendor of this module
    CompanyName       = 'ZippyAgent'

    # Copyright statement for this module
    Copyright         = '(c) 2025 ZippyAgent. All rights reserved.'

    # Description of the functionality provided by this module
    Description       = 'Harvests metadata and statistics from git repositories for the ZippyAgent platform.'

    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module
    FunctionsToExport = @('Invoke-RepoHarvest')

    # Cmdlets to export from this module
    CmdletsToExport   = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport   = @()

    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData       = @{
        PSData = @{
            # Tags applied to this module. These help with module discovery in online galleries.
            Tags        = @('git','repository','harvest','ZippyAgent')

            # A URL to the license for this module.
            LicenseUri  = ''

            # A URL to the main website for this project.
            ProjectUri  = 'https://github.com/user/ZippyAgent'

            # Release notes for this module.
            ReleaseNotes = 'Initial placeholder release.'
        }
    }
}

