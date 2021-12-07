
# Azure 계정 연결  
Connect-AzAccount

# csv 파일 임포트 선언
$resourceinfos = Import-csv -Path "C:\Users\shj\shtest\Git_Test\resource_v4.1.csv"

# RG 생성 (kc je ue 3ea)
$RG = $resourceinfos | Where-Object {$_.kind -eq "resourcegroup"}

New-AzResourceGroup -Name $RG.name -Location $RG.region

# Subnet, VNET 변수 선언 
$Vnets = $resourceinfos | Where-Object {$_.kind -eq "vnet"}
$Subnets = $resourceinfos | Where-Object {$_.kind -eq "subnet"}

# VNET 및 SUBNET 배포 ( VNET 2 EA / SUBNET 2 EA )
foreach($vnet in $vnets){
    $new_vnet = New-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $vnet.refer -Location $vnet.region -AddressPrefix $vnet.ipaddress
    foreach($subnet in $Subnets){
        if($new_vnet.name -eq $subnet.refer){ # vnet.name과 subnet.refer와 같을 경우 서브넷 생성 
            # New-AzVirtualNetworkSubnetConfig -Name $subnet.Name -AddressPrefix $subnet.ipaddress
            Add-AzVirtualNetworkSubnetConfig -Name $subnet.name -AddressPrefix $subnet.ipaddress -VirtualNetwork $new_vnet
            Set-AzVirtualNetwork -VirtualNetwork $new_vnet
        }
    }
}

# NSG 변수 가져오기
$nsgs = $resourceinfos | Where-Object {$_.kind -eq "nsg"}
$nsgrules = $resourceinfos | Where-Object {$_.kind -eq "nsgrule"}

# NSG 및 NSG Rule 연결 
$nsgs = $resourceinfos | Where-Object {$_.kind -eq "nsg"}

foreach($nsg in $nsgs){
    $new_nsg = New-AzNetworkSecurityGroup -ResourceGroupName $nsg.refer -Location $nsg.region -Name $nsg.name
    $nsgrules = $resourceinfos | Where-Object {$_.refer -eq $nsg.Name}
    foreach($nsgrule in $nsgrules){
            Add-AzNetworkSecurityRuleConfig -Name $nsgrule.name -Description $nsgrule.Desc -Access "Allow" -Protocol $nsgrule.protocol -Direction Inbound -Priority $nsgrule.priority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $nsgrule.destport `
            -NetworkSecurityGroup $new_nsg
            $new_nsg | Set-AzNetworkSecurityGroup
    }
}

Get-AzNetworkSecurityGroup -ResourceGroupName $RG.name

# 관리자 계정 생성, 암호화되지않은 표준 문자열을 보안 문자열로 변환 변수 선언
$VMs = $resourceinfos | Where-Object {$_.kind -eq "vm"}
$VMAdminUser = "shjoo"
$VMAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($VMAdminUser, $VMAdminSecurePassword);

# VM 2 대 배포 kc-01, kc-02
foreach($VM in $VMs){
    # PIP 생성
    $pip = New-AzPublicIpAddress -Name ($VM.name+"-pip") -ResourceGroupName $RG.name -AllocationMethod Static -Location $RG.region -Sku "Standard"
    $vnet = Get-Azvirtualnetwork -name $VM.refer -ResourceGroupName $vm.rg
    
    $VirtualMachine = New-AzVMConfig -VMName $VM.name -VMSize $VM.size
    if($vm.ostype -eq "Windows"){
        Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VM.name -Credential $cred
    }
    else {
        Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $VM.name -Credential $cred
    }

    Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $VM.publisher -Offer $VM.offer -Skus $VM.sku -Version "latest"

    # NIC 연결
    $nsg = Get-AzNetworkSecurityGroup -Name $VM.nsg
    $nic = New-AzNetworkInterface -ResourceGroupName $VM.rg -Location $VM.region `
    -Name ($VM.name+"-NIC") -SubnetId $vnet.subnets.Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id
    Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.id

    New-AzVM -VM $VirtualMachine -ResourceGroupName $VM.rg -Location $VM.region -Verbose
  }

# 참조
# 불러와서 쓰기 + 문자열 if x
# $vmvnet = Get-Azvirtualnetwork -name $vmcreate.tag -ResourceGroupName $vmcreate.rg
# $nic = New-AzNetworkInterface -Name ($vmcreate.name + "NIC") -ResourceGroupName $vmcreate.rg -Location $vmcreate.location -SubnetId $vmvnet.Subnets.Id -PrivateIpAddress $vmcreate.ip

###################################

# VNET Peering 변수 선언(vnet_1 - ue,je,kc-01, vnet_2 - ue,je,kc-02)
$get_vnet_1 = Get-AzVirtualNetwork -Name "vnet*01"
$get_vnet_2 = Get-AzVirtualNetwork -Name "vnet*02"

# 동일 리전간 Peering ( KC <-> KC 2 )
# KC-01 <-> KC-02
    Add-AzVirtualNetworkPeering -Name ($get_vnet_1.name + "-To-" + $get_vnet_2.name) -VirtualNetwork $get_vnet_1 -RemoteVirtualNetworkId $get_vnet_2.id -AllowForwardedTraffic 
    Add-AzVirtualNetworkPeering -Name ($get_vnet_2.name + "-To-" + $get_vnet_1.name) -VirtualNetwork $get_vnet_2 -RemoteVirtualNetworkId $get_vnet_1.id -AllowForwardedTraffic    

###########################

# 리소스 그룹 제거 
Remove-AzResourceGroup -Name $RG.name -force



