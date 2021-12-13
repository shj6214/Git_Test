
# Azure 계정 연결  
Connect-AzAccount

# csv 파일 임포트 선언
$resourceinfos = Import-csv -Path "C:\Users\20132\git_test\resource_v4.2.csv"

$RG = $resourceinfos | Where-Object {$_.kind -eq "resourcegroup"}
$Vnets = $resourceinfos | Where-Object {$_.kind -eq "vnet"}
$Subnets = $resourceinfos | Where-Object {$_.kind -eq "subnet"}

$nsgs = $resourceinfos | Where-Object {$_.kind -eq "nsg"}
$nsgrules = $resourceinfos | Where-Object {$_.kind -eq "nsgrule"}

$VMs = $resourceinfos | Where-Object {$_.kind -eq "vm"}
$VMAdminUser = "shjoo"
$VMAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($VMAdminUser, $VMAdminSecurePassword);

New-AzResourceGroup -Name $RG.name -Location $RG.region

##

# VNET 및 SUBNET 배포 ( VNET 2 EA / SUBNET 2 EA )
foreach($vnet in $vnets){
    $new_vnet = New-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $vnet.refer -Location $vnet.region -AddressPrefix $vnet.ipaddress
    foreach($subnet in $Subnets){
        #if($new_vnet.name -eq $subnet.refer){ # vnet.name과 subnet.refer와 같을 경우 서브넷 생성
            Add-AzVirtualNetworkSubnetConfig -Name $subnet.name -AddressPrefix $subnet.ipaddress -VirtualNetwork $new_vnet
            Set-AzVirtualNetwork -VirtualNetwork $new_vnet
        #}
    }
}

# NSG 2 EA RULE 4 EA 매핑
foreach($nsg in $nsgs){
    $new_nsg = New-AzNetworkSecurityGroup -ResourceGroupName $nsg.refer -Location $nsg.region -Name $nsg.name
    $nsgrules = $resourceinfos | Where-Object {$_.refer -eq $nsg.Name}
    foreach($nsgrule in $nsgrules){
            Add-AzNetworkSecurityRuleConfig -Name $nsgrule.name -Description $nsgrule.Desc -Access "Allow" -Protocol $nsgrule.protocol -Direction Inbound -Priority $nsgrule.priority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $nsgrule.destport `
            -NetworkSecurityGroup $new_nsg
            $new_nsg | Set-AzNetworkSecurityGroup
    }
}


# VM 4 대 배포
foreach($VM in $VMs){
    Start-Job -Name ($VM.name+"-Job") -ScriptBlock { param($VM, $Cred)

        $pip = New-AzPublicIpAddress -Name ($VM.name+"-pip") -ResourceGroupName $vm.rg -AllocationMethod Static -Location $vm.region -Sku "Standard" 
        $vnet = Get-Azvirtualnetwork -name $VM.refer -ResourceGroupName $vm.rg
        $nsg = Get-AzNetworkSecurityGroup -Name $VM.nsg
        $nic = New-AzNetworkInterface -ResourceGroupName $VM.rg -Location $VM.region `
        -Name ($VM.name+"-NIC") -SubnetId $vnet.subnets.Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

        $VMConfig=@{ VMName=$VM.name; VMSize=$VM.size}
        $osconfig = @{ ComputerName=$VM.name; Credential=$cred }
        $image = @{ PublisherName=$VM.publisher; Offer=$VM.offer; Skus=$VM.sku; Version="latest" }

        if($vm.ostype -eq "Windows"){
            $VMConfigs = New-AzVMConfig @VMConfig | Set-AzVMOperatingSystem @osconfig -Windows | Set-AzVMSourceImage @image | Add-AzVMNetworkInterface -Id $nic.id
            $VirtualMachine = @{ VM=$VMConfigs; ResourceGroupName=$VM.rg; Location=$VM.region }
            New-AzVM @VirtualMachine -Verbose
        }
        else {
            $VMConfigs = New-AzVMConfig @VMConfig | Set-AzVMOperatingSystem @osconfig -Linux | Set-AzVMSourceImage @image | Add-AzVMNetworkInterface -Id $nic.id
            $VirtualMachine = @{ VM=$VMConfigs; ResourceGroupName=$VM.rg; Location=$VM.region }
            New-AzVM @VirtualMachine -Verbose
        }
  } -ArgumentList $VM, $Cred
}

get-job -Name "vm-ue-*"
get-job | Remove-Job
Receive-Job -Name "vm-ue-*-Job"
stop-job "vm-ue-*-Job"

##

# 참조
# $vmvnet = Get-Azvirtualnetwork -name $vmcreate.tag -ResourceGroupName $vmcreate.rg
# $nic = New-AzNetworkInterface -Name ($vmcreate.name + "NIC") -ResourceGroupName $vmcreate.rg -Location $vmcreate.location -SubnetId $vmvnet.Subnets.Id -PrivateIpAddress $vmcreate.ip

# VNET Peering 변수 선언(vnet_UE-01,02)
$get_vnet_1 = Get-AzVirtualNetwork -Name "vnet*01"
$get_vnet_2 = Get-AzVirtualNetwork -Name "vnet*02"

