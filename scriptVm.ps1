

# Variables for the deployment
$adminUsername = "azureadmin"
$adminPassword = ("PASSWORD PATH")
$vmSize = "Standard_B1ms" # 1 vCPU, 2GB RAM
$publisher = "MicrosoftWindowsServer"
$offer = "WindowsServer"
$sku = "2022-datacenter-core-g2" # Use Core instead of Desktop Experience
$version = "latest"

# Team Group IDs
$salesGroupId = ""
$engineeringGroupId = ""
$customerGroupId = ""

# Create Engineering VM2 if it doesn't exist
$engineeringRg = "Engineering-RG"
$engineeringRegion = "eastus"
$engineeringVm = "Engineering-VM2"

if (-not (Get-AzVM -ResourceGroupName $engineeringRg -Name $engineeringVm -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Engineering VM2..." -ForegroundColor Green
    
    # Ensure resource group exists
    if (-not (Get-AzResourceGroup -Name $engineeringRg -ErrorAction SilentlyContinue)) {
        New-AzResourceGroup -Name $engineeringRg -Location $engineeringRegion
    }
    
    # Check if VNet exists
    $vnetName = "Engineering-VNet"
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $engineeringRg -Name $vnetName -ErrorAction SilentlyContinue
    
    if (-not $vnet) {
        $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "Engineering-Subnet" -AddressPrefix "10.0.0.0/24"
        $vnet = New-AzVirtualNetwork -ResourceGroupName $engineeringRg -Name $vnetName -Location $engineeringRegion -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig
    }
    
    # Check if NSG exists
    $nsgName = "Engineering-NSG"
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $engineeringRg -Name $nsgName -ErrorAction SilentlyContinue
    
    if (-not $nsg) {
        $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $engineeringRg -Location $engineeringRegion -Name $nsgName
        $nsg | Add-AzNetworkSecurityRuleConfig -Name "AllowRDP" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 3389 | Set-AzNetworkSecurityGroup
    }
    
    # Create Public IP
    $publicIpName = "$engineeringVm-PublicIP"
    $publicIp = New-AzPublicIpAddress -ResourceGroupName $engineeringRg -Location $engineeringRegion -Name $publicIpName -AllocationMethod Dynamic
    
    # Create NIC
    $nicName = "$engineeringVm-NIC"
    $nic = New-AzNetworkInterface -ResourceGroupName $engineeringRg -Location $engineeringRegion -Name $nicName -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id
    
    # Create VM Configuration
    $vmConfig = New-AzVMConfig -VMName $engineeringVm -VMSize $vmSize
    
    # Set OS Configuration
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $engineeringVm -Credential (New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)) -ProvisionVMAgent -EnableAutoUpdate
    
    # Set Source Image
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisher -Offer $offer -Skus $sku -Version $version
    
    # Add NIC
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
    
    # Configure OS Disk
    $osDiskName = "$engineeringVm-OSDisk"
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $osDiskName -CreateOption FromImage -StorageAccountType Standard_LRS
    
    # Create VM
    New-AzVM -ResourceGroupName $engineeringRg -Location $engineeringRegion -VM $vmConfig
    
    # Add 1GB Data Disk
    $dataDiskName = "$engineeringVm-DataDisk"
    $vm = Get-AzVM -ResourceGroupName $engineeringRg -Name $engineeringVm
    Add-AzVMDataDisk -VM $vm -Name $dataDiskName -DiskSizeInGB 1 -Lun 0 -CreateOption Empty -StorageAccountType Standard_LRS
    Update-AzVM -ResourceGroupName $engineeringRg -VM $vm
    
    # Assign role to Entra group
    $vmId = (Get-AzVM -ResourceGroupName $engineeringRg -Name $engineeringVm).Id
    New-AzRoleAssignment -ObjectId $engineeringGroupId -RoleDefinitionName "Virtual Machine Administrator Login" -Scope $vmId
    
    Write-Host "Engineering VM2 created successfully!" -ForegroundColor Green
}
else {
    Write-Host "Engineering VM2 already exists. Skipping." -ForegroundColor Yellow
}

