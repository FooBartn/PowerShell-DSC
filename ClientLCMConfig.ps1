[DscLocalConfigurationManager()]
Configuration ClientLCMConfig
{
    param  
    ( 
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [guid]$RegistrationKey
    )

    Node localhost
    {
        Settings
        {
            RefreshFrequencyMins            = 30;
            RefreshMode                     = "PULL";
            ConfigurationMode               = "ApplyAndAutocorrect";
            AllowModuleOverwrite            = $true;
            RebootNodeIfNeeded              = $false;
            ConfigurationModeFrequencyMins  = 60;
        }
        ConfigurationRepositoryWeb Lab-PullSrv
        {
            ServerURL                       = 'https://dscpull.testlab.myorg:8080/PSDSCPullServer.svc'    
            RegistrationKey                 = $RegistrationKey    
            ConfigurationNames              = @(
                                                    "Base",
                                                    "Extra"
                                                )
        }     

        PartialConfiguration Base
        {
            Description                     = "Base configuration"
            ConfigurationSource             = @("[ConfigurationRepositoryWeb]Lab-PullSrv") 
        }

        PartialConfiguration Extra
        {
            Description                     = "Extra configuration"
            ConfigurationSource             = @("[ConfigurationRepositoryWeb]Lab-PullSrv")
            DependsOn                       = '[PartialConfiguration]Base'
        }
    }
}

[guid]$RegistrationKey = '' #Enter Reg Key

# Generate MOF
New-Item -Path 'D:\PSDSC' -ItemType Directory -Force
StandardClientConfiguration -OutputPath 'D:\PSDSC' -RegistrationKey $RegistrationKey -Verbose
