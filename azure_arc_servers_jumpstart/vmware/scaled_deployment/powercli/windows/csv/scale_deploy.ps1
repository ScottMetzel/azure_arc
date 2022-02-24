[CmdletBinding()]
param (
  [Parameter(
    Mandatory = $true
  )]
  [ValidateNotNullOrEmpty()]
  [System.String]$vCenterAddress,
  [Parameter(
    Mandatory = $false
  )]
  [ValidateNotNullOrEmpty()]
  [System.Management.Automation.PSCredential]$vCenterCredential = (Get-Credential)
)
# Define preference Variables
$InformationPreference = "Continue"
$ErrorActionPreference = "Stop"

# Import the CSV File
[System.String]$MessageImportCSV = "Importing CSV."
Write-Information -MessageData $MessageImportCSV

[System.String]$CSVPath = [System.String]::Concat($PSScriptRoot, "\vms.csv")
$ImportCSV = Import-Csv -Path $CSVPath

# Download the package
[System.String]$InvokeWROutFile = [System.String]::Concat($PSScriptRoot, "\AzureConnectedMachineAgent.msi")
function download {
  [CmdletBinding()]
  param (
    [System.String]$InvokeWROutFile = [System.String]::Concat($PSScriptRoot, "\AzureConnectedMachineAgent.msi")
  )
  $InformationPreference = "Continue"
  $ProgressPreference = "SilentlyContinue"
  Write-Information -MessageData "Downloading Azure Connected Machine Agent."
  Invoke-WebRequest -Uri https://aka.ms/AzureConnectedMachineAgent -OutFile $InvokeWROutFile
}
download -InvokeWROutFile $InvokeWROutFile

# Connet to VMware vCenter
[System.String]$MessageSetPowerCLI = "Setting PowerCLI configuration."
Write-Information -MessageData $MessageSetPowerCLI
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

[System.String]$MessagevCenterConnect = [System.String]::Concat("Connecting to vCenter ", $vCenterAddress)
Write-Information -MessageData $MessagevCenterConnect
Connect-VIServer -Server $vCenterAddress -Credential $vCenterCredential -Force

# Create a basic counter and get the total number of VMs to onboard
[System.Int32]$c = 1
[System.Int32]$VMCount = $ImportCSV.Count