# Create Sales & Marketing VMs
$salesRg = "SalesMarketing-RG"
$salesRegion = "westus"

# Ensure resource group exists
if (-not (Get-AzResourceGroup -Name $salesRg -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $salesRg -Location $salesRegion
}

# Create VNet if it doesn't exist
$vnetName = "SalesMarketing-VNet"
$vnet = Get-AzVirtualNetwork -ResourceGroupName $salesRg -Name $vnetName -ErrorAction SilentlyContinue

if (-not $vnet) {
    $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "SalesMarketing-Subnet" -AddressPrefix "10.0.0.0/24"
    $vnet = New-AzVirtualNetwork -ResourceGroupName $salesRg -Name $vnetName -Location $salesRegion -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig
}

# Create NSG if it doesn't exist
$nsgName = "SalesMarketing-NSG"
$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $salesRg -Name $nsgName -ErrorAction SilentlyContinue

if (-not $nsg) {
    $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $salesRg -Location $salesRegion -Name $nsgName
    $nsg | Add-AzNetworkSecurityRuleConfig -Name "AllowRDP" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 3389 | Set-AzNetworkSecurityGroup
}

# Create 2 VMs
for ($i = 1; $i -le 2; $i++) {
    $vmName = "SalesMarketing-VM$i"
    
    if (-not (Get-AzVM -ResourceGroupName $salesRg -Name $vmName -ErrorAction SilentlyContinue)) {
        Write-Host "Creating $vmName..." -ForegroundColor Green
        
        # Create Public IP
        $publicIpName = "$vmName-PublicIP"
        $publicIp = New-AzPublicIpAddress -ResourceGroupName $salesRg -Location $salesRegion -Name $publicIpName -AllocationMethod Dynamic
        
        # Create NIC
        $nicName = "$vmName-NIC"
        $nic = New-AzNetworkInterface -ResourceGroupName $salesRg -Location $salesRegion -Name $nicName -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id
        
        # Create VM Configuration
        $vmConfig = New-AzVMConfig -VMName $vmName -VMSize $vmSize
        
        # Set OS Configuration
        $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $vmName -Credential (New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)) -ProvisionVMAgent -EnableAutoUpdate
        
        # Set Source Image
        $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisher -Offer $offer -Skus $sku -Version $version
        
        # Add NIC
        $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
        
        # Configure OS Disk
        $osDiskName = "$vmName-OSDisk"
        $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $osDiskName -CreateOption FromImage -StorageAccountType Standard_LRS
        
        # Create VM
        New-AzVM -ResourceGroupName $salesRg -Location $salesRegion -VM $vmConfig
        
        # Add 1GB Data Disk
        $dataDiskName = "$vmName-DataDisk"
        $vm = Get-AzVM -ResourceGroupName $salesRg -Name $vmName
        Add-AzVMDataDisk -VM $vm -Name $dataDiskName -DiskSizeInGB 1 -Lun 0 -CreateOption Empty -StorageAccountType Standard_LRS
        Update-AzVM -ResourceGroupName $salesRg -VM $vm
        
        # Assign role to Entra group
        $vmId = (Get-AzVM -ResourceGroupName $salesRg -Name $vmName).Id
        New-AzRoleAssignment -ObjectId $salesGroupId -RoleDefinitionName "Virtual Machine Administrator Login" -Scope $vmId
        
        Write-Host "$vmName created successfully!" -ForegroundColor Green
    }
    else {
        Write-Host "$vmName already exists. Skipping." -ForegroundColor Yellow
    }
}

# Create Customer Success VM1
$customerRg = "CustomerSuccess-RG"
$customerRegion = "centralus"
$customerVm = "CustomerSuccess-VM1"

