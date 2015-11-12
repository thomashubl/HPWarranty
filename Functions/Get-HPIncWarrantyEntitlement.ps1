﻿Function Get-HPIncWarrantyEntitlement {
    
    [CmdletBinding(DefaultParameterSetName = '__AllParameterSets')]
    [OutputType([System.Management.Automation.PSCustomObject])]
    
	Param (
        [Parameter(
            ParameterSetName = 'Default',
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true
        )]
        [Alias(
            'Name'
        )]
        [ValidateScript({
            if ($_ -eq $env:COMPUTERNAME) { 
                $true 
            } else { 
                try { 
                    Test-Connection -ComputerName $_ -Count 1 -ErrorAction Stop
                    $true 
                } catch { 
                    throw "Unable to connect to $_." 
                }
            }
        })]
        [String[]]
        $ComputerName = $env:ComputerName,

		[Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipelineByPropertyName = $true
        )]
		[String]
        $ProductNumber,

        [Parameter(
            Mandatory = $true,
            ParameterSetName = 'Static',
            ValueFromPipelineByPropertyName = $true
        )]
		[String]
        $SerialNumber,

        [Parameter(
            ParameterSetName = '__AllParameterSets'
        )]
		[Parameter(
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
		[String]
        $CountryCode = 'US',

        [Parameter(
            ParameterSetName = '__AllParameterSets'
        )]
		[Parameter(
            ParameterSetName = 'Default'
        )]
        [Parameter(
            ParameterSetName = 'Static'
        )]
        [String]
        [ValidateNotNullOrEmpty()]
        $XmlExportPath = $null
	)

    Begin {
        $request = (Get-Content -Path "$PSScriptRoot\..\RequestTemplates\HPIncWarrantyEntitlement.xml").Replace(
            '<[!--EntitlementCheckDate--!]>', (Get-Date -Format 'yyyy-MM-dd')
        ).Replace(
            '<[!--CountryCode--!]>', $CountryCode
        )
    }

    Process {
        for ($i = 0; $i -lt $ComputerName.Length; $i++) {
            if (-not ($PSCmdlet.ParameterSetName -eq 'Static')) {
                if (($systemInformation = Get-HPProductNumberAndSerialNumber -ComputerName $ComputerName[$i]) -ne $null) {
                    $SerialNumber = $systemInformation.SerialNumber
                    $ProductNumber = $systemInformation.ProductNumber
                } else {
                    continue
                }
            }

            try {
                [xml]$entitlement = Invoke-RestMethod -Body $request.Replace(
                    '<[!--SerialNumber--!]>', $SerialNumber
                ).Replace(
                    '<[!--ProductNumber--!]>', $ProductNumber
                ) -Uri 'https://entitlement-ext.corp.hp.com/es/ES10_1/ESListener' -ContentType 'text/html' -Method Post -ErrorAction Stop
            } catch {
                Write-Error -Message 'Failed to invoke rest method.'
                continue
            }

            if ($entitlement -ne $null) {
                if ($entitlement.GetElementsByTagName('ErrorID').InnerText -ne $null) {
                    Write-Error -Message $($entitlement.GetElementsByTagName('DataPayLoad').InnerText) -ErrorId $($entitlement.GetElementsByTagName('ErrorID').InnerText)
                    continue
                } else {
                    if ($PSBoundParameters.ContainsKey('XmlExportPath')) {
                        try {
                            $entitlement.Save("${XmlExportPath}\${SerialNumber}_entitlement.xml")
                        } catch {
                            Write-Error -Message 'Failed to save xml file.'
                        }
                    }

                    [System.Management.Automation.PSCustomObject]([Ordered]@{
                        'ComputerName' = $ComputerName[$i]
                        'SerialNumber' = $SerialNumber
                        'ProductNumber' = $ProductNumber
                        'ProductLineDescription' = $entitlement.GetElementsByTagName('ProductLineDescription').InnerText
                        'ProductLineCode' = $entitlement.GetElementsByTagName('ProductLineCode').InnerText
                        'ActiveWarrantyEntitlement' = $entitlement.GetElementsByTagName('ActiveWarrantyEntitlement').InnerText
                        'OverallWarrantyStartDate' = $entitlement.GetElementsByTagName('OverallWarrantyStartDate').InnerText
                        'OverallWarrantyEndDate' = $entitlement.GetElementsByTagName('OverallWarrantyEndDate').InnerText
                        'OverallContractEndDate' = $entitlement.GetElementsByTagName('OverallContractEndDate').InnerText
                        'WarrantyDeterminationDescription' = $entitlement.GetElementsByTagName('WarrantyDeterminationDescription').InnerText
                        'WarrantyDeterminationCode' = $entitlement.GetElementsByTagName('WarrantyDeterminationCode').InnerText
                        'WarrantyExtension' = $entitlement.GetElementsByTagName('WarrantyExtension').InnerText
                        'GracePeriod' = $entitlement.GetElementsByTagName('WarrantyExtension').InnerText
                    })
                }
            } else {
                Write-Error -Message 'No entitlement found.'
                continue
            }
        }
    }
}