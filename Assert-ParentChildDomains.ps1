$secpasswd = ConvertTo-SecureString "Adrumble@6" -AsPlainText -Force
$domainCred = New-Object System.Management.Automation.PSCredential ("sva-dscdom\Administrator", $secpasswd)
$safemodeAdministratorCred = New-Object System.Management.Automation.PSCredential ("sva-dscdom\Administrator", $secpasswd)
$localcred = New-Object System.Management.Automation.PSCredential ("Administrator", $secpasswd)
$redmondCred = Get-Credential -Message "Enter Credentials for DNS Delegation: "
$newpasswd = ConvertTo-SecureString "Adrumble@7" -AsPlainText -Force
$userCred = New-Object System.Management.Automation.PSCredential ("sva-dscdom\Administrator", $newpasswd)

configuration AssertParentChildDomains
{

    Import-DscResource -ModuleName msActiveDirectory

    Node $AllNodes.Where{$_.Role -eq "Parent DC"}.Nodename
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

    Node $AllNodes.Where{$_.Role -eq "Child DC"}.Nodename
    {
        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }

        msWaitForADDomain DscForestWait
        {
            DomainName = $Node.ParentDomainName
            DomainUserCredential = $domaincred
	    RetryCount = $Node.RetryCount
            RetryIntervalSec = $Node.RetryIntervalSec
            DependsOn = "[WindowsFeature]ADDSInstall"
        }

        msADDomain ChildDS
        {
            DomainName = $Node.DomainName
            ParentDomainName = $Node.ParentDomainName
            DomainAdministratorCredential = $domaincred
            SafemodeAdministratorPassword = $safemodeAdministratorCred
            DependsOn = "[msWaitForADDomain]DscForestWait"
        }
    }
}

$config = Invoke-Expression (Get-content $PSScriptRoot\ParentChildconfig.psd1 -Raw)
AssertParentChildDomains -configurationData $config

Start-DscConfiguration -Wait -Force -Verbose -ComputerName "sva-dsc1" -Path $PSScriptRoot\AssertParentChildDomains -Credential $localcred
Start-DscConfiguration -Wait -Force -Verbose -ComputerName "sva-dsc2" -Path $PSScriptRoot\AssertParentChildDomains -Credential $localcred
