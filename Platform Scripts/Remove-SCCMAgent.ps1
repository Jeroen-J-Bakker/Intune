<#
Remove-SCCMAgent.ps1

Combined script created by: Jeroen Bakker
Version 2.0
Date: 19-12-2023

    Added transcript
    Replaced incorrect smart/ curly quotes with straight/dumb quotes
    Added delayed restart of "Microsoft Intune Management Extension" service at end of script through rewrite of Michael Mardahl's script

############
Credits:

SCCM client removal script:        
Author: Rob Moir 
Source: https://github.com/robertomoir/remove-sccm

Inspiration for delayed service restart:
Michael Mardahl - @michael_mardahl on twitter - BLOG: https://www.iphase.dk
Source: https://www.iphase.dk/hacking-intune-management-extension/
        https://github.com/mardahl/forgetMeMethod_Intune/blob/master/forgetMeMethod.ps1


Version history
---------------
Version 1.0: 19-12-2023: Initial version
Version 2.0: 12-04-2024: Generalized script for reuse and distribution

#>

# Transcript
Start-Transcript -Append -Path 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Remove-SCCMAgent_Transcript.txt'


# Run SSCM remove
# $ccmpath is path to SCCM Agent's own uninstall routine.
$CCMpath = 'C:\Windows\ccmsetup\ccmsetup.exe'
# And if it exists we will remove it, or else we will silently fail.
if (Test-Path $CCMpath) {

    Start-Process -FilePath $CCMpath -Args "/uninstall" -Wait -NoNewWindow
    # wait for exit

    $CCMProcess = Get-Process ccmsetup -ErrorAction SilentlyContinue

        try{
            $CCMProcess.WaitForExit()
            }catch{
 

            }
}


# Stop Services
Stop-Service -Name ccmsetup -Force -ErrorAction SilentlyContinue
Stop-Service -Name CcmExec -Force -ErrorAction SilentlyContinue
Stop-Service -Name smstsmgr -Force -ErrorAction SilentlyContinue
Stop-Service -Name CmRcService -Force -ErrorAction SilentlyContinue

# wait for services to exit
$CCMProcess = Get-Process ccmexec -ErrorAction SilentlyContinue
try{

    $CCMProcess.WaitForExit()

}catch{


}

 
# Remove WMI Namespaces
Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='ccm'" -Namespace root | Remove-WmiObject
Get-WmiObject -Query "SELECT * FROM __Namespace WHERE Name='sms'" -Namespace root\cimv2 | Remove-WmiObject

# Remove Services from Registry
# Set $CurrentPath to services registry keys
$CurrentPath = "HKLM:\SYSTEM\CurrentControlSet\Services"
Remove-Item -Path $CurrentPath\CCMSetup -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\CcmExec -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\smstsmgr -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\CmRcService -Force -Recurse -ErrorAction SilentlyContinue

# Remove SCCM Client from Registry
# Update $CurrentPath to HKLM/Software/Microsoft
$CurrentPath = "HKLM:\SOFTWARE\Microsoft"
Remove-Item -Path $CurrentPath\CCM -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\CCMSetup -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\SMS -Force -Recurse -ErrorAction SilentlyContinue

# Reset MDM Authority
# CurrentPath should still be correct, we are removing this key: HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\DeviceManageabilityCSP
Remove-Item -Path $CurrentPath\DeviceManageabilityCSP -Force -Recurse -ErrorAction SilentlyContinue

# Remove Folders and Files
# Tidy up garbage in Windows folder
$CurrentPath = $env:WinDir
Remove-Item -Path $CurrentPath\CCM -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\ccmsetup -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\ccmcache -Force -Recurse -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\SMSCFG.ini -Force -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\SMS*.mif -Force -ErrorAction SilentlyContinue
Remove-Item -Path $CurrentPath\SMS*.mif -Force -ErrorAction SilentlyContinue


# Restart Microsoft Intune Management Extension service in a delayed child process
# Restarting the service speeds up Intune policy retreival and subsequent software installation


    # the delete registry key script (don't tab this code, it will break)
$RestartScript = @'
$Transcript = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Restart_ime_Transcript.txt'
start-transcript;
Start-Sleep -Seconds 90;
Restart-Service -Name IntuneManagementExtension -Force -ErrorAction SilentlyContinue
Stop-Transcript;
'@

    $RestartScriptName = "c:\windows\temp\Restart_IME.ps1"
    $RestartScript | Out-File $RestartScriptName -Force

    # starting a seperate powershell process that will wait 90 seconds before restarting the IME Service.
    $RestartProcess = New-Object System.Diagnostics.ProcessStartInfo "Powershell";
    $RestartProcess.Arguments = "-File " + $RestartScriptName
    $RestartProcess.Verb = "runas";
    [System.Diagnostics.Process]::Start($RestartProcess);



Stop-Transcript
Exit