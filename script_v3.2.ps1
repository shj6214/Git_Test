

Connect-AzAccount
$SubscriptionId = '20e48f57-d5dd-4ab1-afc1-c425d5f933a5'
Set-AzContext -SubscriptionId $subscriptionId 
Enable-AzContextAutosave

## Start ## 
$RGName = "RG-DB"
$location = "eastus"
$startIp = "123.141.145.22"
$endip = "123.141.145.22"
$admin = "shjoo"
$Password = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$ServName = "dbServ"
New-AzResourceGroup -Name $RGName -Location $location 

#### mysql #### #### job 1 #### 

$job1 = Start-Job -Name job1 -ScriptBlock { param($RGName, $location, $admin, $startIp, $endip, $Password,$ServName) 
    
    # create administrator info & mysql server 
    New-AzMySqlServer -Name ("MYSQL"+$ServName) -ResourceGroupName $RGName -Sku "GP_Gen5_2" -GeoRedundantBackup "Enabled" -Location $location `
    -AdministratorUsername $admin -AdministratorLoginPassword $Password -SslEnforcement "Disabled"

    # create firewall rule
    New-AzMySqlFirewallRule -Name "Allow_Client_IP" -ResourceGroupName $RGName -ServerName ("MYSQL"+$ServName) -StartIPAddress $startIp -EndIPAddress $endip

} -ArgumentList $RGName, $location, $admin, $startIp, $endip, $Password, $ServName

### mssql job2 ###
$job2 = Start-Job -Name Job2 -ScriptBlock { param($RGName, $location, $admin, $startIp, $endip, $Password, $ServName)
    
    $dbName = "mssqldb-shj"
    $VNetName = "VNET-KC"
    $SubnetName = "SNET-FE-01"
    $PrivateEndpointName = "PE-KC-01"
    $SubnetAddressPrefix = "192.168.0.0/24"
    $vnetAddressPrefix = "192.168.0.0/16"
    
    $GroupID = "sqlserver"
    $PrivateLinkname = "PLINK-01"
    $privateEndpointName = "private-endpoint"
    
    $DNSZonename = "sql-dns-shj.database.windows.net"
    $DNSLinkname = "dns-link"
    $DNSZoneGroupName = "DNS-Zone-Group"

    $server = New-AzSqlServer -ResourceGroupName $RGName `
        -ServerName ("MSSQL"+$ServName) `
        -Location $location `
        -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList $admin, $password)
    
    New-AzSqlServerFirewallRule -ResourceGroupName $RGName `
        -ServerName ("MSSQL"+$ServName) `
        -FirewallRuleName "AllowedIPs" -StartIpAddress $startIp -EndIpAddress $endIp

    New-AzSqlDatabase -ResourceGroupName $RGName `
        -ServerName ("MSSQL"+$ServName) `
        -DatabaseName $dbName `
        -Edition GeneralPurpose `
        -ComputeModel Serverless `
        -ComputeGeneration Gen5 `
        -VCore 2 `
        -MinimumCapacity 2 `
        -SampleName "AdventureWorksLT"

    $subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -PrivateEndpointNetworkPoliciesFlag "Disabled"
    $vnet = New-AzVirtualNetwork -Name $Vnetname -ResourceGroupName $RGName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet 
    
    $SQLServerResourceId = (Get-AzSqlServer -Name ("MSSQL"+$ServName).ServerName).ResourceId
    $PrivateLink = New-AzPrivateLinkServiceConnection -Name $PrivateLinkname -privateLinkServiceId $SQLServerResourceId -GroupID $GroupID
    $privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName $RGName -Name $privateEndpointName -Location $location -Subnet $vnet.Subnets[0] -PrivateLinkServiceConnection $PrivateLink
    
    $DNSZone = New-AzPrivateDnsZone -ResourceGroupName $RGName -Name $DNSZonename
    $DNSLink = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName $DNSZonename -Name $DNSLinkname -VirtualNetworkId $vnet.Id
    $DNSConfig = New-AzPrivateDnsZoneConfig -Name $DNSZonename -PrivateDnsZoneId $DNSZone.ResourceId
    $DNSZone = New-AzPrivateDnsZoneGroup -ResourceGroupName $RGName -privateEndpointName $privateEndpointName -Name $DNSZoneGroupName -PrivateDnsZoneConfig $DNSConfig

} -ArgumentList $RGName, $location, $admin, $startIp, $endip, $Password, $ServName

#### redis #####
$job3 = Start-Job -Name Job3 { param($RGName, $location,$ServName) 
        New-AzRedisCache -ResourceGroupName $RGName -Name ("redis"+$ServName) -Location $location -Sku "Standard" -Size "C1"
} -ArgumentList $RGName, $location, $ServName
    
$job1
$job2
$job3
get-job 
get-job | Remove-Job
Receive-Job -Job $job1, $job2, $job3
Stop-Job $job1














