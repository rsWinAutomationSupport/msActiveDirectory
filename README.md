msActiveDirectory
=================

Updated to Microsoft module v2.2<br/>
Note that class names have been renamed from 'x' to 'ms'

Usage:
<pre>
        WindowsFeature ADDSInstall
        {
            Ensure = "Present"
            Name = "AD-Domain-Services"
        }
        msADDomain FirstDS
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domainCred
            SafemodeAdministratorPassword = $safemodeAdministratorCred
            DnsDelegationCredential = $DNSDelegationCred
            DependsOn = "[WindowsFeature]ADDSInstall"
        }
</pre>
