

###
# 유의 사항 
# 1. Peering option 참조. 
# 2. VM 배포 후, Script deployment 
# 3. P2S Connect - je vm 02에 접근 할 수 있는지 ? 
# 4. VM, NIC, LB 배포 
###

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


# VNET 및 SUBNET 생성, 연결 (6ea)
$get_vnet = foreach($vnet in $vnets){
    $new_vnet = New-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $vnet.refer -Location $vnet.region -AddressPrefix $vnet.ipaddress
    foreach($subnet in $Subnets){
        if($new_vnet.name -eq $subnet.refer){ # vnet.name subnet.refer와 같을 경우 서브넷 생성 
            New-AzVirtualNetworkSubnetConfig -Name $subnet.Name -AddressPrefix $subnet.ipaddress
            Add-AzVirtualNetworkSubnetConfig -Name $subnet.name -AddressPrefix $subnet.ipaddress -VirtualNetwork $new_vnet
            Set-AzVirtualNetwork -VirtualNetwork $new_vnet
        }
    }
}


# VM01 생성 및 관리자 계정 생성, 암호화되지않은 표준 문자열을 보안 문자열로 변환
# VM 3 대 배포 kc-01, ue-01, je-01 
$VMs = $resourceinfos | Where-Object {$_.kind -eq "vm"}
$VMAdminUser = "shjoo"
$VMAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($VMAdminUser, $VMAdminSecurePassword);

# $get_vnet = Get-AzVirtualNetwork -Name "vnet-*-02" 
$get_vnets = $get_vnet | Where-Object {$_.name -like "vnet*02"}

foreach($VM in $VMs){ # VM 3 ea
    # nic 3 ea 
    
    # $new_nic = New-AzNetworkInterface -Name $vm.nics -ResourceGroupName $vm.refer -Location $vm.region -SubnetId $vm.subnet.id 
    $VirtualMachine = New-AzVMConfig -VMName $VM.name -VMSize $VM.size
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VM.name -Credential $cred
    
    foreach($get_subnet in ($get_vnet | Where-Object {$_.name -like "vnet-*-02"})){
        if($get_subnet.name -eq "vnet-kc-02"){
            $new_nic = New-AzNetworkInterface -Name $vm.nics -ResourceGroupName $vm.refer -Location $vm.region -SubnetId $get_subnet.subnets.id
            -LoadBalancerBackendAddressPool $backendPoolName
        }
        elseif($get_subnet.Name -eq "vnet-je-02"){
            $new_nic = New-AzNetworkInterface -Name $vm.nics -ResourceGroupName $vm.refer -Location $vm.region -SubnetId $get_subnet.subnets.id
            -LoadBalancerBackendAddressPool $backendPoolName
        }
        else{
            $new_nic = New-AzNetworkInterface -Name $vm.nics -ResourceGroupName $vm.refer -Location $vm.region -SubnetId $get_subnet.subnets.id
            -LoadBalancerBackendAddressPool $backendPoolName
        }
    }

    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $VM.publisher -Offer $VM.offer -Skus $VM.sku -Version latest
    $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $new_nic.Id
    New-AzVM -VM $VirtualMachine -ResourceGroupName $VM.refer -Location $VM.region -Verbose 
}

#################################
# 공통 IIS 변수
$Publisher = 'Microsoft.Compute'
$ExtensionType = 'CustomScriptExtension'
$ExtensionName = 'IIS'
$TypeHandlerVersion = '1.8'
$SettingString = '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'

### Script 동작
Set-AzVMExtension -Publisher $Publisher -ExtensionType $ExtensionType -ExtensionName $ExtensionName -ResourceGroupName $VM.refer -VMName $VM.name -Location $VM.region -TypeHandlerVersion $TypeHandlerVersion -settingString $SettingString


# LB 세팅 
$LBs = $resourceinfos | Where-Object {$_.kind -eq "lb"}

foreach($LB in $LBs){

    # LB - PIP 생성 (3ea)
    $New_Pip = New-AzPublicIpAddress -Name $LB.pipname -ResourceGroupName $LB.refer -AllocationMethod "Static" -Location $lb.region -Sku $lb.sku

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
    | Add-AzLoadBalancerOutboundRuleConfig -Name $LB.lbout -AllocatedOutboundPort 80 -Protocol $LB.protocol -FrontendIpConfiguration $KRLB.FrontendIpConfigurations[1] -BackendAddressPool $new_lbpool | Set-AzLoadBalancer
}

Get-AzLoadBalancer 
Get-AzLoadBalancerBackendAddressPool

# OutBound Setting
# $KRPublicIPoutbound = New-AzPublicIpAddress -Name $KRPublicIPoutboundName -ResourceGroupName $ResourceGroupName -Location $KRLocation -sku $lbsku -AllocationMethod Static

# $KRfrontendConfig = Add-AzLoadBalancerFrontendIpConfig -LoadBalancer $KRLB -Name $KRfrontendConfigName -PublicIpAddressId $KRPublicIPoutbound.Id

# $KRbackendConfig = Add-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $KRLB -Name $KRbackendConfigName
# $KRbackendConfig = Add-AzLoadBalancerBackendAddressPoolConfig -LoadBalancer $KRLB -Name $KRbackendConfigName

# $KROutboundRule = Add-AzLoadBalancerOutboundRuleConfig  -LoadBalancer $KRLB -Name $KROutboundRuleName -AllocatedOutboundPort $AllocatedOutboundPort -Protocol $Outboundprotocol -FrontendIpConfiguration $KRLB.FrontendIpConfigurations[1] -BackendAddressPool  $KRLB.BackendAddressPools[1] | Set-AzLoadBalancer

