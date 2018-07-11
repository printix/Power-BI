<#
    .SYNOPSIS
    This script will extract relevant data from the Printix API, process it and make it ready for use for the Power BI report.

    .DESCRIPTION
    This script will extract relevant data from the Printix API which in turn will upload the extracted data to a specified Azure Storage account.
    This script will then temporary download the ZIP files from that storage account, unzip the content and format the files as UTF-8, before uploading the files to a specified Azure storage account and container.

    .PARAMETER PrintixCustomerID
    This is the Printix Customer ID. You can get this by contacting Printix support.

    .PARAMETER ClientCredentialsName
    This is the name of the credential asset, with the Printix clientId and secret.

    .PARAMETER DeleteExtractedData
    If true, the script will delete the extract data from the source blob

    .PARAMETER DaysToExtract
    Number of days with data to extract (1-89)

    .EXAMPLE
    Get-PrintixData -PrintixCustomerID '45dbbbbb-62929-1111-4444-15153b055555' -ClientCredentialsName 'PrintixClientCredentials' -DeleteExtractedData $true -DaysToExtract 5

    This will get all tenants extract data for the last 5 months, for the given CustomerID, using the PrintixClientCredentials credential asset before deleting the extracted data.

#>

param (
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 0, HelpMessage = 'This is the Printix Customer ID')]
    [String] $PrintixCustomerID = 'bc274346-8827-4562-a685-1e4b414f9865',
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 1, HelpMessage = 'This is the name of the credential asset, with the Printix clientId and secret.')]
    [String]$ClientCredentialsName = 'printix',
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 2, HelpMessage = 'If true, the script will delete the extract data from the source blob')]
    [bool]$DeleteExtractedData = $true,
    [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, Position = 3, HelpMessage = 'Number of days of data to extract from Printix. Valid data range is: 1-89')]
    [ValidateRange(1, 89)]
    [int]$DaysToExtract = 6
)

# (To keep the code base as minimal as possible, we use the same StorageMapping object in both the Partner and Direct customer runbook.)
#This object is used for mapping the different printix tenants, to different Azure storage accounts and/or containers.
#StorageAccountPrintixExtractedData is the storage account where the extracted printix data will be temporary stored
#StorageAccountPrintixExtractedDataResourceGroup is the resource group name of the StorageAccountPrintixExtractedData
#Fill in the TenantDomain, StorageAccount name, resource group and Container name where you want to store the processed data.
[PSCustomObject]$StorageMapping = @{
    StorageAccountPrintixExtractedData              = 'powerbiprintixironit'
    StorageAccountPrintixExtractedDataResourceGroup = 'PrintixPowerBI-Development-rg'
    Tenants                                         = @(
        [PSCustomObject]@{
            TenantDomain   = 'ironstoneit.printix.net'
            StorageAccount = 'powerbiprintixironit'
            ResourceGroup  = 'PrintixPowerBI-Development-rg'
            ContainerName  = 'production'
        }
    )
}

#For more detailed outputs, set the VerbosePreference to Continue
$VerbosePreference = 'SilentlyContinue'

#Do not change the ErrorAction
$ErrorActionPreference = 'stop'

#Timestamp format for logs
$Global:TimestampFormat = 'HH:mm:ss'

