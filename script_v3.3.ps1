
Connect-AzAccount

## 공통 변수 ## 
$RGName = "RG-DB"
$location = "eastus"
$startIp = "123.141.145.23"
$endip = "123.141.145.23"
$admin = "shjoo"
$Password = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$ServName = "dbserv"
New-AzResourceGroup -Name $RGName -Location $location

#### mysql job 1 #### 
$job1 = Start-Job -Name job1 -ScriptBlock { param($RGName, $location, $admin, $startIp, $endip, $Password, $ServName)
    
    # mysql 서버 생성 + 관리자 계정 정보 및 SKU, SSL 비활성화, 지리적 중복 옵션. 
    New-AzMySqlServer -Name ("mysql"+$ServName) -ResourceGroupName $RGName -Sku "GP_Gen5_2" -GeoRedundantBackup "Enabled" -Location $location `
    -AdministratorUsername $admin -AdministratorLoginPassword $Password -SslEnforcement "Disabled"

    # 클라이언트에서 접근할 수 있도록 서버 방화벽 규칙 추가. 
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


    # 서브넷 생성 -> Endpoint 관련 설정 추가
    $subnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix -PrivateEndpointNetworkPoliciesFlag "Disabled" `
    -ServiceEndpoint "Microsoft.Sql"
    
    # VNET 생성 및 Subnet 연결 
    $vnet = New-AzVirtualNetwork -Name $Vnetname -ResourceGroupName $RGName -Location $location -AddressPrefix $vnetAddressPrefix -Subnet $subnet
    $vnet | Set-AzVirtualNetwork 

    # SQL Server 생성 
    New-AzSqlServer -ResourceGroupName $RGName `
        -ServerName ("mssql"+$ServName) `
        -Location $location `
        -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList $admin, $password)

    # 특정 IP 대역으로 접근하기 위한 방화벽 룰 생성
    New-AzSqlServerFirewallRule -ResourceGroupName $RGName `
        -ServerName ("mssql"+$ServName) `
        -FirewallRuleName "AllowedIPs" -StartIpAddress $startIp -EndIpAddress $endIp
    
    # SQL DB 생성
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

    # 프라이빗 커넥션 연결 설정 및 Endpoint 생성
    $PrivateLink = New-AzPrivateLinkServiceConnection -Name $PrivateLinkname -privateLinkServiceId $SQLServerResourceId.ResourceId -GroupID $GroupID
    New-AzPrivateEndpoint -ResourceGroupName $RGName -Name $privateEndpointName -Location $location -Subnet $vnet.Subnets[0] -PrivateLinkServiceConnection $PrivateLink
    
    # VNET 규칙 생성 
    New-AzSqlServerVirtualNetworkRule -VirtualNetworkRuleName $VNetRuleName `
	 	-VirtualNetworkSubnetId $vnet.Subnets[0].Id `
	 	-ServerName ("mssql"+$ServName) `
	 	-ResourceGroupName $RGName

    # zone, Link, config 생성 
    $DNSZone = New-AzPrivateDnsZone -ResourceGroupName $RGName -Name $DNSZonename
    New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $RGName -ZoneName $DNSZonename -Name $DNSLinkname -VirtualNetworkId $vnet.Id
    $DNSConfig = New-AzPrivateDnsZoneConfig -Name $DNSZonename -PrivateDnsZoneId $DNSZone.ResourceId
    New-AzPrivateDnsZoneGroup -ResourceGroupName $RGName -privateEndpointName $privateEndpointName -Name $DNSZoneGroupName -PrivateDnsZoneConfig $DNSConfig

} -ArgumentList $RGName, $location, $admin, $startIp, $endip, $Password, $ServName

#### redis #####
$job3 = Start-Job -Name Job3 -ScriptBlock { param($RGName, $location,$ServName)
        New-AzRedisCache -ResourceGroupName $RGName -Name ("redis"+$ServName) -Location $location -Sku "Standard" -Size "C1"
} -ArgumentList $RGName, $location, $ServName
        













