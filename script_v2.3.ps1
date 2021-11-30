
# Azure 계정 연결  
Connect-AzAccount

# csv 파일 임포트 선언
$resourceinfos = Import-csv -Path "C:\Users\shj\shtest\Git_Test\resource_v2.1.1.csv"

# RG 생성 (kc je ue 3ea)
$RGs = $resourceinfos | Where-Object {$_.kind -eq "resourcegroup"}

foreach($RG in $RGs){
    New-AzResourceGroup -Name $RG.name -Location $RG.region
}

# Subnet, VNET 변수 선언 
$Vnets = $resourceinfos | Where-Object {$_.kind -eq "vnet"}
$Subnets = $resourceinfos | Where-Object {$_.kind -eq "subnet"}

# VNET 및 SUBNET 배포 ( VNET 6 EA / SUBNET 6 EA )
foreach($vnet in $vnets){
    $new_vnet = New-AzVirtualNetwork -Name $vnet.name -ResourceGroupName $vnet.refer -Location $vnet.region -AddressPrefix $vnet.ipaddress
    foreach($subnet in $Subnets){
        if($new_vnet.name -eq $subnet.refer){ # vnet.name과 subnet.refer와 같을 경우 서브넷 생성 
            New-AzVirtualNetworkSubnetConfig -Name $subnet.Name -AddressPrefix $subnet.ipaddress
            Add-AzVirtualNetworkSubnetConfig -Name $subnet.name -AddressPrefix $subnet.ipaddress -VirtualNetwork $new_vnet
            Set-AzVirtualNetwork -VirtualNetwork $new_vnet
        }
    }
}

# NSG 변수 가져오기
$nsgs = $resourceinfos | Where-Object {$_.kind -eq "nsg"}

# NSG 및 NSG Rule 연결 (nsg 1 ea / nsgrule 1ea)
$new_nsgrule = foreach($nsg in $nsgs){
    New-AzNetworkSecurityRuleConfig -Name $nsg.nsgrule -Description $nsg.Desc -Access "Allow" -Protocol $nsg.protocol -Direction Inbound -Priority $nsg.priority -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange $nsg.destport
    New-AzNetworkSecurityGroup -ResourceGroupName $nsg.refer -Location $nsg.region -Name $nsg.name -SecurityRules $new_nsgrule
}

# LB 관련 변수 선언  
$LBs = $resourceinfos | Where-Object {$_.kind -eq "lb"}
$get_vnets = Get-AzVirtualNetwork -Name "vnet-*-02"

# LB ue, je, kc 3 EA 배포 
foreach($LB in $LBs){

    # LB - PIP 생성 (3ea)
    $New_Pip = New-AzPublicIpAddress -Name $LB.pipname -ResourceGroupName $LB.refer -AllocationMethod "Dynamic" -Location $lb.region -Sku $lb.sku

    # LB - Web 접근을 위한 FEIP 생성 (3ea)
    $new_FEip = New-AzLoadBalancerFrontendIpConfig -Name $LB.lbfrontip -PublicIpAddressId $New_Pip.Id

    # LB - BackEnd Pool 생성 (3ea)
    $new_lbpool = New-AzLoadBalancerBackendAddressPoolConfig -Name $LB.lbPool

    # LB - Probe 생성 (3ea)
    $new_probe = New-AzLoadBalancerProbeConfig -Name $LB.lbprobe -Protocol $LB.protocol -Port $LB.destport -IntervalInSeconds 360 -ProbeCount 5 

    # LB - LBrule 생성 (3ea)
    $New_LBrules = New-AzLoadBalancerRuleConfig -Name $LB.lbrule -Protocol $LB.protocol -FrontendPort $LB.sourceport -BackendPort $LB.destport -IdleTimeoutInMinutes 15 -FrontendIpConfigurationId $new_FEIP.Id -ProbeId $new_probe.Id `
    -BackendAddressPoolId $new_lbpool.Id

    # LB - 생성 
    New-AzLoadBalancer -ResourceGroupName $LB.refer -Name $LB.name -Location $LB.region -Sku $LB.sku -FrontendIpConfiguration $new_FEIP -BackendAddressPool $new_lbpool -LoadBalancingRule $New_LBrules -Probe $new_probe
    
    # NIC -> 백엔드 풀 연결 # NIC 3ea bepool 연결
    if($LB.nics -eq "nic01"){ 
        New-AzNetworkInterface -ResourceGroupName $LB.refer -Location $LB.region `
        -Name $LB.nics -LoadBalancerBackendAddressPoolId $new_lbpool.Id -SubnetId $get_vnets.subnets[0].Id
    }
    elseif($LB.nics -eq "nic02"){
        New-AzNetworkInterface -ResourceGroupName $LB.refer -Location $LB.region `
        -Name $LB.nics -LoadBalancerBackendAddressPoolId $new_lbpool.Id -SubnetId $get_vnets.subnets[1].Id
    }
    else{
        New-AzNetworkInterface -ResourceGroupName $LB.refer -Location $LB.region `
        -Name $LB.nics -LoadBalancerBackendAddressPoolId $new_lbpool.Id -SubnetId $get_vnets.subnets[2].Id
    }
}

