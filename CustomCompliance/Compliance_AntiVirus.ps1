<#
Compliance_AntiVirus.ps1
Custom compliance detection script for Intune

Author: Jeroen Bakker
Version 2.0

Detects the Antivirus product name, if it is active and up-to-date, and the last update time.
If multiple products are detected it will output the active product or, if there is no active product, the last one in the array

To be used if third party Anti Malware is used.
Custom compliance JSON file can compare active AV against expected product name as registerd in Security Center

Version history
---------------
Version 1.0: 22-03-2024: Initial production version
Version 2.0: 04-04-2024: Generalized script for reuse and distribution


#>


Class AVInfo{
    [String]$AntiVirusProductName
    [String]$Active
    [Boolean]$UptoDate
    [DateTime]$LastUpdateTime
}


# Collect Antivirus protection data from WMI
$result = @(Get-CimInstance -Namespace 'ROOT\SecurityCenter2' -ClassName AntiVirusProduct)


If ($result.count -eq 0){
    # No AntiVirusProduct detected
    $AvInfo = New-Object -TypeName AVInfo
    $AvInfo.AntiVirusProductName = 'No product detected'
    $AvInfo.Active = 'Unknown'
    $AvInfo.UptoDate = 'Unknown'
    }
ElseIf ($result.count -eq 1){
    # A single product is detected
    $AvInfo = New-Object -TypeName AVInfo
    $AvInfo.AntiVirusProductName = $result.displayname
    $AvInfo.LastUpdateTime = $result.timestamp
    $StateConvert = [System.Convert]::ToString($result.productState,16).padleft(6,'0')

        Switch ($StateConvert.substring(2,1)){
            '0' {$AvInfo.Active = 'Off'}
            '1' {$AvInfo.Active = 'On'}
            '2' {$AvInfo.Active = 'Snoozed'}
            '3' {$AvInfo.Active = 'Expired'}
            Default {$AvInfo.Active = 'Unknown'}
        }

        Switch ($StateConvert.substring(4,1)){
            '0' {$AvInfo.UptoDate = $true}
            '1' {$AvInfo.UptoDate = $False}
            Default {$AvInfo.Active = 'Unknown'}
        }
    }
Else {
    # Multiple products have been detected, determine product for reporting.
    #Report based on active product; if no active product is detected, report on last object in array
    $Result|Foreach-object{
        $StateConvert = [System.Convert]::ToString($_.productState,16).padleft(6,'0')
        If ($StateConvert.substring(2,1) -eq 1){
            $AvInfo = New-Object -TypeName AVInfo
            $AvInfo.AntiVirusProductName = $_.displayname
            $AvInfo.LastUpdateTime = $_.timestamp

            Switch ($StateConvert.substring(2,1)){
                '0' {$AvInfo.Active = 'Off'}
                '1' {$AvInfo.Active = 'On'}
                '2' {$AvInfo.Active = 'Snoozed'}
                '3' {$AvInfo.Active = 'Expired'}
                Default {$AvInfo.Active = 'Unknown'}
            }

            Switch ($StateConvert.substring(4,1)){
                '0' {$AvInfo.UptoDate = $true}
                '1' {$AvInfo.UptoDate = $False}
                Default {$AvInfo.Active = 'Unknown'}
            }
        }
    }
     
    If (!$AvInfo){
        #No active product detected report on last in array
        $AvInfo = New-Object -TypeName AVInfo
        $AvInfo.AntiVirusProductName = $Result[-1].displayname
        $AvInfo.LastUpdateTime = $Result[-1].timestamp
        $StateConvert = [System.Convert]::ToString($Result[-1].productState,16).padleft(6,'0')

            Switch ($StateConvert.substring(2,1)){
                '0' {$AvInfo.Active = 'Off'}
                '1' {$AvInfo.Active = 'On'}
                '2' {$AvInfo.Active = 'Snoozed'}
                '3' {$AvInfo.Active = 'Expired'}
                Default {$AvInfo.Active = 'Unknown'}
            }

            Switch ($StateConvert.substring(4,1)){
                '0' {$AvInfo.UptoDate = $true}
                '1' {$AvInfo.UptoDate = $False}
                Default {$AvInfo.Active = 'Unknown'}
            }
    }
 }




Return $AVInfo|convertto-json -Compress