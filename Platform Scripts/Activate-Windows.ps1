<#
Activate-Windows.ps1

Author: Jeroen Bakker
Date: 15-11-2024
Version 1.0

Set the KMS server and license key
Activate Windows with an Enterprise license
Can be used as an Intune platform script

Note: Set the KMS server FQDN (and port) on line 25

Output:
    slmgr.vbs output is redirected to textfiles in the Intune Management Extension log folder
#>


Function Set-LogFile {
    #Set Log file location and name with timestamp in filename
    $LogFile = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\SLMGR_$(get-date -format yyyyMMdd_HHmmss).txt"
    $LogFile
}

#Set KMS server
start-process -FilePath cscript.exe -ArgumentList "slmgr.vbs /skms <Replace with server FQDN>:1688" -NoNewWindow -wait -RedirectStandardOutput $(Set-LogFile)

#Set KMS license key for Windows Enterprise
start-process -FilePath cscript.exe -ArgumentList "slmgr.vbs /ipk NPPR9-FWDCX-D2C8J-H872K-2YT43" -NoNewWindow -wait -RedirectStandardOutput $(Set-LogFile)

#Activate Windows
start-process -FilePath cscript.exe -ArgumentList "slmgr.vbs /ato" -NoNewWindow -wait -RedirectStandardOutput $(Set-LogFile)