# 관리자 계정 생성, 암호화되지않은 표준 문자열을 보안 문자열로 변환 변수 선언
$VMs = $resourceinfos | Where-Object {$_.kind -eq "vm"}
$VMAdminUser = "shjoo"
$VMAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force
$Cred = New-Object System.Management.Automation.PSCredential ($VMAdminUser, $VMAdminSecurePassword);

# LB에서 생성한 nic 정보를 가져와 변수 선언 
$get_nic = Get-AzNetworkInterface -Name "nic*" 

# VM 3 대 배포 kc-01, ue-01, je-01
foreach($VM in $VMs){
    
    $VirtualMachine = New-AzVMConfig -VMName $VM.name -VMSize $VM.size
    $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $VM.name -Credential $cred
    $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $VM.publisher -Offer $VM.offer -Skus $VM.sku -Version latest
    
    # NIC 카드 VM에 연결
    if($VM.nics -eq "nic01"){
        Add-AzVMNetworkInterface -VM $VirtualMachine -Id $get_nic[0].id
    }
    elseif($VM.nics -eq "nic02"){
        Add-AzVMNetworkInterface -VM $VirtualMachine -Id $get_nic[1].Id
    }
    else{
        Add-AzVMNetworkInterface -VM $VirtualMachine -Id $get_nic[2].Id
    }

    New-AzVM -VM $VirtualMachine -ResourceGroupName $VM.refer -Location $VM.region -Verbose
  }

################################################

# 공통 IIS 변수 선언
$Publisher = 'Microsoft.Compute'
$ExtensionType = 'CustomScriptExtension'
$ExtensionName = 'IIS'
$TypeHandlerVersion = '1.8'
$SettingString = '{"commandToExecute":"powershell Add-WindowsFeature Web-Server; powershell Add-Content -Path \"C:\\inetpub\\wwwroot\\Default.htm\" -Value $($env:computername)"}'

### Script 동작 각 VM 머신 배포 
foreach($VM in $VMs){
    Set-AzVMExtension -Publisher $Publisher -ExtensionType $ExtensionType -ExtensionName $ExtensionName -ResourceGroupName $VM.refer -VMName $VM.name -Location $VM.region -TypeHandlerVersion $TypeHandlerVersion -settingString $SettingString
}

################################################
# vgw 관련 변수 선언
$gwsubnet = $resourceinfos | Where-Object {$_.kind -like "gateway*"}
$gwvm = $resourceinfos | Where-Object {$_.Name -like "vgw*"}

