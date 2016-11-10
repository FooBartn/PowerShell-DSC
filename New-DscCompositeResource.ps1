function New-DscCompositeResource {
    <#
        .SYNOPSIS
        Provides a quick way to create the directory structure for a composite resource

        .DESCRIPTION
        Given a module and resource name, the function will create the skeleton folder structure and manifest files
        necessary for the use of composite resources

        .PARAMETER ModuleName
        Name of the new base module folder being created under C:\Program Files\WindowsPowerShell\Modules

        .PARAMETER ResourceName
        Name of the composite resource being created. Affects the directory structure and file names.

        .INPUTS
        None

        .OUTPUTS
        "C:\Program Files\WindowsPowerShell\Modules\$ModuleName"
        "$ModulePath\DSCResources"
        "$ModulePath\DSCResources\$ResourceName"
        "$ModulePath\$ModuleName.psd1"
        "$ResourcePath\$ResourceName.psd1"
        "$ResourcePath\$ResourceName.schema.psm1"

        .NOTES
        Version:        1.0
        Author:         Joshua Barton (@foobartn)
        Creation Date:  11.9.2016
        Purpose/Change: Initial script development
        
        .EXAMPLE
        Create a new module named MyDscResources
        Create a new composite resource under that module named MyCompositeResource

        New-DscCompositeResource -ModuleName MyDscResources -ResourceName MyCompositeResource
    #>


    param (
        # Name of module folder to create
        [Parameter(Mandatory=$true)]
        [string]
        $ModuleName,

        # Name of composite resource to create
        [Parameter(Mandatory=$true)]
        [string]
        $ResourceName
    )

    $ModulePath = "C:\Program Files\WindowsPowerShell\Modules\$ModuleName"
    $ResourcePath = "$ModulePath\DSCResources\$ResourceName"
    $ResourceSchemaPath = "$ResourcePath\$ResourceName.schema.psm1"
    $DscResourcePath = "$ModulePath\DSCResources"

    # Create Directory Structure
    New-Item -Path @($ModulePath,$DscResourcePath,$ResourcePath) -ItemType Directory

    # Add Base Module Manifest
    New-ModuleManifest -RootModule $ModuleName –Path "$ModulePath\$ModuleName.psd1"

    # Add Composite Resource Files
    New-Item –Path $ResourceSchemaPath -ItemType File
    New-ModuleManifest  -RootModule "$ResourceName.schema.psm1" –Path "$ResourcePath\$ResourceName.psd1"

    # Add Base Content to Resource
    Add-Content -Path $ResourceSchemaPath -Value "configuration $ResourceName {"
    Add-Content -Path $ResourceSchemaPath -Value "}"
}
