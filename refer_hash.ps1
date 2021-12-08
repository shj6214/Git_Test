
$VMsetting = @{ 
    VMName = $vm.resourcename; 
    VMsize = $vm.size}    
$vmos = @{ 
    ComputerName = $vm.computername ; 
    Credential = $Credential}    
$vmimage = @{ PublisherName = $vm.publisher; 
            offer = $vm.offer ; Skus = $vm.sku ; 
            version = $vm.version}    

if ($vm.ostype -eq "window") {        
    $windowVMconfig = New-AzVMConfig @VMsetting | Set-AzVMOperatingSystem @vmos -Windows -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate | Set-AzVMSourceImage @vmimage | Add-AzVMNetworkInterface -Id $nic.Id        
    $windowVirtalMachine = @{resourcegroupname = $rg.resourcegroupname ; location = $rg.location ; vm = $windowVMconfig}        
    New-AzVM @windowVirtalMachine
    }else { 
        $linuxVMconfig = New-AzVMConfig @VMsetting  | Set-AzVMOperatingSystem @vmos -Linux -Credential $Credential  | Set-AzVMSourceImage @vmimage | Add-AzVMNetworkInterface -Id $nic.Id
        $linuxVirtalMachine = @{resourcegroupname = $rg.resourcegroupname ; location = $rg.location ; vm = $linuxVMconfig
    }        
    New-AzVM @linuxVirtalMachine
}
