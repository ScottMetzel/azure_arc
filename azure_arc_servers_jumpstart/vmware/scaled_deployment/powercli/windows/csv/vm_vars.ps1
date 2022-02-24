# Azure vars
$env:subscription_id = 'Your Azure subscription ID'
$env:servicePrincipalClientId = 'Your Azure service principal name'
$env:servicePrincipalSecret = 'Your Azure service principal password'
$env:tenant_id = 'Your Azure tenant ID'
$env:resourceGroup = 'Azure resource group name where the Azure Arc servers will be onboarded to'
$env:location = 'Azure Region' # For example: "eastus"

# Do not remove this variable. Only fill in the double quotes if a proxy is needed.
$env:ConnectivityMethodProxyURL = ""