# 게이트 웨이 서브넷 생성 
$get_vnet2 = Get-AzVirtualNetwork -ResourceGroupName $gwvm.refer -Name $gwsubnet.refer
Add-AzVirtualNetworkSubnetConfig -Name $gwsubnet.Name -AddressPrefix $gwsubnet.ipaddress -VirtualNetwork $get_vnet2

# 가상네트워크에 GatewaySubnet 연결
$get_vnet2 = $get_vnet2 | Set-AzVirtualNetwork

# VGW 용 public IP 주소 생성 (VPN GW는 동적 IP 옵션만 지원)
$gwpip = New-AzPublicIpAddress -Name $gwsubnet.pipname -ResourceGroupName $get_vnet2.ResourceGroupName -Location $gwsubnet.region -AllocationMethod Dynamic

# GW IP 구성 설정 생성(pip, subnetid)
$gwipconfig = New-AzVirtualNetworkGatewayIpConfig -Name $gwsubnet.gwconf -SubnetId $get_vnet2.Subnets[1].id -PublicIpAddressId $gwpip.Id

# VPN Gateway 생성(IP, Type, VPN Type, SKU..)
$new_vgw = New-AzVirtualNetworkGateway -Name $gwvm.Name -ResourceGroupName $get_vnet2.ResourceGroupName `
-Location $gwsubnet.region -IpConfigurations $gwipconfig -GatewayType $gwsubnet.type `
-VpnType $gwsubnet.vpntype -GatewaySku $gwsubnet.sku

# VPN 클라이언트 주소 풀 추가(연결 대상 VNET과 겹치지 않도록 할 것)
$Get_Gateway = Get-AzVirtualNetworkGateway -ResourceGroupName $new_vgw.ResourceGroupName 
Set-AzVirtualNetworkGateway -VirtualNetworkGateway $Get_Gateway -VpnClientAddressPool $gwsubnet.vpnpool -VpnClientProtocol $gwsubnet.protocol

