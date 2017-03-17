configuration ConfigurePullServer
{
    param  
    ( 
        [string[]]$NodeName = 'localhost', 

        [ValidateNotNullOrEmpty()] 
        [string] $certificateThumbPrint,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $RegistrationKey,

        [Parameter(Mandatory)]
        [PsCredential]
        $AdminCredential,

        [Parameter(Mandatory)]
        [string]
        $IPAddress,

        [Parameter(Mandatory)]
        [int]
        $SubnetPrefixLength,

        [Parameter(Mandatory)]
        [string]
        $OUPath,

        [Parameter(Mandatory)]
        [string]
        $DomainName
     )
     
    # Modules must exist on target pull server
    Import-DSCResource -ModuleName xPSDesiredStateConfiguration
    Import-DSCResource –ModuleName PSDesiredStateConfiguration
    Import-DscResource -Module xActiveDirectory,xNetworking
    Import-DscResource -Module xComputerManagement,xStorage

    Node $AllNodes.NodeName
    {
        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyAndMonitor'                   
        }

        User AdminUser
        {
            UserName = $AdminCredential.UserName
            Ensure = 'Present'
            Password = $AdminCredential
        }

        Script ChangeCDROMDriveLetter 
        {
            GetScript = {
                @{
                    GetScript = $GetScript
                    SetScript = $SetScript
                    TestScript = $TestScript
                    Result = (Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'D:'").DriveType -ne 5
                }           
            }
                    
            SetScript = {
                Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'D:'" | 
                    Set-CimInstance -Property @{ DriveLetter = "Z:" }
            }

            TestScript = {
                $Status = (Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'D:'").DriveType -ne 5
                $Status -eq $True
            }
        }

        xWaitforDisk Disk1
        {
             DiskNumber = 1
             RetryIntervalSec =$RetryIntervalSec
             RetryCount = $RetryCount
        }

        xDisk DataVol
        {
            DiskNumber = 1
            DriveLetter = 'D'
        }

        xIPAddress NewIPAddress
        {
            IPAddress      = $IPAddress
            InterfaceAlias = 'Ethernet'
            PrefixLength     = $SubnetPrefixLength
            AddressFamily  = 'IPV4'
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = '192.168.1.250'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn = "[xIPAddress]NewIPAddress"
        }

        WindowsFeature DSCServiceFeature
        {
            Ensure = "Present"
            Name   = "DSC-Service"
        }

        WindowsFeature IISConsole {
            Ensure = "Present"
            Name   = "Web-Mgmt-Console"
        }

        xDscWebService PSDSCPullServer
        {
            Ensure                  = "Present"
            EndpointName            = "PSDSCPullServer"
            Port                    = 8080
            PhysicalPath            = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer"
            CertificateThumbPrint   = "AllowUnencryptedTraffic"
            ModulePath              = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
            ConfigurationPath       = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
            State                   = "Started"
            DependsOn               = "[WindowsFeature]DSCServiceFeature"
            UseSecurityBestPractices = $false
        }
        
        File RegistrationKeyFile
        {
            Ensure          ='Present'
            Type            = 'File'
            DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
            Contents        = $RegistrationKey
        }

        xComputer JoinDomain  
        {
            Name = $NodeName
            DomainName = $DomainName
            Credential = $AdminCredential
            JoinOU = $OUPath
            DependsOn = "[xDNSServerAddress]DnsServerAddress"
        }
    }
}

$RegistrationKey = [guid]::NewGuid()
$AdminPW = ConvertTo-SecureString 'Adminin@tor!' -AsPlainText -Force
$AdminCredential = [PSCredential]::new('testlab\Administrator',$AdminPW)

$configData = @{
    AllNodes = @(
        @{
            NodeName = $env:ComputerName
            PSDscAllowPlainTextPassword = $true
        }
    )
}

$PullSvrParams = @{
    RegistrationKey = $RegistrationKey
    DomainName = 'testlab.myorg'
    AdminCredential = $AdminCredential
    IPAddress = '192.168.1.251'
    SubnetPrefixLength = 24
    OUPath = 'OU=Administrative,OU=Servers,DC=testlab,DC=myorg'
    ConfigurationData = $configData
}

# Generate MOF
ConfigurePullServer @PullSvrParams
Start-DscConfiguration -Path .\ConfigurePullServer -Wait -Verbose -Force -Debug
