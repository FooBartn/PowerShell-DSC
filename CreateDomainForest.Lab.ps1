configuration CreateDomainForest
{
    param
    (
        [string[]]
        $NodeName ='localhost',
        
        [Parameter(Mandatory)]
        [PSCredential]
        $AdminCredential,

        [Parameter(Mandatory)]
        [string]
        $DomainName,

        [Parameter(Mandatory)]
        [PSCredential]
        $SafeModeCredential,

        [Parameter(Mandatory)]
        [string]
        $IPAddress,

        [Parameter(Mandatory)]
        [int]
        $SubnetPrefixLength,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    )
     
    # Modules must exist on target pull server
    Import-DscResource -Module xActiveDirectory,xNetworking
    Import-DscResource -Module xComputerManagement, xStorage

    # Create $DomainCredential from $AdminCredential
    $DomainUser = "$DomainName\$($AdminCredential.Username)"
    $DomainCredential = [PSCredential]::new($DomainUser,$AdminCredential.Password)

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
                    Result = (Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'D:'").DriveType -ne 5
                }           
            }
                    
            SetScript = {
                Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'D:'" | 
                    Set-CimInstance -Property @{ DriveLetter = "Z:" }
            }

            TestScript = {
                (Get-CimInstance -ClassName Win32_Volume -Filter "DriveLetter = 'D:'").DriveType -ne 5
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

        WindowsFeature ADDSInstall
        { 
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
            IncludeAllSubFeature = $true
        }

        WindowsFeature RSATTools
        {
            Ensure = 'Present'
            Name = 'RSAT-AD-Tools'
            IncludeAllSubFeature = $true
        }

        xIPAddress NewIPAddress
        {
            IPAddress      = $IPAddress
            InterfaceAlias = 'Ethernet'
            PrefixLength     = $SubnetPrefixLength
            AddressFamily  = 'IPV4'
        }

        WindowsFeature DNS
        {
            Ensure = 'Present'
            Name = 'DNS'
        }

        xDnsServerAddress DnsServerAddress
        {
            Address        = '127.0.0.1'
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
        }

        xADDomain NewDscForest
        {
            DomainName= $DomainName
            DomainAdministratorCredential= $AdminCredential
            SafemodeAdministratorPassword= $SafeModeCredential
            DatabasePath = 'D:\NTDS'
            LogPath = 'D:\NTDS'
            SysvolPath = 'D:\SYSVOL'
            DependsOn=@(
                '[WindowsFeature]ADDSInstall',
                '[xDnsServerAddress]DnsServerAddress',
                '[xDisk]DataVol'
            )
        }
    }
}

$SafeModePW = ConvertTo-SecureString 'InCaseOfFireBreakGlass1!' -AsPlainText -Force
$SafeModeCredential = [PSCredential]::new('Administrator',$SafeModePW)
 
$AdminPW = ConvertTo-SecureString 'Adminin@tor!' -AsPlainText -Force
$AdminCredential = [PSCredential]::new('Administrator',$AdminPW)

$configData = @{
    AllNodes = @(
        @{
            NodeName = 'localhost';
            PSDscAllowPlainTextPassword = $true
        }
    )
}

$DCParams = @{
    AdminCredential = $AdminCredential
    DomainName = 'testlab.myorg'
    SafeModeCredential = $SafeModeCredential
    IPAddress = '192.168.1.250'
    SubnetPrefixLength = 24
    ConfigurationData = $configData
}

ConfigureFirstDomainController @DCParams
 
Start-DscConfiguration -Wait -Force -Verbose -path .\ConfigureFirstDomainController -Debug
