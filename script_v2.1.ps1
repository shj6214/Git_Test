

# Azure 계정 연결  
Connect-AzAccount

# csv 파일 임포트 선언
$resourceinfos = Import-csv -Path "C:\Users\shj\shtest\Git_Test\resource_v2.1.csv"

# csv 파일 리소스 별 변수 생성
$VMs = $resourceinfos | Where-Object {$_.kind -eq "vm"}
$Vnets = $resourceinfos | Where-Object {$_.kind -eq "vnet"}
$Subnets = $resourceinfos | Where-Object {$_.kind -eq "subnet"}
$gwsubnet = $resourceinfos | Where-Object {$_.kind -eq "gatewaysubnet"}
$Nics = $resourceinfos | Where-Object {$_.kind -eq "nic"} 
$Nsgrule = $resourceinfos | Where-Object {$_.kind -eq "nsgrule"}
$nsgs = $resourceinfos | Where-Object {$_.kind -eq "nsg"}
$Pips = $resourceinfos | Where-Object {$_.kind -eq "pip"}
$LBs = $resourceinfos | Where-Object {$_.kind -eq "lb"}
$LBrules = $resourceinfos | Where-Object {$_.kind -eq "lbrule"}
$LBfeips = $resourceinfos | Where-Object {$_.kind -eq "lbfeip"}
$LBprobe = $resourceinfos | Where-Object {$_.kind -eq "lbprobe"}
$LBpool = $resourceinfos | Where-Object {$_.kind -eq "lbpool"}


# $region = $resourceinfos | Where-Object {$_.kind -eq "region"}

# RG 생성
$RGs = $resourceinfos | Where-Object {$_.kind -eq "resourcegroup"}
foreach($RG in $RGs){
    $new_rg = New-AzResourceGroup -Name $RG.name -Location $RG.region

}

# NSG rule 생성 ("회사 IP"만 접근 가능토록) => NSG Rule 2개 생성 (nsg rule 1ea HTTP))
New-AzNetworkSecurityRuleConfig -Name $nsgrule.name -Description $nsgrule.Desc -Access "Allow" -Protocol $nsgrule.protocol -Direction Inbound -Priority $nsgrule.priority -SourceAddressPrefix $nsgrule.sourceaddress -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $nsgrule.destport

# NSG 생성 및 NSG 세부 규칙 연결 (nsg 1ea <-> subnet)
$New_Nsg = for($i=0; $i -lt $nsgs.length; $i++){
    New-AzNetworkSecurityGroup -ResourceGroupName $new_rg.ResourceGroupName[$i] -Location $new_rg.Location[$i] -Name $nsgs.name[$i] -SecurityRules $new_nsgrule
}

# Subnet 생성 및 Subnet에 NSG 연결 (Subnet 6ea)
$New_Subnet = foreach($subnet in $Subnets){
    New-AzVirtualNetworkSubnetConfig -Name $SUBNET.name -AddressPrefix $SUBNET.ipaddress 
}

# VNET 생성 및 VNET에 Subnet 연결 (VNET 6ea <-> subnet 6ea) 각 와일드 카드 조건에 일치할 경우 vnet 생성 
$New_VNET = for($i=0; $i -lt $vnets.length; $i++){
    if($vnets.name[$i] -like "*kc*") {
        New-AzVirtualNetwork -Name $vnets.name[$i] -ResourceGroupName $new_rg.ResourceGroupName[0] -Location $new_rg.Location[0] -AddressPrefix $vnets.ipaddress[$i] -Subnet $NEW_SUBNET[$i]
    } 
    elseif($vnets.name[$i] -like "*je*"){
        New-AzVirtualNetwork -Name $vnets.name[$i] -ResourceGroupName $new_rg.ResourceGroupName[1] -Location $new_rg.Location[1] -AddressPrefix $vnets.ipaddress[$i] -Subnet $NEW_SUBNET[$i]
    }
    else {
        New-AzVirtualNetwork -Name $vnets.name[$i] -ResourceGroupName $new_rg.ResourceGroupName[2] -Location $new_rg.Location[2] -AddressPrefix $vnets.ipaddress[$i] -Subnet $NEW_SUBNET[$i]
    }
}


# Peer VNet1 to VNet2.
Add-AzVirtualNetworkPeering -Name "peer-kc-to-kc2" -VirtualNetwork $New_VNET[0] -RemoteVirtualNetworkId $New_VNET[1].Id

# Peer VNet2 to VNet1.
Add-AzVirtualNetworkPeering -Name "peer-kc2-to-kc" -VirtualNetwork $New_VNET[1] -RemoteVirtualNetworkId $New_VNET[0].id

