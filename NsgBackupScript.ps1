#Set variables
$nsgSubscriptionId = ""
$storageName = ""
$storageResourceGroup = ""
$storageContainerName = ""

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process | Out-Null

#Auth to Azure
try {
    $AzureContext = (Connect-AzAccount -Identity).context
}
catch{
    Write-Output "There is no managed identity. Aborting. Configure a managed identity as per https://learn.microsoft.com/en-us/azure/automation/enable-managed-identity-for-automation"; 
    exit
}
# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

#Get all NSG names in the subscription, export the template, and upload to storage
$storageAccount = Get-AzStorageAccount -ResourceGroupName $storageResourceGroup -Name $storageName
$nsgList = Get-AzNetworkSecurityGroup
$folderName = Get-Date -Format "MM-dd-yyyy"

foreach ($nsg in $nsgList)
{
    $tempFile = $env:TEMP + "\$($nsg.Name).json"

    #Export the NSG Template
    Export-AzResourceGroup -ResourceGroupName $nsg.ResourceGroupName -Resource "/subscriptions/$nsgSubscriptionId/resourceGroups/$($nsg.ResourceGroupName)/providers/Microsoft.Network/networkSecurityGroups/$($nsg.Name)" -Path $tempFile -SkipAllParameterization -Force
    #Import the NSG Template and remove "dependsOn" properties
    $export = Get-Content -Raw  $tempFile | ConvertFrom-Json -depth 10
    $export.Resources = $export.Resources | select-object * -ExcludeProperty dependsOn
    $export | ConvertTo-Json -Depth 10 | Out-File $tempFile -Force

    #Upload to Storage
    Set-AzStorageBlobContent -Context $storageAccount.Context -Container $storageContainerName -File $tempFile -Blob "$folderName\$($nsg.Name)"
}