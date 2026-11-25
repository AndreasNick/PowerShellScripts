@{
    # Package identity (MSIX PackageName: letters, digits, dots, hyphens only)
    PackageName        = 'RuRStudio'
    PackageDisplayName = 'R und RStudio'
    # Taken from the RStudio installer ProductVersion (2026.11.0.0); R is 4.6.2
    Version            = '2026.11.0.0'
    # Two installers -> wrapper script in Sources\ installs R first, then RStudio
    Installer          = 'Install-RuRStudio.cmd'
    Arguments          = ''
}
