# Root module for ZippyAgent

# Dot-source all public functions automatically
$PublicFunctions = Get-ChildItem -Path $PSScriptRoot/Public -Filter '*.ps1' -Recurse
foreach ($func in $PublicFunctions) {
    . $func.FullName
}

# Dot-source private/internal helper functions
$PrivateFunctions = Get-ChildItem -Path $PSScriptRoot/Private -Filter '*.ps1' -Recurse
foreach ($func in $PrivateFunctions) {
    . $func.FullName
}

Export-ModuleMember -Function ($PublicFunctions | ForEach-Object { $_.BaseName })

