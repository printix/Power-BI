Function Get-PrintixAuthorizationToken {
    [CmdletBinding()] 
    param (
    )
    Write-Verbose -Message 'Getting Printix Authorization Token'

    #Set Authorization Uri and Content Type
    $AuthorizationUri = 'https://auth.printix.net/oauth/token'
    $ContentType = 'application/x-www-form-urlencoded'

    write-Verbose -Message 'Setting body'
    #Set body according to Authentication doc; https://printix.bitbucket.io/index-005e71b7-013f-4dbb-9227-020367495ac4.html
    $Body = ('grant_type=client_credentials&client_id={0}&client_secret={1}' -f $Global:ClientCredentials.UserName, $Global:ClientCredentials.GetNetworkCredential().Password)

    #Catch the X-Printix-Request-Id in case of failure. It's needed by printix for debugging
    try {
        Write-Verbose -Message 'Getting Auth headers'
        $AuthorizationToken = Invoke-RestMethod -Uri $AuthorizationUri -Method Post -ContentType $ContentType -Body $Body -ErrorAction:Stop
        Write-Verbose -Message 'Setting script expire time'
        $Global:HeadersExipreTime = (Get-date).AddSeconds($AuthorizationToken.expires_in)
    }
    catch {
        $ErrorMessage += 'Exception: '
        $ErrorMessage += $_
        $ErrorMessage += " `n"
        $ErrorMessage += 'Printix Request ID: '
        $ErrorMessage += $_.Exception.Response.GetResponseHeader('X-Printix-Request-ID')
        $ErrorMessage += " `n"
        $ErrorMessage += 'Uri: '
        $ErrorMessage += $AuthorizationUri
        $ErrorMessage += " `n"
        $ErrorMessage += 'Response: '
        $ErrorMessage += $_.Exception.Response
        $ErrorMessage += " `n"
        Write-Error -Message $ErrorMessage
    }
    Write-Verbose -Message 'Return Auth headers'
    Return $AuthorizationToken
}


Function Set-PrintixHttpHeaders {
    [CmdletBinding()] 
    param (
    )
    Write-Verbose -Message 'Setting Printix HTTP Headers'

    $AuthorizationToken = Get-PrintixAuthorizationToken

    $Global:httpHeaders = @{
        'Authorization' = ('Bearer {0}' -f $AuthorizationToken.access_token)
        'Accept'        = '*/*'
        'Content-Type'  = 'application/json'
    }

}

Function Get-PrintixPartnerInformation {
    [CmdletBinding()] 
    param (
    )
    Write-Verbose -Message 'Getting Printix Partner Information'

    #Handle the fact that the auth headers might have expired
    if ($Global:HeadersExipreTime -lt (get-date).AddSeconds(+10)) {
        Write-Warning -Message 'Auth headers expired. Getting new http header'
        Set-PrintixHttpHeaders
    }

    #Catch the X-Printix-Request-Id in case of failure. It's needed by printix for debugging
    try {
        $PartnerInformation = Invoke-RestMethod -Method Get -Uri $ApiEntry -Headers $Global:HttpHeaders -ErrorAction:Stop
    }
    catch {
        $ErrorMessage += 'Exception: '
        $ErrorMessage += $_
        $ErrorMessage += " `n"
        $ErrorMessage += 'Printix Request ID: '
        $ErrorMessage += $_.Exception.Response.GetResponseHeader('X-Printix-Request-ID')
        $ErrorMessage += " `n"
        $ErrorMessage += 'Uri: '
        $ErrorMessage += $ApiEntry
        $ErrorMessage += " `n"
        $ErrorMessage += 'Response: '
        $ErrorMessage += $_.Exception.Response
        $ErrorMessage += " `n"
        Write-Error -Message $ErrorMessage
    }

    Return $PartnerInformation

}

Function Get-PrintixPartnerTenants {
    [CmdletBinding()] 
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        $TenantsHref
    )
    Write-Verbose -Message 'Getting Printix Partner tenants'

    #Handle the fact that the auth headers might have expired
    if ($Global:HeadersExipreTime -lt (get-date).AddSeconds(+10)) {
        Write-Warning -Message 'Auth headers expired. Getting new http header'
        Set-PrintixHttpHeaders
    }

    #Catch the X-Printix-Request-Id in case of failure. It's needed by printix for debugging
    try {
        $PartnerTenants = Invoke-RestMethod -Method Get -Uri $TenantsHref -Headers $Global:HttpHeaders -ErrorAction:Stop
    }
    catch {
        $ErrorMessage += 'Exception: '
        $ErrorMessage += $_
        $ErrorMessage += " `n"
        $ErrorMessage += 'Printix Request ID: '
        $ErrorMessage += $_.Exception.Response.GetResponseHeader('X-Printix-Request-ID')
        $ErrorMessage += " `n"
        $ErrorMessage += 'Uri: '
        $ErrorMessage += $TenantsHref
        $ErrorMessage += " `n"
        $ErrorMessage += 'Response: '
        $ErrorMessage += $_.Exception.Response
        $ErrorMessage += " `n"
        Write-Error -Message $ErrorMessage
    }

    Return $PartnerTenants

}

