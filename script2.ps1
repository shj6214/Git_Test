


# Azure Powershell 접속 
Coonnect-AzAccount

# csv 파일 import 
$resourcedocs = Import-csv -Path "C:\Users\shj\shtest\Git_Test\resourcecreate.csv"

$resourcedocs

$resourceinfos = import-csv -Path $r

$vminfo | Where-Object {$_.kind -eq "Name"} | Format-Table

# 프로퍼티 선언 처리 
$resourceinfos | Select-Object

# String 문자열 처리 
$resourceinfos | Select-String 

# 
# https://ss64.com/ps/select-string.html
# 정규 표현식 숙지하자.
# String 에 해당하는 패턴 라인 전부 출력 
$resourceinfos | Select-String -Pattern "resourcegroup"

# 속성에 해당하는 행만 출력
$resourceinfos | Select-Object -Property "kind"

# 파이프를 연속으로 활용하여 원하는 값을 도출할 수 있다. 따로 선언하지 않고 넘겨주고 넘겨줄 수 있다는 특징을 가진다.
$resourceinfos | Select-Object -Property "kind" | select-string -Pattern "resourcegroup"

# 내가 원하는 정보를 패턴을 해서 모두 뽑아낼 것이냐? No
$resourceinfos | Select-String -Pattern "resourcegroup"

# 리소스 그룹 제거
Remove-AzResourceGroup -Name $resourcegroup



#  리소스 그룹 이름 생성 

# 지역 설정
$LocationName = "koreacentral"

# 리소스 그룹 이름
$resourcegroup = "RG-Korea"
# $resourcegroup2 = "RG-Japan"
# $resourcegroup3 = "RG-US"



New-AzResourceGroup -Name $resourcegroup -Location $LocationName
#New-AzResourceGroup -Name $resourcegroup2 -Location "japaneast"
#New-AzResourceGroup -Name $resourcegroup3 -Location "central US"

# VNET , Subnet, NSG 생성 및 연결 (RG, VNET,SUBNET 1 EA, NSG는 회사 IP만 접근 가능토록.. )
# $rg1= New-AzResourceGroup -Name $resourcegroup -Location "koreacentral"

$rdpRule              = New-AzNetworkSecurityRuleConfig -Name "rdp-rule" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix 123.141.145.23 -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$sshRule              = New-AzNetworkSecurityRuleConfig -Name "ssh-rule" -Description "Allow SSH" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix 123.141.145.23 -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 22
$httpRule             = New-AzNetworkSecurityRuleConfig -Name "http-rule" -Description "Allow HTTP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 101 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 80

$networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName $resourcegroup -Location $LocationName -Name "NSG-FrontEnd" -SecurityRules $rdpRule,$httpRule
$Subnet       = New-AzVirtualNetworkSubnetConfig -Name "snet-01" -AddressPrefix "10.0.1.0/24" -NetworkSecurityGroup $networkSecurityGroup
$vnet = New-AzVirtualNetwork -Name "VNET-KC" -ResourceGroupName $resourcegroup -Location $LocationName -AddressPrefix "10.0.0.0/16" -Subnet $Subnet

# $backendSubnet        = New-AzVirtualNetworkSubnetConfig -Name "backendSubnet"  -AddressPrefix "10.0.2.0/24" -NetworkSecurityGroup $networkSecurityGroup
# New-AzVirtualNetwork -Name "VNET-KC" -ResourceGroupName "RG-Korea" -Location "koreacentral" -AddressPrefix "10.0.0.0/16" -Subnet $Subnet,$backendSubnet

# PIP 생성 (VM 1ea만, 나머지는 사설 IP) -> foreach 돌리고, PIP 추가 할 것! 

# $PIP1 = Get-AzPublicIPAddress -Name "PIP1" -ResourceGroupName "RG-Korea"
$PIP = New-AzPublicIpAddress -Name "PIP" -ResourceGroupName $resourcegroup -AllocationMethod Static -Location $LocationName -Sku "Standard"
# $IPConfig1 = New-AzNetworkInterfaceIpConfig -Name "IPConfig-1" -PrivateIpAddressVersion "IPv4" -PrivateIpAddress "10.0.1.9" -Primary -SubnetId $vnet1.Subnets.Id -PublicIpAddressId $PIP1.Id
$nic = New-AzNetworkInterface -Name "NIC$i" -ResourceGroupName $resourcegroup -Location $LocationName -SubnetId $vnet.Subnets.Id -PublicIpAddressId $PIP1.id -PrivateIpAddress 10.0.1.9
# -IpConfigurationName $IPConfig1

# -SubnetId $vnet1.Subnets.Id

# 그 외 VM 사설 IP 생성
# $IPConfig2 = New-AzNetworkInterfaceIpConfig -Name "IP-Config2" -SubnetId $vnet1.Subnets.Id -PrivateIpAddressVersion "IPv4" -PrivateIpAddress "10.0.1.11"
$nic2 = New-AzNetworkInterface -Name "NIC2" -ResourceGroupName $resourcegroup -Location $LocationName -SubnetId $vnet.Subnets.Id

