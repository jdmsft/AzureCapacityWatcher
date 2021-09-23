# Azure Capacity Watcher

Azure Capacity Watcher (for Azure Automation) : Fetch Azure Capacity informations (Compute, Network and Storage quotas) and send a mail report via Office 365 mail account for resource capacity above threshold.

## Presentation

**Azure Capacity Watcher** is an **Azure Automation** solution (PowerShell runbook) that help you to fetch Azure Capacity informations (Compute, Network and Storage quotas) and send a mail report via Office 365 mail account for resource capacity above threshold. See [Prerequistes below](https://github.com/jdmsft/AzureCapacityWatcher#prerequisites) to use this solution.

To sum up, you can use this runbook to:

1) List all Azure resource quota in the Automation *"console"* output
2) Send mail report (via an Office 365 mail account) for Azure resource quota which reach threshold
3) Or both!

## Prerequisites

* An Azure Automation Account with:
  * Some Automation Modules : Az.Accounts, Az.Compute, Az.Network and Az.Storage
  * An Automation Connection (type = AzureServicePrincipal) : refering to your Azure Service Principal (Service Principal with certificate credential and reader access to your Azure resources you want to watch. eg. Reader)
  * An Automation Certificate (used by the Service Principal and refered by the Azure Automation Connection)
  * *(optional)* An Automation Schedule : if you want to send report reccurently (e.g. monthly)
* *(optional)* An Office 365 mail account credential to use as the account that send the mail notification (if you want to enable mail notification)

## Deploy the runbook

***Don't forget to apply all [prerequisites](#prerequisites) prior deploying this runbook!***

Two methods of deployment:

1. By clicking the button below *(fastest method)*
2. By browsing Azure Automation Runbook Gallery

### Option 1: Using the button

Click on the button below, and select your existing Azure Automation account where you want to deploy the runbook.

<p style="text-align:center;"><a href="https://www.powershellgallery.com/packages/AzureCapacityWatcher/1.0.0/DeployItemToAzureAutomation?itemType=PSScript&requireLicenseAcceptance=False" target="_blank">
    <img src="media/DeployToAutomation_v1.0.png" width=45%/>
</a></p>

***NOTE : there's no need to fill the "Subscription name", "Resource group" and "Location" input boxes on the second screen as your Automation account is already selected.***

### Option 2: Using Azure Automation Runbooks Gallery

Open your Azure Automation account, and import **AzureCapacityWatcher** from the Runbooks Gallery (Source : PowerShellGallery ).
