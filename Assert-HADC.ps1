# A configuration to Create High Availability Domain Controller 

$secpasswd = ConvertTo-SecureString "Adrumble@6" -AsPlainText -Force
$domainCred = New-Object System.Management.Automation.PSCredential ("sva-dscdom\Administrator", $secpasswd)
$safemodeAdministratorCred = New-Object System.Management.Automation.PSCredential ("sva-dscdom\Administrator", $secpasswd)
$localcred = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)
$redmondCred = Get-Credential -Message "Enter Credentials for DNS Delegation: "
$newpasswd = ConvertTo-SecureString "Adrumble@7" -AsPlainText -Force
$userCred = New-Object System.Management.Automation.PSCredential ("sva-dscdom\Administrator", $newpasswd)

configuration AssertHADC
{
    Import-DscResource -ModuleName msActiveDirectory

    Node $AllNodes.Where{$_.Role -eq "Primary DC"}.Nodename
    {
        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        msADDomain FirstDS
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domaincred
            SafemodeAdministratorPassword = $safemodeAdministratorCred
            DnsDelegationCredential = $redmondCred
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        msWaitForADDomain DscForestWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $domaincred
            RetryCount = $Node.RetryCount
            RetryIntervalSec = $Node.RetryIntervalSec
            DependsOn = "[msADDomain]FirstDS"
        }

        msADUser FirstUser
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domaincred
            UserName = "dummy"
            Password = $userCred
            Ensure = "Present"
            DependsOn = "[msWaitForADDomain]DscForestWait"
        }

    }

    Node $AllNodes.Where{$_.Role -eq "Replica DC"}.Nodename
    {
        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        msWaitForADDomain DscForestWait
        {
            DomainName = $Node.DomainName
            DomainUserCredential = $domaincred
	    RetryCount = $Node.RetryCount
            RetryIntervalSec = $Node.RetryIntervalSec
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        msADDomainController SecondDC
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domaincred
            SafemodeAdministratorPassword = $safemodeAdministratorCred
            DependsOn = "[msWaitForADDomain]DscForestWait"
        }
    }
}

$config = Invoke-Expression (Get-content $PSScriptRoot\HADCconfiguration.psd1 -Raw)
AssertHADC -configurationData $config

Start-DscConfiguration -Wait -Force -Verbose -ComputerName "sva-dsc1" -Path $PSScriptRoot\AssertHADC -Credential $localcred
Start-DscConfiguration -Wait -Force -Verbose -ComputerName "sva-dsc2" -Path $PSScriptRoot\AssertHADC -Credential $localcred