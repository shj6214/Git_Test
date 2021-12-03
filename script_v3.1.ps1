
#
Connect-AzAccount

#### mysql ####
### register Provider for Mysql & module install 
Register-AzResourceProvider -ProviderNamespace "Microsoft.DBforMySQL"
Install-Module -Name Az.MySql -AllowPrerelease

# declare variable 
$RGName_my = "rg-mysql"
$location = "eastus"
$ServName_my = "MysqlServShj"
$startIp = "123.141.145.22"
$endip = "123.141.145.22"
$admin = "shjoo"
$Password = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force

# resource group create 
New-AzResourceGroup -Name $RGName_my -Location $location1

# create administrator info & mysql server 
New-AzMySqlServer -Name $ServName_my -ResourceGroupName $RGName_my -Sku "GP_Gen5_2" -GeoRedundantBackup "Enabled" -Location $location `
-AdministratorUsername $admin -AdministratorLoginPassword $Password -SslEnforcement "Disabled"

# create firewall rule
New-AzMySqlFirewallRule -Name "Allow_Client_IP" -ResourceGroupName $RGName1 -ServerName $ServName1 -StartIPAddress $startIp -EndIPAddress $endip

# Get Connection info 
Get-AzMySqlServer -Name $ServName1 -ResourceGroupName $RGName1 | Select-Object -Property FullyQualifiedDomainName, AdministratorLogin

# Connect to Server 
mysql -h mysqlservshj.mysql.database.azure.com -u shjoo@mysqlservshj -p



#### mssql 2 ####
# The SubscriptionId in which to create these objects
$SubscriptionId = '20e48f57-d5dd-4ab1-afc1-c425d5f933a5'
Set-AzContext -SubscriptionId $subscriptionId 

# Set the resource group name and location for your server
$RGName_ms = "rg-mssql"
$location_ms = "eastus"

# Set an admin login and password for your server
$admin = "shjoo"
$Password = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force

# Set server name - the logical server name has to be unique in the system
$serverName = "mssql-shj"
$dbName = "mssqldb-shj"

# The ip address range that you want to allow to access your server
$startIp = "123.141.145.23"
$endIp = "123.141.145.23"

# Create a resource group
New-AzResourceGroup -Name $RGName_ms -Location $location_ms

# Create a server with a system wide unique server name
$server = New-AzSqlServer -ResourceGroupName $RGName_ms `
    -ServerName $serverName `
    -Location $location_ms `
    -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential `
    -ArgumentList $admin, $password)
 
# Create a server firewall rule that allows access from the specified IP range
New-AzSqlServerFirewallRule -ResourceGroupName $RGName_ms `
    -ServerName $serverName `
    -FirewallRuleName "AllowedIPs" -StartIpAddress $startIp -EndIpAddress $endIp
#$serverFirewallRule

# create single database
New-AzSqlDatabase -ResourceGroupName $RGName_ms `
    -ServerName $serverName `
    -DatabaseName $dbName `
    -Edition GeneralPurpose `
    -ComputeModel Serverless `
    -ComputeGeneration Gen5 `
    -VCore 2 `
    -MinimumCapacity 2 `
    -SampleName "AdventureWorksLT"
# $database

# Get Connection info 
Get-AzSqlServer -Name $server.ServerName -ResourceGroupName $RGName_ms | Select-Object -Property FullyQualifiedDomainName, AdministratorLogin

# Name of the existing virtual network
$VNetName = "VNET-KC"
$SubnetName = "SNET-FE-01"
$PrivateEndpointName = "PE-KC-01"
$SubnetAddressPrefix = "192.168.0.0/24"
$vnetAddressPrefix = "192.168.0.0/16"
$GroupID = "sqlserver"
$PrivateLinkname = "PLINK-01"
$privateEndpointName = "private-endpoint"

$subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix `
-PrivateEndpointNetworkPoliciesFlag "Disabled"
$vnet = New-AzVirtualNetwork -Name $Vnetname -ResourceGroupName $RGName_ms -Location $location_ms -AddressPrefix $vnetAddressPrefix -Subnet $subnet 
$SQLServerResourceId = (Get-AzSqlServer -Name $server.ServerName).ResourceId

$PrivateLink = New-AzPrivateLinkServiceConnection -Name $PrivateLinkname -privateLinkServiceId $SQLServerResourceId -GroupID $GroupID
$privateEndpoint = New-AzPrivateEndpoint -ResourceGroupName $RGName_ms -Name $privateEndpointName -Location $location_ms -Subnet $vnet.Subnets[0] -PrivateLinkServiceConnection $PrivateLink

# 프라이빗 DNS 구성# PRIVATE DNS ZONE
$DNSZonename = "sql-dns-shj.database.windows.net"
$DNSZone = New-AzPrivateDnsZone -ResourceGroupName $RGName_ms -Name $DNSZonename

# dns network link 
# 프라이빗 DNS 영역 및 가상 네트워크와 연결된 새 가상 네트워크 링크 
$DNSLinkname = "dns-link"
$DNSLink = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName_ms -ZoneName $DNSZonename -Name $DNSLinkname -VirtualNetworkId $vnet.Id

# Dns Configuration
$DNSConfig = New-AzPrivateDnsZoneConfig -Name $DNSZonename -PrivateDnsZoneId $DNSZone.ResourceId

# DNS ZONE 생성
# 지정된 프라이빗 엔드포인트에 프라이빗 DNS 영역 그룹을 생성
$DNSZoneGroupName = "DNS-Zone-Group"
$DNSZone = New-AzPrivateDnsZoneGroup -ResourceGroupName $RGName_ms -privateEndpointName $privateEndpointName -Name $DNSZoneGroupName -PrivateDnsZoneConfig $DNSConfig

# Azure 서비스 및 리소스가 이 서버에 액세스할 수 있도록 허용 : 보안 공격 취약
# 

##

##
# Clean up deployment
# Remove-AzResourceGroup -ResourceGroupName $resourceGroupName

#################################
#### redis #####

$SubscriptionId = "20e48f57-d5dd-4ab1-afc1-c425d5f933a5"

# Resource group where the Azure Cache for Redis instance and virtual network resources are located
$RGName_rd = "rg-redis"

# Name of the Azure Cache for Redis instance
$redisName = "redisinstance"

# Location where the private endpoint can be created. The private endpoint should be created in the same location where your subnet or the virtual network exists
$Location_rd = "North Central US"
New-AzResourceGroup -Name $RGName_rd -Location $location_rd

# create redis cache
New-AzRedisCache -ResourceGroupName $RGName_rd -Name $redisName -Location $location_rd `
-Sku "Standard" -Size "C1" 


























