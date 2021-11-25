

# Azure 계정 연결  
Connect-AzAccount

# csv 파일 임포트 선언
$resourceinfos = Import-csv -Path "C:\Users\shj\shtest\Git_Test\resource_v2.1.csv"

# RG 생성 (kc je ue 3ea)
$RGs = $resourceinfos | Where-Object {$_.kind -eq "resourcegroup"}

foreach($RG in $RGs){
    New-AzResourceGroup -Name $RG.name -Location $RG.region
}

# NSG 생성 및 NSG 세부 규칙 연결 (nsg 1 nsgrule 1ea)
$nsgs = $resourceinfos | Where-Object {$_.kind -eq "nsg"}

foreach($nsg in $nsgs){
    # NSG rule 생성 (HTTP 1ea))
    $new_nsgrule = New-AzNetworkSecurityRuleConfig -Name $nsg.nsgrule -Description $nsg.Desc -Access "Allow" -Protocol $nsg.protocol -Direction Inbound -Priority $nsg.priority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $nsg.destport
    New-AzNetworkSecurityGroup -ResourceGroupName $nsg.refer -Location $nsg.region -Name $nsg.name -SecurityRules $new_nsgrule
}

# Subnet, VNET 생성 및 연결 (Vnet 6ea, Subnet 6ea)
$Vnets = $resourceinfos | Where-Object {$_.kind -eq "vnet"}
$Subnets = $resourceinfos | Where-Object {$_.kind -eq "subnet"}
$gwsubnet = $resourceinfos | Where-Object {$_.kind -eq "gatewaysubnet"}

# 수정
foreach($vnet in $vnets){
    $new_vnet = New-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $vnet.refer -Location $vnet.region -AddressPrefix $vnet.ipaddress
    foreach($subnet in $Subnets){
        Add-AzVirtualNetworkSubnetConfig -Name $subnet.name -AddressPrefix $subnet.ipaddress -VirtualNetwork $new_vnet
    } 
}


# LB 세팅 
$LBs = $resourceinfos | Where-Object {$_.kind -eq "lb"}
# # PIP 세팅
$Pips = $resourceinfos | Where-Object {$_.kind -like "lb"} | Where-Object {$_.pipname -like "*pip"}

foreach($LB in $LBs){

    # LB - PIP 생성 (3ea)
    $New_Pip = New-AzPublicIpAddress -Name $LB.pipname -ResourceGroupName $pip.refer -AllocationMethod "Static" -Location $lb.region -Sku $lb.sku

    # LB - BackEnd POOL 생성 (3ea)
    $new_lbpool = New-AzLoadBalancerBackendAddressPoolConfig -Name $LB.lbPool

    # LB - Probe 생성 (3ea)
    $new_probe = New-AzLoadBalancerProbeConfig -Name $LB.lbprobe -Protocol $LB.protocol -Port $LB.destport -IntervalInSeconds 360 -ProbeCount 5 
    
    # LB - FEIP 생성 (3ea)
    $new_FEip = New-AzLoadBalancerFrontendIpConfig -Name $LB.lbfrontip -PublicIpAddressId $New_Pip.Id

    # LB - LBrule 생성 (3ea)
    $New_LBrules = New-AzLoadBalancerRuleConfig -Name $LB.lbrule -Protocol $LB.protocol -FrontendPort $LB.sourceport -BackendPort $LB.destport -IdleTimeoutInMinutes 15 -FrontendIpConfigurationId $new_FEIP.Id

    # LB - 생성 
    New-AzLoadBalancer -ResourceGroupName $LB.refer -Name $LB.name -Location $LB.region -Sku $LB.sku -FrontendIpConfiguration $new_FEIP -BackendAddressPool $new_lbpool -LoadBalancingRule $New_LBrules -Probe $new_probe
}


$lb.gettype()
$lbs | ft


# nic 01 ~ 03 3 개 생성 + 백엔드풀 규칙 추가 
$Nics = $resourceinfos | Where-Object {$_.kind -eq "nic"}
foreach($nic in $nics){
    New-AzNetworkInterface -Name $nics.name -ResourceGroupName $nics.name -Location $nics.region -SubnetId $ -NetworkSecurityGroupId $New_Nsg.id[$i] -LoadBalancerBackendAddressPoolId $.Id
}


# VM01 생성 및 관리자 계정 생성, 암호화되지않은 표준 문자열을 보안 문자열로 변환
# VM 3 대 배포 kc-02, ue-02, je-02 
$VMs = $resourceinfos | Where-Object {$_.kind -eq "vm"}
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


# Peer VNet1 to VNet2.
Add-AzVirtualNetworkPeering -Name "peer-kc-to-kc2" -VirtualNetwork $New_VNET[0] -RemoteVirtualNetworkId $New_VNET[1].Id

# Peer VNet2 to VNet1.
Add-AzVirtualNetworkPeering -Name "peer-kc2-to-kc" -VirtualNetwork $New_VNET[1] -RemoteVirtualNetworkId $New_VNET[0].id

# OutBound Setting
$KRPublicIPoutbound = New-AzPublicIpAddress -Name $KRPublicIPoutboundName -ResourceGroupName $ResourceGroupName -Location $KRLocation -sku $lbsku -AllocationMethod Static

$KRfrontendConfig = Add-AzLoadBalancerFrontendIpConfig -LoadBalancer $KRLB -Name $KRfrontendConfigName -PublicIpAddressId $KRPublicIPoutbound.Id

$KRbackendConfig = Add-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $KRLB -Name $KRbackendConfigName

$KROutboundRule = Add-AzLoadBalancerOutboundRuleConfig  -LoadBalancer $KRLB -Name $KROutboundRuleName -AllocatedOutboundPort $AllocatedOutboundPort -Protocol $Outboundprotocol -FrontendIpConfiguration $KRLB.FrontendIpConfigurations[1] -BackendAddressPool  $KRLB.BackendAddressPools[1] | Set-AzLoadBalancer

# 


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