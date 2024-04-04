<#
Set-Hostname_Detection.ps1

Author: Jeroen Bakker
Version 2.0

Detect if the hostname is configured as desired.
To be used as a detection script in intune

Output:
    Desired state: none (exit code = 0)
    Remediation needed: exit code = 1


Hostnme formatting:
Asset Tag hostname format: Prefix + Asset tag value
BIOS hostname format: SN<Serial> (serial truncated at 13 characters, only alphanumerical characters and hyphens allowed)

If neither asset tag and serial are valid for hostname, a random 8 digit number is generated and prefixed with 'RAN'

Version history
---------------
Version 1.0: 10-10-2023: Initial production version
Version 2.0: 04-04-2024: Generalized script for reuse and distribution


#>


set-strictmode -Version latest

#region Configurable variables

# Prefix to use for hostnames. The prefix must be an empty string if the asset tag value is the full hostname.
$NamePrefix = 'Prefix'

# Regex string to verify validity of the asset tag. Default: 6 digit numerical value.
$AssetRegex = '^\d{6}$'

# Regex string to verify validity of the full hostname (prefix + asset tag).
$NameRegex = '^Prefix\d{6}$'

#endregion

#Write-log function with CMTrace output format
function Write-log {
# Source: https://janikvonrotz.ch/2017/10/26/powershell-logging-in-cmtrace-format/
    [CmdletBinding()]
    Param(
          [parameter(Mandatory=$true)]
          [String]$Path,

          [parameter(Mandatory=$true)]
          [String]$Message,

          [parameter(Mandatory=$true)]
          [String]$Component,

          [Parameter(Mandatory=$true)]
          [ValidateSet("Info", "Warning", "Error")]
          [String]$Type
    )

    switch ($Type) {
        "Info" { [int]$Type = 1 }
        "Warning" { [int]$Type = 2 }
        "Error" { [int]$Type = 3 }
    }

    # Create a log entry
    $Content = "<![LOG[$Message]LOG]!>" +`
        "<time=`"$(Get-Date -Format "HH:mm:ss.ffffff")`" " +`
        "date=`"$(Get-Date -Format "M-d-yyyy")`" " +`
        "component=`"$Component`" " +`
        "context=`"$([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " +`
        "type=`"$Type`" " +`
        "thread=`"$([Threading.Thread]::CurrentThread.ManagedThreadId)`" " +`
        "file=`"`">"

    # Write the line to the log file
    Add-Content -Path $Path -Value $Content
}


# Start log and transcript
$LogFile = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Set-Hostname_Detection.log'

Write-log -Path $LogFile -Component Detection -Type Info -Message '*************************************************'

# Write hostname prefix to log
Write-log -Path $LogFile -Component Initialization -Type Info -Message "Hostname prefix: $NamePrefix"

# Write current hostname to log
Write-log -Path $LogFile -Component Detection -Type Info -Message "Current hostname: $env:COMPUTERNAME"

# Test if a pending rename action is still waiting for a reboot: This is the default state directly after succesfull remediation
$PendingName = Get-ItemPropertyValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName' -Name 'ComputerName'
If ($env:COMPUTERNAME -ne $PendingName){
    # The new computername value in the registry does not match the current hostname, a rename action is pending. No change needed.
    Write-log -Path $LogFile -Component Change -Type info -Message "Pending name change to $PendingName detected. No action required"
    exit 0
}

# Get asset tag, remove all spaces and convert to UCase
$AssetTag = (Get-WmiObject -query "Select * from Win32_SystemEnclosure").SMBiosAssetTag.replace(' ','').ToUpper()

# Get serial, remove all spaces and convert to UCase, limit to 13 characters because of netbios name limits
$Serial = (Get-WmiObject -query "Select * from Win32_SystemEnclosure").SerialNumber.replace(' ','').ToUpper()

# Compose desired hostname based on available information

If ($AssetTag -and ($AssetTag -match $AssetRegex)){
    # Verify if asset tag is present and has a valid format ( for naming computers
    $NewHostName = $NamePrefix+$AssetTag
    $NewNameType = 'AssetTag'
}
ElseIf ($Serial -and ($Serial -match '^[A-Z0-9-]+$')){
    # Invalid or missing asset tag, use serial number with prefix 'SN' as name if valid and available
   
    # limit hostname to first 13 characters of serial because of netbios name limits
    If ($Serial.Length -le 13){
        $NewHostName = "SN$Serial"
    }
    Else {
        $NewHostName = "SN$($Serial.substring(0,13))"
    }
    $NewNameType = 'Serial'
}
Else {
    # no valid asset tag or serial, use a random 8 digit number with prefix 'RAN'
    $NewHostName = "RAN$(-join ((48..57)|Get-Random -count 8| % {[char]$_}))"
    $NewNameType = 'Random'
 }


If ($NewHostName -eq $env:COMPUTERNAME){
    # "Hostnames match, no change needed"
    $ChangeNeeded = $False
}
ElseIf (($env:COMPUTERNAME -match $NameRegex) -And ($NewNameType -ne 'AssetTag')) {
    # "Old name is in valid assettag format, the new name is not; Assuming current hostname is correct"
    $ChangeNeeded = $False
}
ElseIf (($env:COMPUTERNAME -match $NameRegex) -And ($NewNameType -eq 'AssetTag')) {
    # "Old name and desired name have valid assettag format but do not match; Changing name to match BIOS assettag"
    $ChangeNeeded = $True

}
ElseIf (($env:COMPUTERNAME -match '^RAN\d{8}$') -And ($NewNameType -eq 'Random')) {
    # "Old name and desired name are of the Random type; Not changing the current name"
    $ChangeNeeded = $False
}
Else {
    #"Old and desired name do not match; Hostname change is needed"
    $ChangeNeeded = $True
}


If ($ChangeNeeded){
    # Hostname change is needed, exit script with error code 1 to trigger remediation
    Write-log -Path $LogFile -Component Change -Type info -Message "The hostname will be changed to $NewHostname of type $NewNameType"
    exit 1
}
Else {
    Write-log -Path $LogFile -Component Detection -Type info -Message "Hostname is as desired, no change needed"
}