Try {

    # Get the connection "AzureRunAsConnection" Service Principal Connection
    $servicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection'  -ErrorAction SilentlyContinue
    If ($servicePrincipalConnection) {
        Try {
            $null = Add-AzureRmAccount `
                -ServicePrincipal `
                -TenantId $servicePrincipalConnection.TenantId `
                -ApplicationId $servicePrincipalConnection.ApplicationId `
                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                -ErrorAction Stop

            Write-Output -InputObject ('{0} - Successfuly connected to Azure with Service Principal.' -f (Get-Date -format $Global:TimestampFormat))
        }
        Catch {
            $ErrorMessage = 'Login to Azure failed with Service Principal.'
            $ErrorMessage += " `n"
            $ErrorMessage += 'Error: '
            $ErrorMessage += $_
            Write-Error -Message $ErrorMessage `
                -ErrorAction Stop
        }
    }

    #Azure
    Write-output -InputObject ('{0} - Getting AutomationPSCredential [{1}].' -f (Get-Date -format $Global:TimestampFormat), $ClientCredentialsName)
    $Global:ClientCredentials = Get-AutomationPSCredential -Name $ClientCredentialsName
    #Verify that we found the client credentials we need
    if ([string]::IsNullOrEmpty($global:ClientCredentials)) {
        throw ('{0} - Could not retrieve [{1}] credential. Check that you created this first in the Automation account.' -f (Get-Date -format $Global:TimestampFormat), $ClientCredentials)
    }

    #Verify that the storage accounts specified in the $StorageMapping actually exist
    $null = Get-AzureRmStorageaccount -StorageAccountName $StorageMapping.StorageAccountPrintixExtractedData -ResourceGroupName $StorageMapping.StorageAccountPrintixExtractedDataResourceGroup
    foreach ($Tenant in $StorageMapping.tenants) {
        $null = Get-AzureRmStorageaccount -StorageAccountName $Tenant.StorageAccount -ResourceGroupName $tenant.ResourceGroup
    }

    #Request the Data Extract
    Write-Output -InputObject ('{0} -   Requesting data extract. This might take some time...' -f (Get-Date -format $Global:TimestampFormat))
    $ExtractResults = New-PrintixDataExtract -StorageMapping $StorageMapping -DaysToExtract $DaysToExtract -ExtractUri ('https://api.printix.net/tenants/{0}/dataextract' -f $PrintixCustomerID)

    if ($ExtractResults.SuccessfullExtract) {

        #To keep the code base as minimal as possible, we use the same StorageMapping object in both the Partner and Direct customer runbook.
        #This is the direct customer runbook, so we can also assume that we can get the first tenant object.
        $TenantStorageInfo = $StorageMapping.Tenants[0]

        #Get the storage and container context for the extracted data
        Write-Output -InputObject ('{0} -     Getting Azure Storage account [{1}] in Resource group [{2}]' -f (Get-Date -format $Global:TimestampFormat), $StorageMapping.StorageAccountPrintixExtractedData, $StorageMapping.StorageAccountPrintixExtractedDataResourceGroup)
        $StorageAccountPrintixContext = Get-AzureRmStorageaccount -Name $StorageMapping.StorageAccountPrintixExtractedData -ResourceGroupName $StorageMapping.StorageAccountPrintixExtractedDataResourceGroup
        Write-Output -InputObject ('{0} -     Getting Azure Storage container [{1}] ' -f (Get-Date -format $Global:TimestampFormat), $ExtractResults.ContainerName)
        $StorageContainerPrintixExtract = Get-AzureStorageContainer -Name $ExtractResults.ContainerName -Context $StorageAccountPrintixContext.Context

        #Get the storage and container context for the destination data
        #To keep the code base as minimal as possible, we use the same StorageMapping object in both the Partner and Direct customer runbook.
        #This is the direct customer runbook, so we can  assume that we can get the first tenant object.
        $TenantStorageInfo = $StorageMapping.Tenants[0]
        Write-Output -InputObject ('{0} -     Getting Azure Storage account [{1}] in Resource group [{2}]' -f (Get-Date -format $Global:TimestampFormat), $TenantStorageInfo.StorageAccount, $TenantStorageInfo.ResourceGroup)
        $StorageAccountTenantContext = Get-AzureRmStorageaccount -Name $TenantStorageInfo.StorageAccount -ResourceGroupName $TenantStorageInfo.ResourceGroup
        Write-Output -InputObject ('{0} -     Getting Azure Storage container [{1}] ' -f (Get-Date -format $Global:TimestampFormat), $TenantStorageInfo.ContainerName)
        $StorageContainerTenant = Get-AzureStorageContainer -Name $TenantStorageInfo.ContainerName -Context $StorageAccountTenantContext.Context -ErrorAction SilentlyContinue

        #If the destination container does not exist, create it
        if ([string]::IsNullOrEmpty($StorageContainerTenant)) {
            Write-Output -InputObject ('{0} -         Azure Storage container [{1}] does not exist, creating it' -f (Get-Date -format $Global:TimestampFormat), $TenantStorageInfo.ContainerName)
            $StorageContainerTenant = New-AzureStorageContainer -Name ($TenantStorageInfo.ContainerName).ToLowerInvariant() -Context $StorageAccountTenantContext.Context
        }

        #Get content from the extracted data, and store it in the destination container
        Foreach ($ExtractType in $ExtractResults.ExtractStatus.extractStatuses.type) {

            #Create object names
            $CloudBlobContainerName = $ExtractType
            $DestinationPath = ('{0}\{1}' -f $env:TEMP, $CloudBlobContainerName)
            $SourcePath = ('{0}.zip' -f $DestinationPath)
            $DestFile = ('{0}\{1}.json' -f $DestinationPath, $CloudBlobContainerName)
            $DestFileTemp = ('{0}\{1}_TEMP.json' -f $DestinationPath, $CloudBlobContainerName)
            $BlobDestination = ('{0}\{0}.json' -f $CloudBlobContainerName)
            $CloudBlobContainer = [array]($StorageContainerPrintixExtract.CloudBlobContainer.ListBlobs()) | where-object {$_.name -match ($CloudBlobContainerName.replace('_', '-')) }

            #Get the AzureBlobContent and store it for unzipping
            Write-Output -InputObject ('{0} -         Getting Azure Storage Blob Content from cludblob [{1}]' -f (Get-Date -format $Global:TimestampFormat), $CloudBlobContainer.name)
            $null = Get-AzureStorageBlobContent -CloudBlob $CloudBlobContainer -Context $StorageContainerPrintixExtract.Context -Destination $SourcePath -Force

            #Unzip the content
            Write-Output -InputObject ('{0} -             Unzipping file [{1}]' -f (Get-Date -format $Global:TimestampFormat), $SourcePath)
            $null = Expand-Archive -Path $SourcePath -DestinationPath $DestinationPath -force

            #Verify that we actually have data in our file
            $ItemLength = Get-Item -Path $DestFile -ErrorAction SilentlyContinue
            if ($ItemLength.length -lt 20) {
                Write-Warning -Message ('{0} -              [{1}] does not seem to have any content. Skipping file' -f (Get-Date -format $Global:TimestampFormat), $CloudBlobContainerName)
            }
            elseif ([string]::IsNullOrEmpty($ItemLength)) {
                Throw ('{0} -             Unable to get file [{1}] content. Skipping file' -f (Get-Date -format $Global:TimestampFormat), $DestFile)
            }
            else {

                #Make sure the file is UTF-8 encoded
                Write-Output -InputObject ('{0} -             Changing encoding to [UTF8]' -f (Get-Date -format $Global:TimestampFormat) )
                $null = [Io.File]::ReadAllText($DestFile) | Out-File -FilePath $DestFileTemp -Encoding utf8
                $null = Remove-item -Path $DestFile -Force
                $null = Rename-Item -Path $DestFileTemp -NewName $DestFile

                #Upload to destination blob
                Write-Output -InputObject ('{0} -             Uploading file to container [{1}]' -f (Get-Date -format $Global:TimestampFormat), $TenantStorageInfo.ContainerName)
                $null = Set-AzureStorageBlobContent -File $DestFile -Context $StorageContainerTenant.Context -Container $TenantStorageInfo.ContainerName -Blob $BlobDestination -Force
            }

        } #end for each

        #Delete the extract container
        if ($DeleteExtractedData) {
            Write-Output -InputObject ('{0} -         Deleting container [{1}]' -f (Get-Date -format $Global:TimestampFormat), $ExtractResults.ContainerName)
            Remove-AzureStorageContainer -Name $ExtractResults.ContainerName -Context $StorageAccountPrintixContext.context -force
        }

    } #end if
    else {
        Write-warning -Message ('{0} - Unable to get a successfull extract. Error: {1}' -f (Get-Date -format $Global:TimestampFormat), $ExtractResults.ExtractStatus)
    } #End else

    Write-Output -InputObject ('{0} - Successfully extracted data.' -f (Get-Date -format $Global:TimestampFormat))
} #end try
catch {
    # Construct Message
    $ErrorMessage = " `n"
    $ErrorMessage += 'Exception: '
    $ErrorMessage += $_.Exception
    $ErrorMessage += " `n"
    $ErrorMessage += 'Activity: '
    $ErrorMessage += $_.CategoryInfo.Activity
    $ErrorMessage += " `n"
    $ErrorMessage += 'Error Category: '
    $ErrorMessage += $_.CategoryInfo.Category
    $ErrorMessage += " `n"
    $ErrorMessage += 'Error Reason: '
    $ErrorMessage += $_.CategoryInfo.Reason
    throw $ErrorMessage
}