# Enter onboarding loop for each VM in the CSV
[System.String]$MessageTotalOnboard = [System.String]::Concat("Will onboard ", $VMCount, " VMs.")
Write-Information -MessageData $MessageTotalOnboard
foreach ($VM in $ImportCSV) {
  # Define per-VM variables in the CSV
  [System.String]$VMName = $VM.VMName
  [System.String]$OSAdmin = $VM.OSAdmin
  [System.String]$OSAdminPassword = $VM.OSAdminPassword

  [System.String]$MessageWorkingOnVM = [System.String]::Concat("Working on VM ", $VMName, ". VM ", $c, " of ", $VMCount, " VMs.")
  Write-Information -MessageData $MessageWorkingOnVM

  # Get the VM in vCenter
  try {
    $ErrorActionPreference = "Stop"
    [System.String]$MessageGetVM = [System.String]::Concat("Getting VM ", $VMName, ".")
    Write-Information -MessageData $MessageGetVM

    $GetVM = Get-VM -Name $VMName -ErrorAction "Stop"
  }
  catch {
    [System.String]$MessageGetVMCatch = [System.String]::Concat("Could not find VM ", $VMName)
    Write-Warning -Message $MessageGetVMCatch
  }

  # Define scripts information and copy to VM
  [System.String]$File1 = [System.String]::Concat("install_arc_agent.ps1")
  [System.String]$File2 = [System.String]::Concat("vm_vars.ps1")
  [System.String]$File3 = [System.String]::Concat("AzureConnectedMachineAgent.msi")
  [System.String]$DestinationDirectory = "C:\arctemp\"
  [System.String]$Destination1 = [System.String]::Concat($DestinationDirectory, $File1)
  [System.String]$Destination2 = [System.String]::Concat($DestinationDirectory, $File2)
  [System.String]$Destination3 = [System.String]::Concat($DestinationDirectory, $File3)

  try {
    $ErrorActionPreference = "Stop"
    [System.String]$MessageCopyScripts = "About to copy installation files."
    Write-Information -MessageData $MessageCopyScripts

    [System.String]$MessageCopyFile1 = [System.String]::Concat("Copying ", $File1, " to ", $Destination1, " on VM.")
    [System.String]$MessageCopyFile2 = [System.String]::Concat("Copying ", $File2, " to ", $Destination2, " on VM.")
    [System.String]$MessageCopyFile3 = [System.String]::Concat("Copying ", $File3, " to ", $Destination3, " on VM.")

    Write-Information -MessageData $MessageCopyFile1
    Copy-VMGuestFile -VM $GetVM -Source $File1 -Destination $Destination1 -LocalToGuest -GuestUser $OSAdmin -GuestPassword $OSAdminPassword -Force

    Write-Information -MessageData $MessageCopyFile2
    Copy-VMGuestFile -VM $GetVM -Source $File2 -Destination $Destination2 -LocalToGuest -GuestUser $OSAdmin -GuestPassword $OSAdminPassword -Force

    Write-Information -MessageData $MessageCopyFile3
    Copy-VMGuestFile -VM $GetVM -Source $File3 -Destination $Destination3 -LocalToGuest -GuestUser $OSAdmin -GuestPassword $OSAdminPassword -Force
  }
  catch {
    [System.String]$MessageCopyScriptsCatch = [System.String]::Concat("A problem occurred while copying scripts to VM ", $VMName)
    Write-Error -Message $MessageCopyScriptsCatch
  }

  # Onboard VM to Azure Arc
  try {
    $ErrorActionPreference = "Stop"
    [System.String]$MessageOnboarding = [System.String]::Concat("Hold tight, I am onboarding VM ", $VMName, " to Azure Arc...")
    Write-Information -MessageData $MessageOnboarding

    $OnboardResult = Invoke-VMScript -VM $GetVM -ScriptText $Destination1 -GuestUser $OSAdmin -GuestPassword $OSAdminPassword
    $OnboardExitCode = $OnboardResult.ExitCode
  }
  catch {
    [System.String]$MessageOnboardingIssue = "An issue was encountered during onboarding."
    Write-Error -Message $MessageOnboardingIssue
  }

  # Get the exit code from onboarding
  if ($OnboardExitCode -eq "0") {
    [System.String]$MessageOnboardingSucceeded = [System.String]::Concat($VMName, " has been successfully onboarded to Azure Arc.")
    Write-Information -MessageData $MessageOnboardingSucceeded
  }
  else {
    [System.String]$MessageOnboardingSucceededIssue = [System.String]::Concat($VMName, " returned exit code ", $ExitCode)
    Write-Warning -Message $MessageOnboardingSucceededIssue
  }

  # Cleanup post-onboarding
  try {
    $ErrorActionPreference = "Stop"
    [System.String]$MessageCleanupVM = [System.String]::Concat("Removing ", $DestinationDirectory, " from ", $VMName)
    Write-Information -MessageData $MessageCleanupVM

    $CleanupResult = Invoke-VMScript -VM $GetVM -ScriptText "Remove-Item -Force -Recurse -Path $DestinationDirectory" -GuestUser $OSAdmin -GuestPassword $OSAdminPassword
    $CleanupExitCode = $CleanupResult.ExitCode
  }
  catch {
    [System.String]$MessageCleanupVMIssue = "An issue was encountered during cleanup."
    Write-Error -Message $MessageCleanupVMIssue
  }

  # Get the exit code from cleanup
  if ($CleanupExitCode -eq "0") {
    [System.String]$MessageCleanupSucceeded = [System.String]::Concat($DestinationDirectory, " removed from ", $VMName, " successfully")
    Write-Information -MessageData $MessageCleanupSucceeded
  }
  else {
    [System.String]$MessageCleanupSucceededIssue = [System.String]::Concat($DestinationDirectory, " not removed from ", $VMName, ".")
    Write-Warning -Message $MessageCleanupSucceededIssue
  }

  # Increase the counter
  $c++
}