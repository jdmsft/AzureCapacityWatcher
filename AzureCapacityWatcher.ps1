<#PSScriptInfo
.VERSION 1.0.0
.GUID 484bbc9d-b032-4b06-86b1-8c19e3699edb
.AUTHOR JDMSFT
.COMPANYNAME JDMSFT
.COPYRIGHT (c) 2021 JDMSFT. All Right Reserved.
.TAGS AzureAutomation Runbook Azure Capacity Notification Watcher alert
.LICENSEURI https://github.com/jdmsft/AzureCapacityWatcher/blob/master/LICENSE
.PROJECTURI https://github.com/jdmsft/AzureCapacityWatcher
.ICONURI
.EXTERNALMODULEDEPENDENCIES
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
.PRIVATEDATA
#>

<#
.SYNOPSIS
    Azure Capacity Watcher for Azure Automation (aka AzureCapacityWatcher)

.DESCRIPTION
    Azure Capacity Watcher (for Azure Automation) : Fetch Azure Capacity informations (Compute, Network and Storage quotas) and send a mail alert via Office 365 mail account for resource capacity above threshold.

.PARAMETER Location
   Mandatory (with default of "francecentral").
   Specify the location (region)

.PARAMETER Threshold
    Mandatory (with default of "75").
    Specify the resource capacity threshold.

.PARAMETER ShowConsoleOutput
    Mandatory (with default of "$true").
    Enable or Disable the console output

.PARAMETER ShowBeyondThresholdOnly
    Mandatory (with default of "$false").
    Show only resource with capacity above threshold

.PARAMETER AzureAutomationConnectionName
    Mandatory (with default of "AzureRunAsAccount").
    Specify the Automation connection used to read resources

.PARAMETER ExchangeOnlineMail
    Mandatory (with default of "$false").
    Enable or Disable the mail alert using Exchange Online (Office 365).

.PARAMETER ExchangeOnlineAutomationCredential
    Optional
    Specify Exchange Online Automation Credential (account used to send mail alert)

.PARAMETER ExchangeOnlineRecipient
    Optional
    Specify Exchange Online recipient (account who receive mail alert)

