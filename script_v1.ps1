Get-AzResourceGroup

Get-AzResource

### 뭘 끌지 정해놓지 않음 ###
stop-azvm

### 문서를 자주 봐야함. 파라미터가 바뀌는 걸 알 수 있으므로

### 와일드 마스크 연습 ###
Get-AzResource -Name "?M-KC-??"
Get-AzResource -Name "*-KC-*"
Get-AzResource -Name "LB-KC-*"
Get-AzResource -Name "LB-*-*"


Get-AzAppServicePlan


## 변수 선언 ##
$rginfo = Get-AzResource

$rginfo.GetType()
$rginfo.name[0].GetType()

$rginfo=""

## 자료형 선언이 없다보니, 변수의 재활용이 가능하다.
## 개별 변수를 선언할 수 있고, Flow를 명확하게 알면 재활용해서 사용할 수 있다. 

$rginfo 

## 값을 일부 호출 가능 Array => String으로 변경되는 것이다.
Get-AzResource -Name $rginfo.Name[0]
$rginfo.getType()
$rginfo.Name[1].getType()
# Get-AzResource -Name $rginfo.Name[1].GetType()
$rginfo

## foreach 돌면서 각각 도는 것 -> 여러 개가 있어도 한꺼번에 처리가 가능하다. 
## get-azVM 정보를 가져와서 staz vm해서 변수에 담은 이름을 불러다가 끄면 됌

$aspname

foreach ($aspname in ($rginfo.name)){
    $aspname
    Pause
}

$vminfo = Get-AzVM

Stop-azVM -Name $vminfo.name[0]
Stop-azVM -Name $vminfo.name[1]

$vminfo

$vminfo | Where-Object {$_.kind -eq "Name"} | Format-Table
$vminfo.count
$vminfo

foreach ($vmname in ($vminfo.name)){
    # Stop-azVM -Name $vminfo.name
    # $vminfo
    $vmname
    Pause
}

###
$vminfos = get-azVM
$vminfos


foreach($vminfo in $vminfos){
    # $vminfo.name
    $vminfo
    pause
}

$vminfos.getType() # Array
$vminfos.Name.getType() # Array
$vminfos.Name[0].getType() # Object

## 객체.속성-> 배열

###
foreach ($vmname in ($vminfo.name)){
    # Stop-azVM -Name $vminfo.name
    # $vmname
    $vminfo
    Pause
}

### powershell에서 불러올때는 csv가 가장 편리하다.
### 그래서, import-csv
### Debug : 에러 났을 때 
### Error : 경고, impormation 정도 수준에서 띄울껀지 정할 수 있다.
### Errorvaroable foreach 동작 시 에러를 띄우기 위함(디버깅)
### 콤마, 세미콜런, Delimiter라 부른다. 
### 한글 UTF-8 , 그 외 ANSI
$resourcedocs = Import-csv -Path "C:\Users\20132\git\resourcecreate.csv"

$resourcedocs

$resourceinfos = import-csv -Path $rsourcedocs
$resourceinfos = import-csv -Path "C:\Users\shj\shtest\Git_Test\resourcecreate.csv"

### 포맷 테이블 - 테이블 형태로 변경
### 형태 : $source | $receiver 

$resourceinfos | Format-table

# Format-Table -
# 뒤에 내용이 잘렸을 때 - auto size
$resourceinfos | Format-table -AutoSize
$resourceinfos

# 핵심은 Pipe를 토대로 필터링을 수행하는 것이다!!

# 리소스 그룹만 쓰고 싶을때 
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

# 따라서, where를 사용하여 필터링을 수행하자. $_ : 앞의 변수를 의미한다. 
# 나는 이 kind 중에서 resource group만 가져오고 싶어 -eq : 연산자
# https://docs.microsoft.com/ko-kr/powershell/module/microsoft.powershell.core/about/about_comparison_operators?view=powershell-7.2
# https://docs.microsoft.com/ko-kr/powershell/module/microsoft.powershell.core/about/about_operators?view=powershell-7.2
# about_comparison_operators 
$resourceinfos | Where-Object {$_.kind -eq "resourcegroup"} | Format-Table
$resourceinfos

# 재활용을 위해 변수에 저장 
$resourcegroups = $resourceinfos | Where-Object {$_.kind -eq "resourcegroup"}
$resourcegroups.getType()
$resourcegroups

# 리소스 그룹을 만들어보자 kind, locate, resourcegroup 3가지 정보를 토대로..
# get-azresourcegroup 핵심값 name -location
# 여기서 말하는 수는 지시자를 의미한다. 숫자가 아니다..

$B = ,1
$B.getType()

$newrgs = new-azResourceGroup -Name $resourcegroups.ResourceGroupName[2] -Location $resourcegroups.Location[2]
$newrgs.getType()
$newrgs

# 리소스 그룹 생성 테스트 
$resourcegroup = New-AzResourceGroup -Name RG-Korea -Location "koreacentral"
$resourcegroup.getType()
$resourcegroup = New-AzResourceGroup -Name RG-Japan -Location "japaneast"
$resourcegroup.getType()
$resourcegroup.name