# $IPConfig3 = New-AzNetworkInterfaceIpConfig -Name "IP-Config3" -SubnetId $vnet1.Subnets.Id -PrivateIpAddressVersion "IPv4" -PrivateIpAddress "10.0.1.12"
$nic3 = New-AzNetworkInterface -Name "NIC3" -ResourceGroupName $resourcegroup -Location $LocationName -SubnetId $vnet.Subnets.Id


# 가용성 집합 추가
$avset = New-AzAvailabilitySet -ResourceGroupName $resourcegroup -Name "AvSet01" -Location $LocationName -PlatformFaultDomainCount 2 -PlatformUpdateDomainCount 3 -Sku "Aligned"

# VM01 생성

## VM Account
# Credentials for Local Admin account you created in the sysprepped (generalized) vhd image
# 관리자 계정 생성 
# 암호화된 표준 문자열을 보안 문자열로 변환
$VMLocalAdminUser = "shjoo"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force

# 가상 머신 호스트 OS 이름을 설정. Win 15, Linux 64 자. 
$ComputerName = "shVM$i"

# VM 세부 사항 
$VMName = "shVM$i"
$VMSize = "Standard_B1ls"

### 
#Networking 
$NetworkName = "VNET-KC"
$NICName = "NIC1"
$SubnetName = "Subnet"
$SubnetAddressPrefix = "10.0.1.0/24"
$VnetAddressPrefix = "10.0.0.0/16"

$SingleSubnet = New-AzVirtualNetworkSubnetConfig -Name $SubnetName -AddressPrefix $SubnetAddressPrefix
$Vnet = New-AzVirtualNetwork -Name $NetworkName -ResourceGroupName $resourcegroup -Location $LocationName -AddressPrefix $VnetAddressPrefix -Subnet $SingleSubnet
$NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $resourcegroup -Location $LocationName -SubnetId $vnet.Subnets[0].Id
###

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

# Windows - 최소 이미지 크기 B1s 
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetID $avset.Id
Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

# Linux - 최소 이미지 크기 B1ls 
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetID $avset.Id
Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $ComputerName -Credential $Credential
Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic.Id
Set-AzVMSourceImage -VM $VirtualMachine -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "18.04-LTS" -Version latest

New-AzVM -ResourceGroupName $resourcegroup -Location $LocationName -VM $VirtualMachine -Verbose



###
# VM02 생성

## VM Account
# Credentials for Local Admin account you created in the sysprepped (generalized) vhd image
# 관리자 계정 생성 
# 암호화된 표준 문자열을 보안 문자열로 변환
$VMLocalAdminUser = "shjoo"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force

# 가상 머신 호스트 OS 이름을 설정. Win 15, Linux 64 자. 
$ComputerName2 = "shVM2"

# VM 세부 사항 
$VMName2 = "shVM2"
$VMSize2 = "Standard_B1ls"

###
# nic 생성 
$nic2 = New-AzNetworkInterface -Name "NIC2" -ResourceGroupName $resourcegroup -Location $LocationName -SubnetId $vnet1.Subnets.Id
###

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

# Windows - 최소 이미지 크기 B1s 
$VirtualMachine = New-AzVMConfig -VMName $VMName2 -VMSize $VMSize2 -AvailabilitySetID $avset.Id
Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName2 -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic2.Id
Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

# Linux - 최소 이미지 크기 b1ls
$VirtualMachine = New-AzVMConfig -VMName $VMName2 -VMSize $VMSize2 -AvailabilitySetID $avset.Id
Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $ComputerName -Credential $Credential
Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic2.Id
Set-AzVMSourceImage -VM $VirtualMachine -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "18.04-LTS" -Version latest

New-AzVM -ResourceGroupName $resourcegroup -Location $LocationName -VM $VirtualMachine -Verbose

#####################
# VM02 생성

## VM Account
# Credentials for Local Admin account you created in the sysprepped (generalized) vhd image
# 관리자 계정 생성 
# 암호화된 표준 문자열을 보안 문자열로 변환
$VMLocalAdminUser = "shjoo"
$VMLocalAdminSecurePassword = ConvertTo-SecureString "P@ssw0rd1!" -AsPlainText -Force

# 가상 머신 호스트 OS 이름을 설정. Win 15, Linux 64자
$ComputerName = "shVM"

# VM 세부 사항 
$VMName = "shVM2"
$VMSize = "Standard_B1s"

###
# nic 생성 
$nic3 = New-AzNetworkInterface -Name "NIC3" -ResourceGroupName $resourcegroup -Location $LocationName -SubnetId $vnet.Subnets.Id 
###

$Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword);

# Windows - 최소 이미지 크기 B1s 
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetID $avset.Id
Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic3.Id
Set-AzVMSourceImage -VM $VirtualMachine -PublisherName 'MicrosoftWindowsServer' -Offer 'WindowsServer' -Skus '2019-Datacenter' -Version latest

# Linux - 최소 이미지 크기 B1ls 
$VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize -AvailabilitySetID $avset.Id
Set-AzVMOperatingSystem -VM $VirtualMachine -Linux -ComputerName $ComputerName -Credential $Credential
Add-AzVMNetworkInterface -VM $VirtualMachine -Id $nic3.Id
Set-AzVMSourceImage -VM $VirtualMachine -PublisherName "Canonical" -Offer "UbuntuServer" -Skus "18.04-LTS" -Version latest

New-AzVM -ResourceGroupName $resourcegroup -Location $LocationName -VM $VirtualMachine -Verbose