###################################

# VNET Peering 연결 수행
$Peers = $resourceinfos | Where-Object {$_.pname -like "peer*"}

# $get_vnets = Get-AzVirtualNetwork -Name "Vnet-*-01"
# $get_vnets2 = Get-AzVirtualNetwork -Name "Vnet-*-02"
$get_vnet = 
$get_vnet2 = 

foreach($peer in $peers){
    for($i=0; $i -lt $get_vnets.length; $i++){
        Add-AzVirtualNetworkPeering -Name $peer.pname -VirtualNetwork $get_vnets[$i] -RemoteVirtualNetworkId $get_vnets2[$i].id   
        if($peer.name -eq "vnet-je-01" && $peer.remote -eq "vnet-je-02"){ # JE-01(VGW) <-> JE-02 (LB-VM) 원격 라우터 서버 사용 옵션
            Add-AzVirtualNetworkPeering -Name $peer.pname -VirtualNetwork $get_vnets2[$i] -RemoteVirtualNetworkId $get_vnets2[$i].id -UseRemoteGateways
        }    
    }
}

# Peer VNet1 to VNet2.
Add-AzVirtualNetworkPeering -Name "peer-kc-to-kc2" -VirtualNetwork $New_VNET[0] -RemoteVirtualNetworkId $New_VNET[1].Id -UseRemoteGateways
# Add-AzVirtualNetworkPeering `
#   -Name myVirtualNetwork1-myVirtualNetwork2 `
#   -VirtualNetwork $virtualNetwork1 `
#   -RemoteVirtualNetworkId $virtualNetwork2.Id

# Peer VNet2 to VNet1.
Add-AzVirtualNetworkPeering -Name "peer-kc2-to-kc" -VirtualNetwork $New_VNET[1] -RemoteVirtualNetworkId $New_VNET[0].id -UseRemoteGateways 

# Add-AzVirtualNetworkPeering `
#   -Name myVirtualNetwork2-myVirtualNetwork1 `
#   -VirtualNetwork $virtualNetwork2 `
#   -RemoteVirtualNetworkId $virtualNetwork1.Id
# -UseRemoteGateways 

################################################

# Gateway Subnet 생성
$gwsubnet = $resourceinfos | Where-Object {$_.kind -eq "gatewaysubnet"} # | Select-Object {$_.refer -eq "vnet-je-01"}
$gwvm = $resourceinfos | Where-Object {$_.Name -eq "vgw-je-01"}

# 게이트 웨이 서브넷 생성 
$get_vnet = Get-AzVirtualNetwork -ResourceGroupName $RGs.Name[1] -Name $gwsubnet.refer
Add-AzVirtualNetworkSubnetConfig -Name $gwsubnet.Name -AddressPrefix $gwsubnet.ipaddress -VirtualNetwork $get_vnet

# 가상네트워크에 GatewaySubnet 연결
$get_vnets = $get_vnet | Set-AzVirtualNetwork

# VGW 용 public IP 주소 생성 
$gwpip = New-AzPublicIpAddress -Name $gwsubnet.pipname -ResourceGroupName $get_vnets.ResourceGroupName -Location $gwsubnet.region -AllocationMethod Dynamic

# GW IP 구성 설정 생성
# $vnet = Get-AzVirtualNetwork -Name $VNetName -ResourceGroupName $RG
# $subnet = Get-AzVirtualNetworkSubnetConfig -Name 'GatewaySubnet' -VirtualNetwork $vnet
$gwipconfig = New-AzVirtualNetworkGatewayIpConfig -Name $gwsubnet.gwconf -SubnetId $get_vnets.Subnets[1].id -PublicIpAddressId $gwpip.Id

# VPN Gateway 생성
$new_vgw = New-AzVirtualNetworkGateway -Name $gwvm.Name -ResourceGroupName $get_vnets.ResourceGroupName `
-Location $gwsubnet.region -IpConfigurations $gwipconfig -GatewayType $gwsubnet.type `
-VpnType $gwsubnet.vpntype -GatewaySku $gwsubnet.sku

# VPN Client Address Pool 추가
$Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $new_vgw.ResourceGroupName 
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Gateway -VpnClientAddressPool $gwsubnet.vpnpool #-VpnClientProtocol "IKEv2"

# 자체 루트 인증서 생성 - 자물쇠
$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
 -Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
 -HashAlgorithm sha256 -KeyLength 2048 `
 -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

# Export the root certificate to "C:\cert\P2SRootCert.cer" 
# Upload the root certificate public key information 
# 내보내기의 경우, 타 인원에 접근하고자 할 경우 활용토록 한다. 
$P2SRootCertName = "P2SRootCert.cer"

$filePathForCert = "C:\cert\P2SRootCert.cer"

$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($filePathForCert)

$CertBase64 = [system.convert]::ToBase64String($cert.RawData)

# 공인 data
$p2srootcert = New-AzVpnClientRootCertificate -Name $P2SRootCertName -PublicCertData $CertBase64
Add-AzVpnClientRootCertificate -VpnClientRootCertificateName $P2SRootCertName `
 -VirtualNetworkGatewayname $Gateway.Name `
 -ResourceGroupName $new_vgw.ResourceGroupName -PublicCertData $CertBase64

###
# 클라이언트 인증서 생성 - 열쇠
New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
-Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" `
-Signer $cert # -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")
##


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