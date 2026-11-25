@echo off
rem Silent all-users install of R and RStudio for the MSIX capture of RuRStudio.
rem Runs inside the elevated MSIX Packaging Tool session on the packaging machine.
rem Logs go to %TEMP% (exclude from the capture: [{Local AppData}]\Temp).
setlocal
set "LOG=%TEMP%\Install-RuRStudio.log"
echo %DATE% %TIME% start > "%LOG%"

rem R 4.6.2 - Inno Setup 6.1.0
rem /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /LOG : Inno Setup command-line help (jrsoftware.org)
rem /ALLUSERS : Inno Setup admin install mode -> Program Files (R FAQ 2.4 lists /CURRENTUSER, so the override is enabled)
start "" /wait "%~dp0R-4.6.2-win.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP- /ALLUSERS /LOG="%TEMP%\R-4.6.2-install.log"
set "RC=%ERRORLEVEL%"
echo %DATE% %TIME% R-4.6.2 exit %RC% >> "%LOG%"
if not "%RC%"=="0" exit /b %RC%

rem RStudio 2026.11.0-203 - NSIS 3.12 with NsisMultiUser
rem /S : NSIS silent switch (case-sensitive); NSIS never reboots unless the script asks
rem /allusers : NsisMultiUser all-users mode -> $PROGRAMFILES64\RStudio (rstudio NSIS.template.in)
start "" /wait "%~dp0RStudio-2026.11.0-203.exe" /S /allusers
set "RC=%ERRORLEVEL%"
echo %DATE% %TIME% RStudio-2026.11.0-203 exit %RC% >> "%LOG%"
exit /b %RC%
