<#
Set-Timezone.ps1

Author: Jeroen Bakker
Version 2.0

Sets the initial timezone for a device. Users are allowed to change the timezone.
Do not use any additional timezone related settings; Timezone settings in configuration profiles lock the setting.

To be used as an intune platform script.

Note: Use the following powershell command to list all valid timezones:
Get-TimeZone -ListAvailable|Out-GridView

Version history
---------------
Version 1.0: 23-10-2023: Initial production version
Version 2.0: 05-04-2024: Generalized script for reuse and distribution

#>

set-strictmode -Version latest

#region Configurable variables

# Set the default initial timezone for devices
$TimezoneID = 'W. Europe Standard Time'

#endregion


$LogFile = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Set-TimeZone_$(get-date -format yyyyMMdd_HHmmss).txt"

Start-Transcript -Path $LogFile

#Get current timezone
Get-timezone

Set-Timezone -Id 'W. Europe Standard Time' -PassThru


Stop-Transcript