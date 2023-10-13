function Get-CIPPAzSubscriptions {
    param (
        $TenantFilter,
        $APIName = "Get-CIPPAzSubscriptions"
    )

    $subsCache = [system.collections.generic.list[hashtable]]::new()
    try {
        try {
            $usageRecords = (New-GraphGETRequest -Uri "https://api.partnercenter.microsoft.com/v1/customers/$($TenantFilter)/subscriptions/usagerecords" -scope "https://api.partnercenter.microsoft.com/user_impersonation").items | Where-Object { $_.status -eq "active" }
            Write-Host "$($usageRecords.Count) usagerecords found"
            #$usageRecords = (Invoke-RestMethod -Method 'GET' -Uri "https://api.partnercenter.microsoft.com/v1/customers/$($tenant.tenantid)/subscriptions/usagerecords" -Headers $partnerheader).items | Where-Object { $_.status -eq "active" }
        } catch {
            #throw "Unable to retrieve usagerecord(s) for tenant $($tenantFilter): $($_.Exception.Message)"
            Write-LogMessage -message "Unable to retrieve usagerecord(s): $($_.Exception.Message)" -Sev 'ERROR' -API $APINAME
        }

        foreach ($usageRecord in $usageRecords) {
            if ($usageRecord.name -ne "Azure Plan") {
                # Legacy subscriptions are directly accessible
                $subDetails = @{
                    tenantId = $tenantFilter
                    subscriptionId = ($usageRecord.id).ToLower()
                    isLegacy = $true
                    POR = "N/A"
                    status = $usageRecord.status
                }
    
                $subsCache.Add($subDetails)
            } else {
                # For modern subscriptions we need to dig a little deeper
                try {
                    $subid = (New-GraphGETRequest -Uri "https://api.partnercenter.microsoft.com/v1/customers/$($TenantFilter)/subscriptions/$($usageRecord.id)/azureEntitlements" -scope "https://api.partnercenter.microsoft.com/user_impersonation").items | Where-Object { $_.status -eq "active" }
                    #$subid = (Invoke-RestMethod -Method 'GET' -Uri "https://api.partnercenter.microsoft.com/v1/customers/$($tenant.tenantid)/subscriptions/$($usageRecord.id)/azureEntitlements" -Headers $partnerheader).items | Where-Object { $_.status -eq "active" }
                
                    foreach ($id in $subid) {
                        $subDetails = @{
                            tenantId = $tenantFilter
                            subscriptionId = ($id.id)
                            isLegacy = $false
                            POR = If ($id.partnerOnRecord) { $id.partnerOnRecord } else { $null }
                            status = $id.status
                        }
        
                        $subsCache.Add($subDetails)
                    }
                } catch {
                    Write-LogMessage -message "Unable to retrieve sub(s) from usagerecord $($usageRecord.id): $($_.Exception.Message)" -Sev 'ERROR' -API $APINAME
                    #Write-Error "Unable to retrieve sub(s) from usagerecord $($usageRecord.id) for tenant $($tenantFilter): $($_.Exception.Message)"
                }
            }
        }

        return $subsCache
    } catch {
        Write-LogMessage -message "Unable to retrieve CSP Azure subscriptions: $($_.Exception.Message)" -Sev 'ERROR' -API $APINAME
    }
}
