<#
Set-Hostname_Remediation.ps1

Author: Jeroen Bakker
Version 2.0

Change the device hostname to the desired format for Intune managed devices
Input:
    BIOS AssetTag value: prefered hostname
    Bios Serial number value: Alternate hostname

Output:
    Transcript and logfile in C:\ProgramData\Microsoft\IntuneManagementExtension\Logs folder.


Hostnme formatting:
Asset Tag hostname format: Prefix + Asset tag value
BIOS hostname format: SN<Serial> (serial truncated at 13 characters, only alphanumerical characters and hyphens allowed)

If neither asset tag and serial are valid for hostname used a random 8 digit number is generated and prefixed with 'RAN'

Usage:
1) Script can be used as a Powershell remediation script in Intune together with a matching detection script.
2) Script can be used as a Powershell platform script (Runs only once) in Intune

Note:
Succesfully changing the hostname requires a reboot after script completion, this is not forced or advertised to users.

Version history
---------------
Version 1.0: 22-09-2023: Initial production version
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
$LogFile = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Set-Hostname_Remediation.log'
$Transcript = 'C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Set-Hostname_Remediation_Transcript.txt'

Write-log -Path $LogFile -Component Initialization -Type Info -Message '*************************************************'
Write-log -Path $LogFile -Component Initialization -Type Info -Message $PSCommandPath
Write-log -Path $LogFile -Component Initialization -Type Info -Message 'Starting hostname verification and remediation script'

Start-Transcript -Append

# Write hostname prefix to log
Write-log -Path $LogFile -Component Initialization -Type Info -Message "Hostname prefix: $NamePrefix"

# Write current hostname to log
Write-log -Path $LogFile -Component Initialization -Type Info -Message "Current hostname: $env:COMPUTERNAME"

# Get asset tag, remove all spaces and convert to UCase
$AssetTag = (Get-WmiObject -query "Select * from Win32_SystemEnclosure").SMBiosAssetTag.replace(' ','').ToUpper()
Write-log -Path $LogFile -Component Initialization -Type Info -Message "BIOS AssetTag: $AssetTag"

# Get serial, remove all spaces and convert to UCase, limit to 13 characters because of netbios name limits
$Serial = (Get-WmiObject -query "Select * from Win32_SystemEnclosure").SerialNumber.replace(' ','').ToUpper()
Write-log -Path $LogFile -Component Initialization -Type Info -Message "Device serial: $Serial"


# Compose desired hostname based on available information
Write-log -Path $LogFile -Component Build -Type Info -Message "Start composing the desired hostname from BIOS information"

If ($AssetTag -and ($AssetTag -match $AssetRegex)){
    # Verify if asset tag is present and has a valid format (WKS######) for naming computers
    Write-log -Path $LogFile -Component Build -Type Info -Message "The assettag is valid, using assettag value as base for the hostname"
    $NewHostName = $NamePrefix+$AssetTag
    $NewNameType = 'AssetTag'
}
ElseIf ($Serial -and ($Serial -match '^[A-Z0-9-]+$')){
    # Invalid or missing asset tag, use serial number with prefix 'SN' as name if valid and available
    Write-log -Path $LogFile -Component Build -Type warning -Message "The assettag $AssetTag is empty or invalid as hostname"
    Write-log -Path $LogFile -Component Build -Type info -Message "The serial is a valid alternate hostname"
    
    # limit hostname to first 13 characters of serial because of netbios name limits
    If ($Serial.Length -le 13){
        Write-log -Path $LogFile -Component Build -Type info -Message "The serial is 13 characters or less in length, using full serial for hostname"
        $NewHostName = "SN$Serial"
    }
    Else {
        Write-log -Path $LogFile -Component Build -Type warning -Message "The serial has a length of more then 13 characters, truncating serial at 13 chars"
        $NewHostName = "SN$($Serial.substring(0,13))"
    }
    $NewNameType = 'Serial'
}
Else {
    # no valid asset tag or serial, use a random 8 digit number with prefix 'RAN'
    Write-log -Path $LogFile -Component Build -Type error -Message "No valid assettag or serial detected for use as hostname, using random 8 digit string as hostname"
    $NewHostName = "RAN$(-join ((48..57)|Get-Random -count 8| % {[char]$_}))"
    $NewNameType = 'Random'
 }


Write-log -Path $LogFile -Component Build -Type info -Message "Using $NewHostName of type $NewNameType as desired new hostname"
Write-log -Path $LogFile -Component Change -Type info -Message "Comparing current hostname with desired hostname to decide on change"

If ($NewHostName -eq $env:COMPUTERNAME){
    Write-log -Path $LogFile -Component Change -Type info -Message "Hostnames match, no change needed"
    $ChangeNeeded = $False
}
ElseIf (($env:COMPUTERNAME -match $NameRegex) -And ($NewNameType -ne 'AssetTag')) {
    Write-log -Path $LogFile -Component Change -Type info -Message "Old name is in valid assettag format, the new name is not; Assuming current hostname is correct"
    $ChangeNeeded = $False
}
ElseIf (($env:COMPUTERNAME -match $NameRegex) -And ($NewNameType -eq 'AssetTag')) {
    Write-log -Path $LogFile -Component Change -Type info -Message "Old name and desired name have valid assettag format but do not match; Changing name to match BIOS assettag"
    $ChangeNeeded = $True

}
ElseIf (($env:COMPUTERNAME -match '^RAN\d{8}$') -And ($NewNameType -eq 'Random')) {
    Write-log -Path $LogFile -Component Change -Type info -Message "Old name and desired name are of the Random type; Not changing the current name"
    $ChangeNeeded = $False
}
Else {
    Write-log -Path $LogFile -Component Change -Type info -Message "Old and desired name do not match; Hostname change is needed"
    $ChangeNeeded = $True
}


If ($ChangeNeeded){
    Write-log -Path $LogFile -Component Change -Type info -Message "The hostname will be changed to $NewHostname"
    $Result = Rename-Computer -NewName $NewHostName -Force -PassThru
    If ($Result.HasSucceeded){
        Write-log -Path $LogFile -Component Change -Type info -Message "Hostname change has succeeded, a reboot may be required to complete the change"
    }
    Else {
        Write-log -Path $LogFile -Component Change -Type error -Message "Hostname change failed; Check $Transcript for more details"
    }


}


Write-log -Path $LogFile -Component Completion -Type info -Message 'Ending hostname verification and remediation script'

Stop-Transcript