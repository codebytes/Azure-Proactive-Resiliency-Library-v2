Function Get-AllAzGraphResource {
  param (
    [string[]]$subscriptionId,
    [string]$query = 'Resources | project id, resourceGroup, subscriptionId, name, type, location'
  )

  $result = $subscriptionId ? (Search-AzGraph -Query $query -first 1000 -Subscription $subscriptionId) : (Search-AzGraph -Query $query -first 1000 -usetenantscope) # -first 1000 returns the first 1000 results and subsequently reduces the amount of queries required to get data.

  # Collection to store all resources
  $allResources = @($result)

  # Loop to paginate through the results using the skip token
  while ($result.SkipToken) {
    # Retrieve the next set of results using the skip token
    $result = $subscriptionId ? (Search-AzGraph -Query $query -SkipToken $result.SkipToken -Subscription $subscriptionId -First 1000) : (Search-AzGraph -query $query -SkipToken $result.SkipToken -First 1000 -UseTenantScope)
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

  $r = $SubscriptionIds ? (Get-AllAzGraphResource -query $q -subscriptionId $SubscriptionIds -usetenantscope) : (Get-AllAzGraphResource -query $q -usetenantscope)

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

function Invoke-TagFiltering {
  param($TagFilters,$Subid)

    $TagFile = get-item -Path $TagFilters
    $TagFile = $TagFile.FullName
    $TagFilter = Get-Content -Path $TagFile

    # Each line in the Tag Filtering file will be processed
    $TaggedResourceGroups = @()
    Foreach ($TagLine in $TagFilter)
      {
        # Finding the TagKey and all the TagValues in the line
        $TagKey = $TagLine.split(':')[0]
        $TagValues = $TagLine.split(',')
        Foreach ($TagValue in $TagValues)
          {
            #Due to the split used to create the array the first TagValue in the array will still have the TagKey
            if ($TagValue -eq $TagValues[0])
              {
                $TagValue = $TagValue.replace(($TagKey+':'),'')
              }
            Write-Debug ("Running Resource Group Tag Inventory for: "+ $TagKey + " : " + $TagValue)
            #Getting all the Resource Groups with the Tags, this will be used later

            $RGTagQuery = "ResourceContainers | where type =~ 'microsoft.resources/subscriptions/resourcegroups' | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey =~ '$TagKey' and tagValue =~ '$TagValue' | project id | order by id"

            $TaggedResourceGroups += Get-AllAzGraphResource -query $RGTagQuery -subscriptionId $Subid

            Write-Debug ("Running Resource Tag Inventory for: "+ $TagKey + " : " + $TagValue)
            #Getting all the resources within the TAGs
            $ResourcesTagQuery = "Resources | mvexpand tags | extend tagKey = tostring(bag_keys(tags)[0]) | extend tagValue = tostring(tags[tagKey]) | where tagKey =~ '$TagKey' and tagValue =~ '$TagValue' | project id, name, subscriptionId, resourceGroup, location | order by id"

            $Script:TaggedResources += Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $Subid
          }
        }
    #If Tags are present in the Resource Group level we make sure to get all the resources within that resource group
    if ($TaggedResourceGroups)
      {
        foreach ($ResourceGroup in $TaggedResourceGroups)
          {
            Write-Debug ("Double Checking Tagged Resources inside the Resource Group: " + $ResourceGroup)
            $ResourcesTagQuery = "Resources | where id startswith '$ResourceGroup' | project id, name, subscriptionId, resourceGroup, location | order by id"

            $Script:TaggedResources += Get-AllAzGraphResource -query $ResourcesTagQuery -subscriptionId $Subid

          }
      }
}