# PIP 생성 (PIP 3 ea) s
$New_Pip =  for($i=0; $i -lt $pips.length; $i++){
    New-AzPublicIpAddress -Name $pips.name[$i] -ResourceGroupName $new_rg.ResourceGroupName[$i] -AllocationMethod "Static" -Location $new_rg.Location[$i] -Sku $pips.sku[$i]
}

# LB - FEIP 생성 (3ea)
$new_feips = for($i=0; $i -lt $new_pip.length; $i++){
    New-AzLoadBalancerFrontendIpConfig -Name $LBfeips.Name[$i] -PublicIpAddressId $new_pip.Id[$i]
}

$new_feips.getType()

# LB - BackEnd POOL 생성 (1ea)
$new_lbpool = New-AzLoadBalancerBackendAddressPoolConfig -Name $lbpool.name

# LB - Probe 생성 (1ea)
$new_probe = New-AzLoadBalancerProbeConfig -Name $LBprobe.name -Protocol $LBprobe.protocol -Port $LBprobe.destport -IntervalInSeconds 360 -ProbeCount 5 -RequestPath '/'

# LB - LBrule 생성 (3ea)
$new_lbrules = for($i=0; $i -lt $new_pip.length; $i++){
    New-AzLoadBalancerRuleConfig -Name $LBrules.name[$i] -Protocol $LBrules.protocol[$i] -FrontendPort $lbrules.sourceport[$i] -BackendPort $LBrules.destport[$i] -IdleTimeoutInMinutes 15 -FrontendIpConfigurationId $new_feips.id[$i]
}

# LB 생성 (3ea)
$new_lb = for($i=0; $i -lt $LBs.length; $i++){
    New-AzLoadBalancer -ResourceGroupName $new_rg.ResourceGroupName[$i] -Name $LBs.name[$i] -Location $new_rg.Location[$i] -Sku $Lbs.sku[$i] -FrontendIpConfiguration $new_feips[$i] -BackendAddressPool $new_lbpool -LoadBalancingRule $new_lbrules[$i] -Probe $new_probe
}


# nic 01 ~ 03 3 개 생성 + 백엔드풀 규칙 추가 
$new_nics = for($i=0; $i -lt $vnets.length; $i++){
    if($nics.name[$i] -eq "nic01") {
        New-AzNetworkInterface -Name $nics.name[$i] -ResourceGroupName $new_rg.ResourceGroupName[$i] -Location $new_rg.Location[$i] -SubnetId $new_vnet.Subnets[$i+1].id -NetworkSecurityGroupId $New_Nsg.id[$i] -LoadBalancerBackendAddressPoolId $new_lbpool.Id
    } 
    elseif($nics.name[$i] -eq "nic02"){
        New-AzNetworkInterface -Name $nics.name[$i] -ResourceGroupName $new_rg.ResourceGroupName[$i] -Location $new_rg.Location[$i] -SubnetId $new_vnet.Subnets[$i+2].id -NetworkSecurityGroupId $New_Nsg.id[$i] -LoadBalancerBackendAddressPoolId $new_lbpool.Id
    }
    elseif($nics.name[$i] -eq "nic03") {
        New-AzNetworkInterface -Name $nics.name[$i] -ResourceGroupName $new_rg.ResourceGroupName[$i] -Location $new_rg.Location[$i] -SubnetId $new_vnet.Subnets[$i+3].id -NetworkSecurityGroupId $New_Nsg.id[$i] -LoadBalancerBackendAddressPoolId $new_lbpool.Id
    }
}


# VM01 생성 및 관리자 계정 생성, 암호화되지않은 표준 문자열을 보안 문자열로 변환
# VM 3 대 배포 kc-02, ue-02, je-02 
$VMAdminUser = "shjoo"
$VMAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($VMAdminUser, $VMAdminSecurePassword);

for ($i=0; $i -lt $VMs.length; $i++){
    
    $VirtualMachine = New-AzVMConfig -VMName $vms.name[$i] -VMSize $vms.size[$i]
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $vms.name[$i] -Credential $cred
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $new_nic.Id[$i]
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $vms.publisher[$i] -Offer $vms.offer[$i] -Skus $vms.sku[$i] -Version latest

    New-AzVM -VM $VirtualMachine -ResourceGroupName $new_rg.ResourceGroupName[$i] -Location $new_rg.Location[$i] -Verbose
}

# 아웃바운드 규칙 생성 



##############
# 생성된 모든 리소스 확인
Get-AzResource | Format-Table

# 생성된 VM 제거 
foreach ($rg in $RGs){
    # Stop-azVM -Name $vmremove.name
    # Remove-AzVM -name $vmremove.name -ResourceGroupName $RG.name -force
    Remove-AzResourceGroup -Name $RG.name -force
}

# 리소스 그룹 제거
Remove-AzResourceGroup -Name $RGs.name[0] -force

# 변수 초기화 
Clear-Variable 

##############