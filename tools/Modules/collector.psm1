Function Get-AllAzGraphResource {
  param (
    [string[]]$subscriptionIds,
    [string]$query = 'Resources | project id, resourceGroup, subscriptionId, name, type, location'
  )

  $result = $subscriptionId ? (Search-AzGraph -Query $query -first 1000 -Subscription $subscriptionIds ) : (Search-AzGraph -Query $query -first 1000) # -first 1000 returns the first 1000 results and subsequently reduces the amount of queries required to get data.

  # Collection to store all resources
  $allResources = @($result)

  # Loop to paginate through the results using the skip token
  while ($result.SkipToken) {
    # Retrieve the next set of results using the skip token
    $result = $subscriptionId ? (Search-AzGraph -Query $query -SkipToken $result.SkipToken -Subscription $subscriptionIds -First 1000 ) : (Search-AzGraph -query $query -SkipToken $result.SkipToken -First 1000)
    # Add the results to the collection
    $allResources += $result
  }

  # Output all resources
  return $allResources
}

function Get-AllResourceGroup {
  param (
    [string[]]$SubscriptionIds
  )

  # Query to get all resource groups in the tenant
  $q = "resourcecontainers
  | where type == 'microsoft.resources/subscriptions'
  | project subscriptionId, subscriptionName = name
  | join (resourcecontainers
      | where type == 'microsoft.resources/subscriptions/resourcegroups')
      on subscriptionId
  | project subscriptionName, subscriptionId, resourceGroup, id=tolower(id)"

  $r = $SubscriptionIds ? (Get-AllAzGraphResource -query $q -subscriptionId $SubscriptionIds) : (Get-AllAzGraphResource -query $q)

  # Returns the resource groups
  return $r
}

function Get-ResourceGroupsByList {
  param (
      [Parameter(Mandatory=$true)]
      [array]$ObjectList,

      [Parameter(Mandatory=$true)]
      [array]$FilterList,

      [Parameter(Mandatory=$true)]
      [string]$KeyColumn
  )



  $matchingObjects = foreach ($obj in $ObjectList) {
      if (($obj.$KeyColumn.split("/")[0..4] -join "/") -in $FilterList) {
          $obj
      }
  }

  return $matchingObjects
}
