# Hyper-V: attach VM to the lab switch "DevOpsLab" (called by Vagrant triggers).
param(
  [Parameter(Mandatory = $true)][string]$VMName,
  [string]$SwitchName = "DevOpsLab"
)
$vm = Get-VM -Name $VMName -ErrorAction SilentlyContinue
if (-not $vm) { exit 0 }

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
  Write-Warning "Switch $SwitchName not found. Run once as Administrator: powershell -ExecutionPolicy Bypass -File .\scripts\hyperv-setup.ps1"
  exit 1
}

if (Get-VMNetworkAdapter -VMName $VMName | Where-Object { $_.SwitchName -eq $SwitchName }) { exit 0 }

try {
  Add-VMNetworkAdapter -VMName $VMName -SwitchName $SwitchName -ErrorAction Stop
  Write-Host "${VMName}: attached to $SwitchName"
} catch {
  $short = $VMName -replace '^devops-', ''
  Write-Warning "Could not attach $SwitchName to running VM ${VMName}: $_"
  Write-Warning "Run: vagrant reload $short"
}
exit 0
