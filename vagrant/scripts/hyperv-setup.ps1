# Hyper-V: one-time host setup for the DevOps course lab (run as Administrator).
#   powershell -ExecutionPolicy Bypass -File .\scripts\hyperv-setup.ps1
# Creates internal virtual switch "DevOpsLab" with host IP 192.168.56.1/24.
# VMs get a 2nd NIC on this switch with static IPs 192.168.56.x;
# the 1st NIC stays on "Default Switch" (internet + Vagrant SSH).
param(
  [string]$SwitchName = "DevOpsLab",
  [string]$HostIP = "192.168.56.1"
)
$ErrorActionPreference = "Stop"

if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) {
  New-VMSwitch -SwitchName $SwitchName -SwitchType Internal | Out-Null
  Write-Host "Switch $SwitchName created"
} else {
  Write-Host "Switch $SwitchName already exists"
}

$alias = "vEthernet ($SwitchName)"
if (-not (Get-NetIPAddress -InterfaceAlias $alias -IPAddress $HostIP -ErrorAction SilentlyContinue)) {
  New-NetIPAddress -InterfaceAlias $alias -IPAddress $HostIP -PrefixLength 24 | Out-Null
  Write-Host "Host IP $HostIP/24 set on $alias"
}

Get-VMSwitch -Name $SwitchName | Format-Table Name, SwitchType
Get-NetIPAddress -InterfaceAlias $alias -AddressFamily IPv4 | Format-Table InterfaceAlias, IPAddress, PrefixLength