Function Get-PrintixTenantInformation {
    [CmdletBinding()] 
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        $TenantHref
    )
    Write-Verbose -Message 'Getting Printix tenant'

    #Handle the fact that the auth headers might have expired
    if ($Global:HeadersExipreTime -lt (get-date).AddSeconds(+10)) {
        Write-Warning -Message 'Auth headers expired. Getting new http header'
        Set-PrintixHttpHeaders
    }

    #Catch the X-Printix-Request-Id in case of failure. It's needed by printix for debugging
    try {
        $TenantInfo = Invoke-RestMethod -Method Get -Uri $TenantHref -Headers $Global:HttpHeaders -ErrorAction:Stop
    }
    catch {
        $ErrorMessage += 'Exception: '
        $ErrorMessage += $_
        $ErrorMessage += " `n"
        $ErrorMessage += 'Printix Request ID: '
        $ErrorMessage += $_.Exception.Response.GetResponseHeader('X-Printix-Request-ID')
        $ErrorMessage += " `n"
        $ErrorMessage += 'Uri: '
        $ErrorMessage += $TenantHref
        $ErrorMessage += " `n"
        $ErrorMessage += 'Response: '
        $ErrorMessage += $_.Exception.Response
        $ErrorMessage += " `n"
        Write-Error -Message $ErrorMessage
    }

    Return $TenantInfo

}

Function New-PrintixDataExtract {
    [CmdletBinding()] 
    param (
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0)]
        $StorageMapping,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 1)]
        [int]$DaysToExtract,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 2)]
        [string]$ExtractUri,
        [Parameter(ValueFromPipelineByPropertyName = $true, Position = 3)]
        [array]$PrintixDataToExtract = ('NETWORKS', 'TRACKING_DATA', 'JOBS', 'PRINTERS', 'DEVICE_READINGS', 'USERS', 'WORKSTATIONS')
    )

    #Catch the X-Printix-Request-Id in case of failure. It's needed by printix for debugging
    try {

        #Handle the fact that the auth headers might have expired
        if ($Global:HeadersExipreTime -lt (get-date).AddSeconds(+10)) {
            Write-Warning -Message 'Auth headers expired. Getting new http header'
            Set-PrintixHttpHeaders
        }

        #Don't use get-date, as the format will be different from different OS cultures
        [string]$FromDate = [DateTime]::UtcNow.AddDays(( - $DaysToExtract)).ToString('o')
        [string]$ToDate = [DateTime]::UtcNow.ToString('o')

        #Get blob storage key
        $StorageAccountPrintixExtractedDataKey = (Get-AzureRmStorageaccountKey -Name $StorageMapping.StorageAccountPrintixExtractedData -ResourceGroupName $StorageMapping.StorageAccountPrintixExtractedDataResourceGroup)[0].value

        #Build request body
        $Requestbody = @{
            'from'                 = $FromDate
            'to'                   = $ToDate
            'blobStoreAccountName' = $StorageMapping.StorageAccountPrintixExtractedData
            'blobStoreAccountKey'  = $StorageAccountPrintixExtractedDataKey
            'extracts'             = $PrintixDataToExtract
        }

        #Create status counter and register start date
        [int]$ExtractstatusCounter = 0
        $ExtractStatusStartTime = get-date

        #Request extract
        $ExtractRequest = Invoke-RestMethod  -Method Post -Uri $ExtractUri -Headers $Global:HttpHeaders -Body ($Requestbody | convertto-json)  -ErrorAction:Stop

        #Wait until extract is completed
        do {
            Write-Verbose -Message ('Checked extract status [{0}] times.' -f $ExtractstatusCounter)

            #Handle the fact that the auth headers might have expired
            if ($Global:HeadersExipreTime -lt (get-date).AddSeconds(+10)) {
                Write-Warning -Message 'Auth headers expired. Getting new http header'
                Set-PrintixHttpHeaders
            }

            $ExtractStatus = Invoke-RestMethod  -Method Get -Uri $ExtractRequest._links.self.href -Headers $Global:HttpHeaders
            $ExtractstatusCounter++

            #Wait for some random time
            start-sleep -Seconds (Get-Random -Minimum 5 -Maximum 20)

        }
        until ($ExtractStatus.completed -or $ExtractstatusCounter -gt 60)

        if ($ExtractstatusCounter -gt 60) {
            Write-Warning -Message ('ExtractstatusCounter is greather than 60. Data extract might be uncomplete!' )
            $SuccessfullExtract = $false
        }
        else {
            $SuccessfullExtract = $true
        }

        #Output usefull verbose information
        $ExtractStatusEndtime = get-date
        Write-Verbose -Message ('Extract completed. Time elapsed: {0:mm} min {0:ss} sec' -f ($ExtractStatusEndtime - $ExtractStatusStartTime))

        #Create return results. Return the containerName since it's used for getting the blobs
        $results = @{
            ContainerName      = $ExtractStatus.container
            ExtractStatus      = $ExtractStatus
            SuccessfullExtract = $SuccessfullExtract
        }

        Return $results
    }
    catch {
        $ErrorMessage += 'Exception: '
        $ErrorMessage += $_
        $ErrorMessage += " `n"
        $ErrorMessage += 'Printix Request ID: '
        $ErrorMessage += $_.Exception.Response.GetResponseHeader('X-Printix-Request-ID')
        $ErrorMessage += " `n"
        $ErrorMessage += 'Uri: '
        $ErrorMessage += ('[{0}] or [{1}]' -f $ExtractRequest._links.self.href, $ExtractUri )
        $ErrorMessage += " `n"
        $ErrorMessage += 'Body: '
        $ErrorMessage += ('[{0}]' -f ($Requestbody | convertto-json) )
        $ErrorMessage += " `n"
        $ErrorMessage += 'Response: '
        $ErrorMessage += $_.Exception.Response
        $ErrorMessage += " `n"
        Write-Error -Message $ErrorMessage
    }

}