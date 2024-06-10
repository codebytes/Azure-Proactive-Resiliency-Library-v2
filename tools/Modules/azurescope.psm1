function New-AzTenantSelection {
  return Get-AzTenant | Out-ConsoleGridView -OutputMode Single -Title "Select Tenant"
}

function New-AzSubscriptionSelection {
  param (
    [Parameter(Mandatory=$true)]
    [string]$TenantId
  )
  return Get-AzSubscription -TenantId $TenantId | Out-ConsoleGridView -OutputMode Multiple -title "Select Subscription(s)"
}

function New-AzResourceGroupSelection {
  param (
    [Parameter(Mandatory=$true)]
    [string[]]$SubscriptionIds
  )
  return Get-AllResourceGroup -SubscriptionId $SubscriptionIds | Select-Object ResourceGroup, SubscriptionName, resourceId | Out-ConsoleGridView -OutputMode Multiple -Title "Select Resource Group(s)"
}
