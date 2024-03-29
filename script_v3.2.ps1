
Connect-AzAccount
# $SubscriptionId = '20e48f57-d5dd-4ab1-afc1-c425d5f933a5'
# Set-AzContext -SubscriptionId $subscriptionId 
# Enable-AzContextAutosave

## Start ## 
$RGName = "RG-DB"
$location = "eastus"
$startIp = "123.141.145.23"
$endip = "123.141.145.23"
$admin = "shjoo"
$Password = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$ServName = "dbserv"
New-AzResourceGroup -Name $RGName -Location $location

#### mysql #### #### job 1 #### 

$job1 = Start-Job -Name job1 -ScriptBlock { param($RGName, $location, $admin, $startIp, $endip, $Password, $ServName)
    
    # create administrator info & mysql server 
    New-AzMySqlServer -Name ("mysql"+$ServName) -ResourceGroupName $RGName -Sku "GP_Gen5_2" -GeoRedundantBackup "Enabled" -Location $location `
    -AdministratorUsername $admin -AdministratorLoginPassword $Password -SslEnforcement "Disabled"

    # create firewall rule
    New-AzMySqlFirewallRule -Name "Allow_Client_IP" -ResourceGroupName $RGName -ServerName ("mysql"+$ServName) -StartIPAddress $startIp -EndIPAddress $endip
    
} -ArgumentList $RGName, $location, $admin, $startIp, $endip, $Password, $ServName

### mssql job2 ###
$job2 = Start-Job -Name Job2 -ScriptBlock { param($RGName, $location, $admin, $startIp, $endip, $Password, $ServName)
    
    $dbName = "mssqldb-shj"
    $VNetName = "VNET-UE"
    $VNetRuleName = "VNET-UE"
    $SubnetName = "SNET-FE-01"
    $PrivateEndpointName = "PE-UE-01"
    $SubnetAddressPrefix = "192.168.0.0/24"
    $vnetAddressPrefix = "192.168.0.0/16"
    
    $GroupID = "sqlserver"
    $PrivateLinkname = "PLINK-01"
    $privateEndpointName = "private-endpoint"
    
    $DNSZonename = "sql-dns-shj.database.windows.net"
    $DNSLinkname = "dns-link"
    $DNSZoneGroupName = "DNS-Zone-Group"

    $subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -PrivateEndpointNetworkPoliciesFlag "Disabled" `
    -ServiceEndpoint "Microsoft.Sql" 
    
    $vnet = New-AzVirtualNetwork -Name $Vnetname -ResourceGroupName $RGName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
    $vnet | Set-AzVirtualNetwork 

    $server = New-AzSqlServer -ResourceGroupName $RGName `
        -ServerName ("mssql"+$ServName) `
        -Location $location `
        -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList $admin, $password)

    New-AzSqlServerFirewallRule -ResourceGroupName $RGName `
        -ServerName ("mssql"+$ServName) `
        -FirewallRuleName "AllowedIPs" -StartIpAddress $startIp -EndIpAddress $endIp

    New-AzSqlDatabase -ResourceGroupName $RGName `
        -ServerName ("mssql"+$ServName) `
        -DatabaseName $dbName `
        -Edition GeneralPurpose `
        -ComputeModel Serverless `
        -ComputeGeneration Gen5 `
        -VCore 2 `
        -MinimumCapacity 2 `
        -SampleName "AdventureWorksLT"

    $SQLServerResourceId = (Get-AzSqlServer -Name ("mssql"+$ServName))
    $PrivateLink = New-AzPrivateLinkServiceConnection -Name $PrivateLinkname -privateLinkServiceId $SQLServerResourceId.ResourceId -GroupID $GroupID
    $privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName $RGName -Name $privateEndpointName -Location $location -Subnet $vnet.Subnets[0] -PrivateLinkServiceConnection $PrivateLink
    
    $new_rule = New-AzSqlServerVirtualNetworkRule -VirtualNetworkRuleName $VNetRuleName `
	 	-VirtualNetworkSubnetId $vnet.Subnets[0].Id `
	 	-ServerName ("mssql"+$ServName) `
	 	-ResourceGroupName $RGName

    $DNSZone = New-AzPrivateDnsZone -ResourceGroupName $RGName -Name $DNSZonename
    $DNSLink = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName $DNSZonename -Name $DNSLinkname -VirtualNetworkId $vnet.Id
    $DNSConfig = New-AzPrivateDnsZoneConfig -Name $DNSZonename -PrivateDnsZoneId $DNSZone.ResourceId
    $DNSZone = New-AzPrivateDnsZoneGroup -ResourceGroupName $RGName -privateEndpointName $privateEndpointName -Name $DNSZoneGroupName -PrivateDnsZoneConfig $DNSConfig

} -ArgumentList $RGName, $location, $admin, $startIp, $endip, $Password, $ServName

#### redis #####
$job3 = Start-Job -Name Job3 -ScriptBlock { param($RGName, $location,$ServName) 
        New-AzRedisCache -ResourceGroupName $RGName -Name ("redis"+$ServName) -Location $location -Sku "Standard" -Size "C1"
} -ArgumentList $RGName, $location, $ServName
        
$job1
$job2
$job3
get-job 
get-job | Remove-Job
Receive-Job -Job $job1
Receive-Job -Job $job2
Receive-Job -Job $job3
Stop-Job $job1
Stop-Job $job2
Stop-Job $job3















