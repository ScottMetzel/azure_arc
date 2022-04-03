# Injecting environment variables
. C:\arctemp\vm_vars.ps1

# Install the package
$exitCode = (Start-Process -FilePath msiexec.exe -ArgumentList @("/i", "C:\arctemp\AzureConnectedMachineAgent.msi" , "/l*v", "installationlog.txt", "/qn") -Wait -PassThru).ExitCode
if ($exitCode -ne 0) {
  $message = (net helpmsg $exitCode)
  throw "Installation failed: $message See installationlog.txt for additional details."
}

# Check if we need to set proxy environment variable
if ($env:ConnectivityMethodProxyURL -notin @($null, "")) {
  Write-Verbose -Message "Setting proxy configuration: $Proxy" -Verbose
  & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" config set proxy.url ${Proxy}
}

# Run connect command
# "cloud" argument value would be "AzureCloud" or "AzureGovernment"
& "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect `
  --service-principal-id $env:servicePrincipalClientId `
  --service-principal-secret $env:servicePrincipalSecret `
  --resource-group $env:resourceGroup `
  --tenant-id $env:tenant_id `
  --location $env:location `
  --subscription-id $env:subscription_id `
  --cloud "AzureCloud" `
  --tags "Project=jumpstart_azure_arc_servers" `
  --correlation-id "d009f5dd-dba8-4ac7-bac9-b54ef3a6671a"