# 'P2SRootCert'자체 루트 인증서 생성 - 자물쇠
$cert = New-SelfSignedCertificate -Type Custom -KeySpec Signature `
 -Subject "CN=P2SRootCert" -KeyExportPolicy Exportable `
 -HashAlgorithm sha256 -KeyLength 2048 `
 -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsageProperty Sign -KeyUsage CertSign

# 클라이언트 인증서 생성 - 열쇠
New-SelfSignedCertificate -Type Custom -DnsName P2SChildCert -KeySpec Signature `
-Subject "CN=P2SChildCert" -KeyExportPolicy Exportable `
-HashAlgorithm sha256 -KeyLength 2048 `
-CertStoreLocation "Cert:\CurrentUser\My" `
-Signer $cert -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2")


# 루트 인증서 퍼블릭 키를 Azure Portal에 업로드할 경우 활용.
# 내보내기의 경우, 타 인원에 접근하고자 할 경우 활용토록 한다. Export "C:\cert\P2SRootCert.cer" 
$P2SRootCertName = "P2SRootCert.cer"
$filePathForCert = "C:\cert\P2SRootCert.cer"
$cert = new-object System.Security.Cryptography.X509Certificates.X509Certificate2($filePathForCert)
$CertBase64 = [system.convert]::ToBase64String($cert.RawData)

# 클라이언트 인증서 공개키 값 저장 
$p2spublic_key = New-AzVpnClientRootCertificate -Name $P2SRootCertName -PublicCertData $CertBase64
Add-AzVpnClientRootCertificate -VpnClientRootCertificateName $P2SRootCertName `
 -VirtualNetworkGatewayname $Get_Gateway.Name `
 -ResourceGroupName $new_vgw.ResourceGroupName -PublicCertData $CertBase64

###################################

# VNET Peering 변수 선언(vnet_1 - ue,je,kc-01, vnet_2 - ue,je,kc-02)
$get_vnet_1 = Get-AzVirtualNetwork -Name "vnet*01"
$get_vnet_2 = Get-AzVirtualNetwork -Name "vnet*02"

# 서로 다른 리전 간 Peering ( KC-01 <-> JE-01, JE-01 <-> UE-01 ) 
Add-AzVirtualNetworkPeering -Name ($get_vnet_1[0].name + "-To-" + $get_vnet_1[1].name) -VirtualNetwork $get_vnet_1[0] -RemoteVirtualNetworkId $get_vnet_1[1].id -UseRemoteGateways -AllowForwardedTraffic 
Add-AzVirtualNetworkPeering -Name ($get_vnet_1[1].name + "-To-" + $get_vnet_1[0].name) -VirtualNetwork $get_vnet_1[1] -RemoteVirtualNetworkId $get_vnet_1[0].id -AllowGatewayTransit -AllowForwardedTraffic 
Add-AzVirtualNetworkPeering -Name ($get_vnet_1[1].name + "-To-" + $get_vnet_1[2].name) -VirtualNetwork $get_vnet_1[1] -RemoteVirtualNetworkId $get_vnet_1[2].id -AllowGatewayTransit -AllowForwardedTraffic 
Add-AzVirtualNetworkPeering -Name ($get_vnet_1[2].name + "-To-" + $get_vnet_1[1].name) -VirtualNetwork $get_vnet_1[2] -RemoteVirtualNetworkId $get_vnet_1[1].id -UseRemoteGateways -AllowForwardedTraffic  

# 동일 리전간 Peering ( UE <-> UE 2, JE <-> JE 2, KC <-> KC 2 )
for($i=0; $i -lt $get_vnet_1.length; $i++){
    if($i -eq 0){  # UE-01 <-> UE-02 
        Add-AzVirtualNetworkPeering -Name ($get_vnet_1[$i].name + "-To-" + $get_vnet_2[$i].name) -VirtualNetwork $get_vnet_1[$i] -RemoteVirtualNetworkId $get_vnet_2[$i].id -AllowForwardedTraffic 
        Add-AzVirtualNetworkPeering -Name ($get_vnet_2[$i].name + "-To-" + $get_vnet_1[$i].name) -VirtualNetwork $get_vnet_2[$i] -RemoteVirtualNetworkId $get_vnet_1[$i].id -AllowForwardedTraffic
    }
    elseif($i -eq 1){ # JE-01(VGW) <-> JE-02 
        Add-AzVirtualNetworkPeering -Name ($get_vnet_1[$i].name + "-To-" + $get_vnet_2[$i].name) -VirtualNetwork $get_vnet_1[$i] -RemoteVirtualNetworkId $get_vnet_2[$i].id -AllowForwardedTraffic -AllowGatewayTransit 
        Add-AzVirtualNetworkPeering -Name ($get_vnet_2[$i].name + "-To-" + $get_vnet_1[$i].name) -VirtualNetwork $get_vnet_2[$i] -RemoteVirtualNetworkId $get_vnet_1[$i].id -AllowForwardedTraffic -UseRemoteGateways
    }
    elseif($i -eq 2){ # KC-01 <-> KC-02 
        Add-AzVirtualNetworkPeering -Name ($get_vnet_1[$i].name + "-To-" + $get_vnet_2[$i].name) -VirtualNetwork $get_vnet_1[$i] -RemoteVirtualNetworkId $get_vnet_2[$i].id -AllowForwardedTraffic
        Add-AzVirtualNetworkPeering -Name ($get_vnet_2[$i].name + "-To-" + $get_vnet_1[$i].name) -VirtualNetwork $get_vnet_2[$i] -RemoteVirtualNetworkId $get_vnet_1[$i].id -AllowForwardedTraffic
    }
}


###########################
# 리소스 그룹 제거 
foreach ($rg in $RGs){
    Remove-AzResourceGroup -Name $RG.name -force
}


$job = Start-Job -ScriptBlock { Get-Process -Name pwsh}
Receive-Job

Get-Job
remove-job 

# get-job 명령을 그대로 파이프라인해서 명령을 활용 (전체 제거 )
Get-Job | remove-job
Get-Job
###########################