# 동일 리전간 Peering ( UE <-> UE 2 )
# UE-01 <-> UE-02
    Add-AzVirtualNetworkPeering -Name ($get_vnet_1.name + "-To-" + $get_vnet_2.name) -VirtualNetwork $get_vnet_1 -RemoteVirtualNetworkId $get_vnet_2.id -AllowForwardedTraffic
    Add-AzVirtualNetworkPeering -Name ($get_vnet_2.name + "-To-" + $get_vnet_1.name) -VirtualNetwork $get_vnet_2 -RemoteVirtualNetworkId $get_vnet_1.id -AllowForwardedTraffic

###########################


### mssql job2 ###
$mssql = $resourceinfos | Where-Object {$_.kind -eq "sql"}

$job2 = Start-Job -Name "Job2" -ScriptBlock { param($mssql, $VMAdminUser, $VMAdminSecurePassword)

    $vnet = Get-AzVirtualNetwork -Name $mssql.refer -ResourceGroupName $mssql.rg
    $rg = Get-AzResourceGroup -Name $mssql.rg

    $PrivateLinkname = "PLINK-01"
    $PrivateEndpointName = "PE-01"
    
    $DNSZonename = "sql-dns-shj.database.windows.net"
    $DNSLinkname = "dns-link"
    $DNSZoneGroupName = "DNS-Zone-Group"

    # 서브넷 생성 -> Endpoint 관련 설정 추가
    set-AzVirtualNetworkSubnetConfig -Name $vnet.subnets.name -AddressPrefix $vnet.Subnets.AddressPrefix -PrivateEndpointNetworkPoliciesFlag "Disabled" `
    -ServiceEndpoint "Microsoft.Sql" -VirtualNetwork $vnet | Set-AzVirtualNetwork
    
    # SQL Server 생성
    New-AzSqlServer -ResourceGroupName $rg.ResourceGroupName `
        -ServerName ($mssql.name+"-serv") `
        -Location $mssql.region `
        -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential `
        -ArgumentList $VMAdminUser, $VMAdminSecurePassword)

    # 특정 IP 대역으로 접근하기 위한 방화벽 룰 생성
    New-AzSqlServerFirewallRule -ResourceGroupName $rg.ResourceGroupName -ServerName ($mssql.name+"-serv") `
        -FirewallRuleName "AllowedIPs" -StartIpAddress $mssql.ipaddress -EndIpAddress $mssql.ipaddress
    
    # SQL DB 생성
    New-AzSqlDatabase -ResourceGroupName $rg.ResourceGroupName -ServerName ($mssql.name+"-serv") `
        -DatabaseName ($mssql.name+"-db") -Edition "GeneralPurpose" `
        -ComputeModel "Serverless" -ComputeGeneration "Gen5" `
        -VCore 2 -MinimumCapacity 2 -SampleName "AdventureWorksLT"

    # 프라이빗 커넥션 연결 설정 및 Endpoint 생성
    $SQLServerResourceId = (Get-AzSqlServer -Name ($mssql.name+"-serv"))
    $subnet = $vnet | Select-Object -ExpandProperty subnets
    $PrivateLink = New-AzPrivateLinkServiceConnection -Name $PrivateLinkname -privateLinkServiceId $SQLServerResourceId.ResourceId -GroupID "sqlserver"
    New-AzPrivateEndpoint -ResourceGroupName $rg.ResourceGroupName -Name $privateEndpointName -Location $mssql.region -Subnet $subnet -PrivateLinkServiceConnection $PrivateLink

    # VNET 규칙 생성 
    New-AzSqlServerVirtualNetworkRule -VirtualNetworkRuleName ($vnet.name+"-rule") -VirtualNetworkSubnetId $vnet.Subnets.Id `
	-ServerName ($mssql.name+"-serv") -ResourceGroupName $rg.ResourceGroupName

    # zone, Link, config 생성
    $DNSZone = New-AzPrivateDnsZone -ResourceGroupName $rg.ResourceGroupName -Name $DNSZonename
    
    New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $rg.ResourceGroupName -ZoneName $DNSZonename -Name $DNSLinkname -VirtualNetworkId $vnet.Id
    
    $DNSConfig = New-AzPrivateDnsZoneConfig -Name $DNSZonename -PrivateDnsZoneId $DNSZone.ResourceId

    New-AzPrivateDnsZoneGroup -ResourceGroupName $rg.ResourceGroupName -privateEndpointName $privateEndpointName -Name $DNSZoneGroupName -PrivateDnsZoneConfig $DNSConfig

} -ArgumentList $mssql, $VMAdminUser, $VMAdminSecurePassword

get-job
get-job | Remove-Job
receive-job -Job $job2
Stop-Job $job2

###########################
$test2 = @{
    network = $new_vnet.Subnets
}

Start-Job -Name "test" -ScriptBlock { param($test2)
    $test2.Subnets
    # $test2
} -ArgumentList $test2

Receive-Job -Name test


# if ($i -eq 1) { # NIC01일 경우(window vm)
#     $nic = @{
#         Name = "NIC0$i"
#         resourcegroupname = $ResourceGroupName
#         location = $Location
#         Subnet = $Vnet.Subnets[0]
#         NetworkSecurityGroup = $NSG
#         PublicIpAddress = $PIP # PUBLIC IP 생성
#     }
#     $nicVM = New-AzNetworkInterface @nic

