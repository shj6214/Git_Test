
# Azure 계정 연결  
Connect-AzAccount

# csv 파일 임포트 선언
$resourceinfos = Import-csv -Path "C:\Users\shj\shtest\Git_Test\resource_v4.1.csv"

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

# VNET 및 SUBNET 배포 ( VNET 2 EA / SUBNET 2 EA )
foreach($vnet in $vnets){
    $new_vnet = New-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $vnet.refer -Location $vnet.region -AddressPrefix $vnet.ipaddress
    foreach($subnet in $Subnets){
        if($new_vnet.name -eq $subnet.refer){ # vnet.name과 subnet.refer와 같을 경우 서브넷 생성
            Add-AzVirtualNetworkSubnetConfig -Name $subnet.name -AddressPrefix $subnet.ipaddress -VirtualNetwork $new_vnet
            Set-AzVirtualNetwork -VirtualNetwork $new_vnet
        }
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
        # PIP 생성
        $pip = New-AzPublicIpAddress -Name ($VM.name+"-pip") -ResourceGroupName $vm.rg -AllocationMethod Static -Location $vm.region -Sku "Standard"
        $vnet = Get-Azvirtualnetwork -name $VM.refer -ResourceGroupName $vm.rg
        $VirtualMachine = New-AzVMConfig -VMName $VM.name -VMSize $VM.size
        $nsg = Get-AzNetworkSecurityGroup -Name $VM.nsg
        $nic = New-AzNetworkInterface -ResourceGroupName $VM.rg -Location $VM.region `
        -Name ($VM.name+"-NIC") -SubnetId $vnet.subnets.Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

        if($vm.ostype -eq "Windows"){
            Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VM.name -Credential $cred
            Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $VM.publisher -Offer $VM.offer -Skus $VM.sku -Version "latest"
            Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.id
            New-AzVM -VM $VirtualMachine -ResourceGroupName $VM.rg -Location $VM.region -Verbose
        }
        else {
            Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VM.name -Credential $cred
            Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $VM.publisher -Offer $VM.offer -Skus $VM.sku -Version "latest"
            Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.id
            New-AzVM -VM $VirtualMachine -ResourceGroupName $VM.rg -Location $VM.region -Verbose
        }
        
  }-ArgumentList $VM,$Cred
}


get-job -Name "vm-ue-*"
get-job | Remove-Job
Receive-Job -Name "vm-ue-*-Job"

# 참조
# 불러와서 쓰기 + 문자열 if x
# $vmvnet = Get-Azvirtualnetwork -name $vmcreate.tag -ResourceGroupName $vmcreate.rg
# $nic = New-AzNetworkInterface -Name ($vmcreate.name + "NIC") -ResourceGroupName $vmcreate.rg -Location $vmcreate.location -SubnetId $vmvnet.Subnets.Id -PrivateIpAddress $vmcreate.ip
###################################

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
        -VCore 2 -MinimumCapacity 2 `
        -SampleName "AdventureWorksLT"

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

# } else { #NIC02, 03일 경우 (linux vm)
#     $nic2 = @{
#         Name = "NIC0$i"
#         resourcegroupname = $ResourceGroupName
#         location = $Location
#         Subnet = $Vnet.Subnets[0]
#         NetworkSecurityGroup = $NSG
#     }
#         $nicVM2 = New-AzNetworkInterface @nic2
# }

$test2 = Get-AzVirtualNetwork -Name "vnet-*"

$test3 = @{
    network = $test2.Subnets
}
$test3

$test4 = Start-Job -Name "test" -ScriptBlock { param($test3)
    $test3.network
} -ArgumentList $test3

receive-job -Job $test4