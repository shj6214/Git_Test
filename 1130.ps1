
$vminfos = Get-AzVM

  

foreach ($vminfo in $ $vminfos){
    $vminfo
    Pause
}

$resourcedocs = "C:\Users\shj\shtest\Git_Test\resourcecreate.csv"

$resourceinfos = Import-csv -Path $resourcedocs

$resourceinfos | Select-String -Pattern "resourcegroup"

$resourcegroups | Format-Table

$vms = $resourceinfos | Where-Object {$_.kind -eq "vm"}

 # Array -> Object로 변경하고자할 때 for, foreach
    foreach ($vm in $vms) {
        write-host "pip value:" $vm.publicip
        switch ($vm.publicip) {
            "yes" { Write-Host $vm.resourcename "공인 IP 사용 합니다." }
            "" { Write-Host $vm.resourcename "공인 IP 사용 안 합니다." }
            # "" : null, ""로 표현해도 되고, 지금같이 csv에서 space 잘못 입력시 고돼짐.
            # default { Write-Host $vm.resourcename "공인 IP 사용 안 합니다." }
        } 
    }
    # "default" : String 
    # default : 명령문의 일부 
# 배열로 떨어지기때문에 출력 불가. 
$vms.publicip.gettype()

# https://namu.wiki/w/CPU%20%EA%B2%8C%EC%9D%B4%ED%8A%B8?from=CPU%EA%B2%8C%EC%9D%B4%ED%8A%B8

# write-host : 받아서 다른 곳에 쓸 수 있음.
# write-output : 

# wildcard example -> 판단을 하지않고 주어진 값으로 진행을 수행한다.
foreach ($vm in $vms) {
    write-host "pip value:" $vm.publicip
    switch -Wildcard ($vm.publicip) {
        "y*" { Write-Host $vm.resourcename "공인 IP 사용 합니다." }
        "*s" { Write-Host $vm.resourcename "공인 IP 사용 합니다." }
        "" { Write-Host $vm.resourcename "공인 IP 사용 안 합니다." }
        # "" : null, ""로 표현해도 되고, 지금같이 csv에서 space 잘못 입력시 고돼짐.
        # default { Write-Host $vm.resourcename "공인 IP 사용 안 합니다." }
    }
}

# wildcard는 본인이 원하는 것을 판단하여 써야하는데 그 이유는?
# get-process를 하게되면, 작업 관리자 > 세부 정보 탭 리스트가 나온다. 
#  notepad.exe 프로그램 > 우클릭 > 속성 탭에서 프로세스 ID 확인 가능

while (condition){
    $processliveCheck = get-process -Name notepad
    if($null -eq $processliveCheck){
        
    }

    Start-Sleep -Seconds 5 
}


while ($true) {
    $processlivecheck = get-process -Name notepad -ErrorAction SilentlyContinue    
    if ($null -eq $processlivecheck) {        
        Write-Host "메모장이 죽었습니다."    
    }    
    Start-Sleep -Seconds 5
}

# 명령 후, 프로세스가 종료되는 것을 확인할 수 있다. 
# 다음주에 볼 것은 about do 
# 반복문은 모니터링 아니면 사용할 일없음. 
# 리소스 만드는 것은 foreach로 마무리. 나머지는 루프 돌일일이 없다.
# do while, do until... 

######### 11 30 교육 ###########
$job = Start-Job -ScriptBlock { Get-Process -Name pwsh }
Receive-Job

Get-Job
remove-job 


#

while (condition){
    $processliveCheck = get-process -Name notepad
    if($null -eq $processliveCheck){
        
    }

    Start-Sleep -Seconds 5 
}