.NOTES

    PREREQUSITES (see https://github.com/jdmsft/AzureCapacityWatcher#prerequisites for full details)

        /!\ REQUIRE AZURE AUTOMATION /!\
        Use this script as Azure Automation PowerShell runbook


        /!\ REQUIRE AZURE SERVICE PRINCIPAL /!\
        Like many apps / runbooks in Azure, this runbook needs a service principal to run (also known as Automation RunAs Account / Automation Connection).

        /!\ REQUIRE AZURE AUTOMATION ASSETS (Shared Resources) /!\
        * Module : Az.Accounts, Az.Compute, Az.Network and Az.Storage
        * Connection : Azure (to read resources capacity)
        * Certificate : used by above connection to authenticate
        * Schedule : to automate your runbook execution, you should define an Automation schedule associated to this runbook for a recurring mail alert.

    PS MODULE DEPENDENCIES

        Az.Accounts (tested on v2.5.3)
        Az.Compute (tested on v4.17.0)
        Az.Network (tested on v4.11.0)
        Az.Storage (testeed on v3.11.0)
#>
param (
    [string]$Location = 'francecentral', 
    [int]$Threshold = 75, 
    [boolean]$ShowConsoleOutput = $true,
    [boolean]$ShowBeyondThresholdOnly = $false,
    [string]$AzureAutomationConnectionName = 'AzureRunAsAccount',
    [boolean]$ExchangeOnlineMail = $false,
    [string]$ExchangeOnlineAutomationCredential,
    [string]$ExchangeOnlineRecipient
)

If ($PSPrivateMetadata.JobId)
{
    Write-Verbose "Runbook environment : Azure Automation"
    Write-Verbose "Azure Connector for Azure Automation v1.0.0`n(c) 2020 - 2021 JDMSFT. All right Reserved."
    $ConnectorTimer = [system.diagnostics.stopwatch]::StartNew()

    Try
    {
        Write-Verbose "[CONNECTOR] Connecting to Azure ..."
        $AutomationConnection = Get-AutomationConnection -Name $AzureAutomationConnectionName
        Connect-AzAccount `
            -TenantId $AutomationConnection.TenantId `
            -ApplicationId $AutomationConnection.ApplicationId `
            -CertificateThumbprint $AutomationConnection.CertificateThumbprint `
        | Out-Null
    }
    Catch 
    {
        If (!$AutomationConnection)
        {
            $ErrorMessage = "Connection $AutomationConnectionName not found."
            throw $ErrorMessage
        } 
        Else
        {
            Write-Error $($_) ; throw "[$($_.InvocationInfo.ScriptLineNumber)] $($_.InvocationInfo.Line.TrimStart()) >> $($_)"
        }
    }
    $ConnectorTimer.Stop()
    Write-Verbose "[CONNECTOR] Elapsed time : $($ConnectorTimer.Elapsed)"
}

$ComputeStorageCategory = @('DiskAccessCount', 'DiskAccessCount', 'DiskEncryptionSetCount', 'Gallery', 'GalleryImage', 'GalleryImageVersion', 'PremiumDiskCount', 'PremiumSnapshotCount', 'PremiumZRSDiskCount', , 'StandardSSDStorageDisks', 'StandardSSDStorageSnapshots', 'StandardSSDZRSStorageDisks', 'StandardStorageSnapshots', 'UltraSSDDiskCount', 'UltraSSDDiskSizeInGB', 'ZRSSnapshotCount')

$output = @()

Get-AzSubscription | % {

    Select-AzSubscription $_ | Out-Null
    $SubscriptionName = $_.Name

    # Compute
    Get-AzVMUsage -Location $Location | % { 
        $Remain = ($_.Limit - $_.CurrentValue)
        If ($_.Limit -ne 0) { $Usage = ($_.CurrentValue / $_.Limit) } Else { $Usage = 0 }
        If ($_.Name.Value -notin $ComputeStorageCategory) { $Category = 'Compute' } Else { $Category = 'Storage' }
        $output += [PSCustomObject]@{SubscriptionName = $SubscriptionName ; Location = $Location ; Category = $Category ; Resource = $_.Name.LocalizedValue ; UsageRaw = $Usage ; Usage = 
            $Usage.tostring("P") ; TotalUsed = $_.CurrentValue ; TotalRemaining = $Remain ; Limit = $_.Limit
        } 
    }

    # Storage
    Get-AzStorageUsage -Location $Location | % { 
        $Remain = ($_.Limit - $_.CurrentValue)
        If ($_.Limit -ne 0) { $Usage = ($_.CurrentValue / $_.Limit) } Else { $Usage = 0 }
        $output += [PSCustomObject]@{SubscriptionName = $SubscriptionName ; Location = $Location ; Category = 'Storage' ; Resource = $_.LocalizedName ; UsageRaw = $Usage ; Usage = 
            $Usage.tostring("P") ; TotalUsed = $_.CurrentValue ; TotalRemaining = $Remain ; Limit = $_.Limit
        } 
    }

    # Network
    Get-AzNetworkUsage -Location $Location | % { 
        If ($_.Name.Value -ne 'NetworkWatchers')
        {
            $Remain = ($_.Limit - $_.CurrentValue)
            If ($_.Limit -ne 0) { $Usage = ($_.CurrentValue / $_.Limit) } Else { $Usage = 0 }
            $output += [PSCustomObject]@{SubscriptionName = $SubscriptionName ; Location = $Location ; Category = 'Network' ; Resource = $_.Name.LocalizedValue ; UsageRaw = $Usage ; Usage = 
                $Usage.tostring("P") ; TotalUsed = $_.CurrentValue ; TotalRemaining = $Remain ; Limit = $_.Limit
            } 
        }
    }

}

# Console
If ($ShowBeyondThresholdOnly) { $output = $output | ? {($_.UsageRaw * 100) -ge $Threshold} | select * -ExcludeProperty UsageRaw | sort SubscriptionName, Location, Category, Resource}
Else { $output = $output | select * -ExcludeProperty UsageRaw | sort SubscriptionName, Location, Category, Resource }
If ($ShowConsoleOutput) {$output | ft -AutoSize}

# Mail
If ($ExchangeOnlineMail)
    {
        $MailSubject = "Azure Capacity Watcher : resource(s) capacity beyond threshold ($Threshold%) !"
        $MailCredential = Get-AutomationPSCredential -Name $ExchangeOnlineAutomationCredential
        $MailBody = ($output | ConvertTo-Html | Out-String) + "`n`nRECOMMENDATION : Please manage the number of the Azure resources involved in your subscription(s) or submit a new request to expand these limits (soft limit only)."

        Write-Output "[RUNBOOK] Sending mail from Exchange Online  ..."
        Send-MailMessage -Credential $MailCredential -SmtpServer smtp.office365.com -Port 587 `
            -To $ExchangeOnlineRecipient `
            -Subject $MailSubject `
            -Body $MailBody `
            -From $MailCredential.UserName `
            -BodyAsHtml `
            -UseSsl
    }