if (-not (Get-AzVM -ResourceGroupName $customerRg -Name $customerVm -ErrorAction SilentlyContinue)) {
    Write-Host "Creating Customer Success VM1..." -ForegroundColor Green
    
    # Ensure resource group exists
    if (-not (Get-AzResourceGroup -Name $customerRg -ErrorAction SilentlyContinue)) {
        New-AzResourceGroup -Name $customerRg -Location $customerRegion
    }
    
    # Check if VNet exists
    $vnetName = "CustomerSuccess-VNet"
    $vnet = Get-AzVirtualNetwork -ResourceGroupName $customerRg -Name $vnetName -ErrorAction SilentlyContinue
    
    if (-not $vnet) {
        $subnetConfig = New-AzVirtualNetworkSubnetConfig -Name "CustomerSuccess-Subnet" -AddressPrefix "10.0.0.0/24"
        $vnet = New-AzVirtualNetwork -ResourceGroupName $customerRg -Name $vnetName -Location $customerRegion -AddressPrefix "10.0.0.0/16" -Subnet $subnetConfig
    }
    
    # Check if NSG exists
    $nsgName = "CustomerSuccess-NSG"
    $nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $customerRg -Name $nsgName -ErrorAction SilentlyContinue
    
    if (-not $nsg) {
        $nsg = New-AzNetworkSecurityGroup -ResourceGroupName $customerRg -Location $customerRegion -Name $nsgName
        $nsg | Add-AzNetworkSecurityRuleConfig -Name "AllowRDP" -Description "Allow RDP" -Access Allow -Protocol Tcp -Direction Inbound -Priority 100 -SourceAddressPrefix "*" -SourcePortRange "*" -DestinationAddressPrefix "*" -DestinationPortRange 3389 | Set-AzNetworkSecurityGroup
    }
    
    # Create Public IP
    $publicIpName = "$customerVm-PublicIP"
    $publicIp = New-AzPublicIpAddress -ResourceGroupName $customerRg -Location $customerRegion -Name $publicIpName -AllocationMethod Dynamic
    
    # Create NIC
    $nicName = "$customerVm-NIC"
    $nic = New-AzNetworkInterface -ResourceGroupName $customerRg -Location $customerRegion -Name $nicName -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id -NetworkSecurityGroupId $nsg.Id
    
    # Create VM Configuration
    $vmConfig = New-AzVMConfig -VMName $customerVm -VMSize $vmSize
    
    # Set OS Configuration
    $vmConfig = Set-AzVMOperatingSystem -VM $vmConfig -Windows -ComputerName $customerVm -Credential (New-Object System.Management.Automation.PSCredential ($adminUsername, $adminPassword)) -ProvisionVMAgent -EnableAutoUpdate
    
    # Set Source Image
    $vmConfig = Set-AzVMSourceImage -VM $vmConfig -PublisherName $publisher -Offer $offer -Skus $sku -Version $version
    
    # Add NIC
    $vmConfig = Add-AzVMNetworkInterface -VM $vmConfig -Id $nic.Id
    
    # Configure OS Disk
    $osDiskName = "$customerVm-OSDisk"
    $vmConfig = Set-AzVMOSDisk -VM $vmConfig -Name $osDiskName -CreateOption FromImage -StorageAccountType Standard_LRS
    
    # Create VM
    New-AzVM -ResourceGroupName $customerRg -Location $customerRegion -VM $vmConfig
    
    # Add 1GB Data Disk
    $dataDiskName = "$customerVm-DataDisk"
    $vm = Get-AzVM -ResourceGroupName $customerRg -Name $customerVm
    Add-AzVMDataDisk -VM $vm -Name $dataDiskName -DiskSizeInGB 1 -Lun 0 -CreateOption Empty -StorageAccountType Standard_LRS
    Update-AzVM -ResourceGroupName $customerRg -VM $vm
    
    # Assign role to Entra group
    $vmId = (Get-AzVM -ResourceGroupName $customerRg -Name $customerVm).Id
    New-AzRoleAssignment -ObjectId $customerGroupId -RoleDefinitionName "Virtual Machine Administrator Login" -Scope $vmId
    
    Write-Host "Customer Success VM1 created successfully!" -ForegroundColor Green
}
else {
    Write-Host "Customer Success VM1 already exists. Skipping." -ForegroundColor Yellow
}

Write-Host "Script completed!" -ForegroundColor Green