$resourcegroup = New-AzResourceGroup -Name RG-US -Location "central US"

foreach($newrg in $newrgs){
    $newrg
    pause
}


$resourcegroups.resourcegroupname
$resourcegroups.count
# $resourcegroups.name

$i = 0
$j = $resourcegroups.count
for($i; $i -le $j; $i++){
    $resourcegroups.ResourceGroupName[$i]
    # Remove-azResourceGroup -Name $resourcegroups.ResourceGroupName[$i] -Location $resourcegroups.Location[$i]
}

# 리소스 그룹 제거. https://docs.microsoft.com/ko-kr/powershell/module/az.resources/remove-azresourcegroup?view=azps-6.6.0 
foreach ($resourcegroup in $resourcegroups){ # 복수 단수
    Remove-azResourceGroup -Name $resourcegroup.ResourceGroupName -Location $resourcegroup.Location
}

# 리소스 그룹 제거 2 
# Get-AzResourceGroup -Name "ContosoRG01" | Remove-AzResourceGroup -Force
# Remove a resource group without confirmation
foreach ($resourcegroup in $resourcegroups){ # 복수 단수
    Remove-azResourceGroup -Name $resourcegroup.ResourceGroupName -force
}

# Remove all resource groups

# 리소스 그룹 생성. foreach는 따로 Y N 입력이 필요없음..
foreach ($resourcegroup in $resourcegroups){ # 복수 단수
    new-azResourceGroup -Name $resourcegroup.ResourceGroupName -Location $resourcegroup.Location
}

# 이 단계에 무슨 값이 있는지 flow를 확인해야함. getType()해서 무슨 값이네.. 
# Stirng or Array 라면, 어떤 처리를 해야할지.. 
# 변수를 그때 그떄 선언해야하므로, csv를 불러 사용하는 것이 바람직.. 
# 일일히 손수 작성하기는 애로사항이 있다. 

# 디버깅 실행 구문은 정지하고 나와야하는 값들이 제대로 나오는지? 확인을 해야한다.

# 리소스 만드는 것 

# foreach csv로 가져왔으니 깐깐한 것, pause를 때려서 쭉나오도록하면 된다. 
# 리소스를 만드는 것은 나중 이야기, 대량 데이터를 불러오고 다룰 수 있는가..? 
# foreach -> 직렬 (foreach-직)job(병렬)으로 감싼다.. => 기본 150*100=7 시간 생성 보다 월등히 짧음
# 목표 : 대량 데이터를 어떻게 다룰 것인가?


# # 과제 
# 스크립트로 VM 생성
# RG, VNET, Subnet 1ea

# AVSet 1ea

# Option
# Vm 3ea OS 종류 무관
# sku 는 제일 작은거
# 공인 IP 는 vm 중 하나만,Option
# NSG 생성 해서 회사 IP 만 접근 가능 하도록

# # 데이터 처리 방식은 자유..! 사람마다 방식이 다르므로..
# 데이터 소스를 어떻게하느냐
# VNET RG만 가지고 try 해보면, 감이 올 수 있음..!

# # 데이터를 처리해서 보여줄 수 있어야 함..!

# 가상 네트워크 및 서브넷 생성 
New-AzResourceGroup -Name "RG-TEST2" -Location "centralus"
$frontendSubnet = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet -AddressPrefix "10.0.1.0/24"
$backendSubnet  = New-AzVirtualNetworkSubnetConfig -Name backendSubnet  -AddressPrefix "10.0.2.0/24"
New-AzVirtualNetwork -Name "VNET-UC" -ResourceGroupName "RG-TEST2" -Location "centralus" -AddressPrefix "10.0.0.0/16" -Subnet $frontendSubnet,$backendSubnet


# RG VNET SUBNET NSG 연결
New-AzResourceGroup -Name "RG-TEST2" -Location "centralus"
$rdpRule              = New-AzNetworkSecurityRuleConfig -Name "rdp-rule" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389
$networkSecurityGroup = New-AzNetworkSecurityGroup -ResourceGroupName "RG-TEST2" -Location "centralus" -Name "NSG-FrontEnd" -SecurityRules $rdpRule
$frontendSubnet       = New-AzVirtualNetworkSubnetConfig -Name "frontendSubnet" -AddressPrefix "10.0.1.0/24" -NetworkSecurityGroup $networkSecurityGroup
$backendSubnet        = New-AzVirtualNetworkSubnetConfig -Name "backendSubnet"  -AddressPrefix "10.0.2.0/24" -NetworkSecurityGroup $networkSecurityGroup
New-AzVirtualNetwork -Name "VNET-UC" -ResourceGroupName "RG-TEST2" -Location "centralus" -AddressPrefix "10.0.0.0/16" -Subnet $frontendSubnet,$backendSubnet


# NSG RULE Config
$rule1 = New-AzNetworkSecurityRuleConfig -Name rdp-rule -Description "Allow RDP" `
    -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix `
    Internet -SourcePortRange * -DestinationAddressPrefix * -DestinationPortRange 3389











