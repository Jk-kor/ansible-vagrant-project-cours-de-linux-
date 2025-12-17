#requires -Version 5.1

<#
Helper for Vagrant VM snapshots with date-based names on Windows PowerShell.

Usage examples:
  ./scripts/snapshot.ps1 -Action save
  ./scripts/snapshot.ps1 -Action list
  ./scripts/snapshot.ps1 -Action restore -Name snap-20251217-103000
#>

param(
  [ValidateSet('save','restore','list','delete')]
  [string]$Action = 'save',

  [string[]]$Machines = @('admin','web','infra'),

  [string]$Name,

  [switch]$Yes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Command([string]$Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Required command not found: $Name. Please install it and retry."
  }
}

function Invoke-Vagrant([string]$VagrantArgs) {
  Write-Host "→ vagrant $VagrantArgs" -ForegroundColor Cyan
  & vagrant $VagrantArgs
}

function Do-Save([string[]]$Machines, [string]$Name) {
  $snapName = if ($Name) { $Name } else { "snap-$(Get-Date -Format 'yyyyMMdd-HHmmss')" }
  foreach ($m in $Machines) {
    Invoke-Vagrant "snapshot save $m $snapName"
  }
}

function Do-List([string[]]$Machines) {
  foreach ($m in $Machines) {
    Write-Host "`n[$m] snapshots:" -ForegroundColor Yellow
    Invoke-Vagrant "snapshot list $m"
  }
}

function Confirm-IfNeeded([string]$Message, [switch]$Yes) {
  if ($Yes) { return $true }
  $resp = Read-Host "$Message (y/N)"
  return ($resp -match '^(y|yes)$')
}

function Do-Restore([string[]]$Machines, [string]$Name, [switch]$Yes) {
  if (-not $Name) { throw 'Please provide -Name for restore.' }
  if (-not (Confirm-IfNeeded "Restore snapshot '$Name' for machines: $($Machines -join ', ')" -Yes:$Yes)) { return }
  foreach ($m in $Machines) {
    Invoke-Vagrant "snapshot restore $m $Name"
  }
}

function Do-Delete([string[]]$Machines, [string]$Name, [switch]$Yes) {
  if (-not $Name) { throw 'Please provide -Name for delete.' }
  if (-not (Confirm-IfNeeded "Delete snapshot '$Name' for machines: $($Machines -join ', ')" -Yes:$Yes)) { return }
  foreach ($m in $Machines) {
    Invoke-Vagrant "snapshot delete $m $Name"
  }
}

# Main
Assert-Command 'vagrant'

switch ($Action) {
  'save'    { Do-Save    -Machines $Machines -Name $Name }
  'list'    { Do-List    -Machines $Machines }
  'restore' { Do-Restore -Machines $Machines -Name $Name -Yes:$Yes }
  'delete'  { Do-Delete  -Machines $Machines -Name $Name -Yes:$Yes }
}

Write-Host "`nDone." -ForegroundColor Green