@{
    # New package (no previous version). Name: letters/digits only.
    PackageName        = 'LibreOffice'
    PackageDisplayName = 'LibreOffice 26.8'
    # ProductVersion from the MSI Property table (26.8.2.2), already four parts
    Version            = '26.8.2.2'
    # Single MSI -> no wrapper script
    Installer          = 'LibreOffice_26.8.2_Win_x86-64.msi'
    # Sources: msiexec / Windows Installer (Microsoft Learn), MSI Property/Feature/Component tables of this MSI.
    # Run 1 used REMOVE=gm_o_Onlineupdate,gm_o_Quickstart: a feature property on the command line disables the default
    # feature selection -> nothing was installed (event 1033 status 0 after 2 s, no files). REMOVE dropped;
    # ISCHECKFORPRODUCTUPDATES=0 (online update components are conditioned on it) and QUICKSTART=0 replace it.
    # No /L*v: the MSIX Packaging Tool appends its own /le log, the last /L wins.
    Arguments          = '/qn /norestart ALLUSERS=1 REBOOT=ReallySuppress RebootYesNo=No ISCHECKFORPRODUCTUPDATES=0 QUICKSTART=0 CREATEDESKTOPLINK=0 VC_REDIST=1'
}
