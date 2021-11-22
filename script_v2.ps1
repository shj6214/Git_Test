
# Azure 계정 연결  
Connect-AzAccount

# csv 파일 임포트 선언
$resourceinfos = Import-csv -Path "C:\Users\shj\shtest\Git_Test\rgcreate.csv"

# csv 파일 리소스 별 변수 생성
$VMs = $resourceinfos | Where-Object {$_.kind -eq "vm"}
$VNET = $resourceinfos | Where-Object {$_.kind -eq "vnet"}
$Subnet = $resourceinfos | Where-Object {$_.kind -eq "subnet"}
$Nics = $resourceinfos | Where-Object {$_.kind -eq "nic"} 
$Nsgrules = $resourceinfos | Where-Object {$_.kind -eq "nsgrule"}
$nsg = $resourceinfos | Where-Object {$_.kind -eq "nsg"}
$Pip = $resourceinfos | Where-Object {$_.kind -eq "pip"}
$Avset = $resourceinfos | Where-Object {$_.kind -eq "avset"}
$RG = $resourceinfos | Where-Object {$_.kind -eq "resourcegroup"}

# RG 생성 및 리전 관련 변수 선언
$LocationName = "korea central"
New-AzResourceGroup -Name $RG.name -Location $LocationName

# NSG rule 생성 ("회사 IP"만 접근 가능토록) => NSG Rule 2개 생성 (nsg rule 2ea (SSH, HTTP))
$New_Nsgrule = foreach($nsgrule in $nsgrules){
    New-AzNetworkSecurityRuleConfig -Name $nsgrule.name -Description $nsgrule.Desc -Access "Allow" -Protocol $nsgrule.protocol -Direction Inbound -Priority $nsgrule.priority -SourceAddressPrefix $nsgrule.sourceaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $nsgrule.destport
}

# NSG 생성 및 NSG 세부 규칙 연결 (nsg 1ea <-> subnet)
$New_Nsg = New-AzNetworkSecurityGroup -ResourceGroupName $RG.name -Location $LocationName -Name $nsg.name -SecurityRules $new_nsgrule

# Subnet 생성 및 Subnet에 NSG 연결 (Subnet 1ea)
$New_Subnet = New-AzVirtualNetworkSubnetConfig -Name $SUBNET.name -AddressPrefix $SUBNET.ipaddress -NetworkSecurityGroupId $new_nsg.id

# VNET 생성 및 VNET에 Subnet 연결 (VNET 1ea <-> subnet)
$New_VNET = New-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $RG.name -Location $LocationName -AddressPrefix $vnet.ipaddress -Subnet $NEW_SUBNET

# PIP 생성 (VM-kc-01 용 PIP 1 ea) 
$New_Pip = New-AzPublicIpAddress -Name $pip.name -ResourceGroupName $RG.name -AllocationMethod Static -Location $LocationName -Sku $pip.sku

# NIC 생성 (NIC 01 ~ 03)
$New_Nic = foreach($nic in $nics){
    if ($nic.name -eq "NIC01") { # VM-KC-01 용 NIC에 PIP 연결 (nic <-> pip)
        New-AzNetworkInterface -Name $nic.name -ResourceGroupName $RG.name -Location $LocationName -SubnetId $new_vnet.Subnets[0].id -PublicIpAddressId $NEW_PIP.id -PrivateIpAddress $nic.ipaddress
    }
    else{ # VM-KC-02, VM-KC-03 NIC 연결
        New-AzNetworkInterface -Name $nic.name -ResourceGroupName $RG.name -Location $LocationName -SubnetId $new_vnet.Subnets[0].id -PrivateIpAddress $nic.ipaddress
    }
}

# 가용성 집합 생성 (Avset 1ea)
$new_avset = New-AzAvailabilitySet -ResourceGroupName $RG.name -Name $avset.name -Location $LocationName -PlatformFaultDomainCount $avset.faultdomain -PlatformUpdateDomainCount $avset.updatedomain -Sku $avset.sku

# VM01 생성 및 관리자 계정 생성
# 암호화되지않은 표준 문자열을 보안 문자열로 변환
$VMAdminUser = "shjoo"
$VMAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($VMAdminUser, $VMAdminSecurePassword);

# VM 3대 생성. Linux - 최소 이미지 sku B1ls
for ($i=0; $i -lt $vms.length; $i++){

    $VirtualMachine = New-AzVMConfig -VMName $vms.name[$i] -VMSize $vms.size[$i] -AvailabilitySetID $new_avset.Id
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $vms.name[$i] -Credential $cred
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $new_nic.Id[$i]
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $vms.publisher[$i] -Offer $vms.offer[$i] -Skus $vms.sku[$i] -Version latest

    New-AzVM -VM $VirtualMachine -ResourceGroupName $RG.name -Location $LocationName -Verbose
}



#############

# 생성된 모든 리소스 확인
Get-AzResource | Format-Table

# 생성된 VM 제거 
foreach ($vmremove in $vms){
    # Stop-azVM -Name $vmremove.name
    Remove-AzVM -name $vmremove.name -ResourceGroupName $RG.name -force
}

# 리소스 그룹 제거
Remove-AzResourceGroup -Name $RG.name -force

############

