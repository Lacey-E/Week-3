

# # Set subscription


# Variables for Windows Server Core
ADMIN_USERNAME="azureadmin"
ADMIN_PASSWORD=""
VM_SIZE="Standard_B1ms"
PUBLISHER="MicrosoftWindowsServer"
OFFER="WindowsServer"
SKU="2022-datacenter-core-g2"
VERSION="latest"

# Team Group IDs
SALES_GROUP_ID=
ENGINEERING_GROUP_ID=
CUSTOMER_GROUP_ID=

# Create 1 more Engineering VM (assuming the first one exists)
create_engineering_vm() {
    echo "Creating additional Engineering VM..."
    TEAM_NAME="Engineering"
    REGION="eastus"
    RG_NAME="${TEAM_NAME}-RG"
    VM_NAME="${TEAM_NAME}-VM2"
    
    # Check if resource group exists, if not create it
    if ! az group show --name $RG_NAME &> /dev/null; then
        az group create --name $RG_NAME --location $REGION
    fi
    
    # Check if vnet exists, if not create it
    if ! az network vnet show --resource-group $RG_NAME --name "${TEAM_NAME}-VNet" &> /dev/null; then
        az network vnet create --resource-group $RG_NAME --name "${TEAM_NAME}-VNet" --address-prefix 10.0.0.0/16 --subnet-name "${TEAM_NAME}-Subnet" --subnet-prefix 10.0.0.0/24
    fi
    
    # Check if NSG exists, if not create it
    if ! az network nsg show --resource-group $RG_NAME --name "${TEAM_NAME}-NSG" &> /dev/null; then
        az network nsg create --resource-group $RG_NAME --name "${TEAM_NAME}-NSG"
        az network nsg rule create --resource-group $RG_NAME --nsg-name "${TEAM_NAME}-NSG" --name "AllowRDP" --protocol tcp --priority 100 --destination-port-range 3389 --access allow
    fi
    
    # Create public IP
    az network public-ip create --resource-group $RG_NAME --name "${VM_NAME}-PublicIP"
    
    # Create NIC
    az network nic create \
        --resource-group $RG_NAME \
        --name "${VM_NAME}-NIC" \
        --vnet-name "${TEAM_NAME}-VNet" \
        --subnet "${TEAM_NAME}-Subnet" \
        --public-ip-address "${VM_NAME}-PublicIP" \
        --network-security-group "${TEAM_NAME}-NSG"
    
    # Create VM
    az vm create \
        --resource-group $RG_NAME \
        --name $VM_NAME \
        --size $VM_SIZE \
        --image "$PUBLISHER:$OFFER:$SKU:$VERSION" \
        --admin-username $ADMIN_USERNAME \
        --admin-password $ADMIN_PASSWORD \
        --nics "${VM_NAME}-NIC" \
        --os-disk-name "${VM_NAME}-OSDisk"
    
    # Add 1GB data disk
    az vm disk attach \
        --resource-group $RG_NAME \
        --vm-name $VM_NAME \
        --name "${VM_NAME}-DataDisk" \
        --size-gb 1 \
        --new
    
    # Assign role to Entra group
    VM_ID=$(az vm show --resource-group $RG_NAME --name $VM_NAME --query id -o tsv)
    az role assignment create --assignee-object-id $ENGINEERING_GROUP_ID --role "Virtual Machine Administrator Login" --scope $VM_ID
    
    echo "Engineering VM created successfully!"
}

# Create 2 Sales & Marketing VMs
create_sales_vms() {
    echo "Creating Sales & Marketing VMs..."
    TEAM_NAME="SalesMarketing"
    REGION="westus"
    RG_NAME="${TEAM_NAME}-RG"
    
    # Create Resource Group
    az group create --name $RG_NAME --location $REGION
    
    # Create virtual network and subnet
    az network vnet create --resource-group $RG_NAME --name "${TEAM_NAME}-VNet" --address-prefix 10.0.0.0/16 --subnet-name "${TEAM_NAME}-Subnet" --subnet-prefix 10.0.0.0/24
    
    # Create NSG with RDP rule
    az network nsg create --resource-group $RG_NAME --name "${TEAM_NAME}-NSG"
    az network nsg rule create --resource-group $RG_NAME --nsg-name "${TEAM_NAME}-NSG" --name "AllowRDP" --protocol tcp --priority 100 --destination-port-range 3389 --access allow
    
    # Create 2 VMs
    for i in 1 2
    do
        VM_NAME="${TEAM_NAME}-VM$i"
        
        # Create public IP
        az network public-ip create --resource-group $RG_NAME --name "${VM_NAME}-PublicIP"
        
        # Create NIC
        az network nic create \
            --resource-group $RG_NAME \
            --name "${VM_NAME}-NIC" \
            --vnet-name "${TEAM_NAME}-VNet" \
            --subnet "${TEAM_NAME}-Subnet" \
            --public-ip-address "${VM_NAME}-PublicIP" \
            --network-security-group "${TEAM_NAME}-NSG"
        
        # Create VM
        az vm create \
            --resource-group $RG_NAME \
            --name $VM_NAME \
            --size $VM_SIZE \
            --image "$PUBLISHER:$OFFER:$SKU:$VERSION" \
            --admin-username $ADMIN_USERNAME \
            --admin-password $ADMIN_PASSWORD \
            --nics "${VM_NAME}-NIC" \
            --os-disk-name "${VM_NAME}-OSDisk"
        
        # Add 1GB data disk
        az vm disk attach \
            --resource-group $RG_NAME \
            --vm-name $VM_NAME \
            --name "${VM_NAME}-DataDisk" \
            --size-gb 1 \
            --new
        
        # Assign role to Entra group
        VM_ID=$(az vm show --resource-group $RG_NAME --name $VM_NAME --query id -o tsv)
        az role assignment create --assignee-object-id $SALES_GROUP_ID --role "Virtual Machine Administrator Login" --scope $VM_ID
    done
    
    echo "Sales & Marketing VMs created successfully!"
}

# Create 1 Customer Success VM
create_customer_vm() {
    echo "Creating Customer Success VM..."
    TEAM_NAME="CustomerSuccess"
    REGION="centralus"
    RG_NAME="${TEAM_NAME}-RG"
    VM_NAME="${TEAM_NAME}-VM1"
    
    # Check if resource group exists, if not create it
    if ! az group show --name $RG_NAME &> /dev/null; then
        az group create --name $RG_NAME --location $REGION
    fi
    
    # Check if vnet exists, if not create it
    if ! az network vnet show --resource-group $RG_NAME --name "${TEAM_NAME}-VNet" &> /dev/null; then
        az network vnet create --resource-group $RG_NAME --name "${TEAM_NAME}-VNet" --address-prefix 10.0.0.0/16 --subnet-name "${TEAM_NAME}-Subnet" --subnet-prefix 10.0.0.0/24
    fi
    
    # Check if NSG exists, if not create it
    if ! az network nsg show --resource-group $RG_NAME --name "${TEAM_NAME}-NSG" &> /dev/null; then
        az network nsg create --resource-group $RG_NAME --name "${TEAM_NAME}-NSG"
        az network nsg rule create --resource-group $RG_NAME --nsg-name "${TEAM_NAME}-NSG" --name "AllowRDP" --protocol tcp --priority 100 --destination-port-range 3389 --access allow
    fi
    
    # Create public IP
    az network public-ip create --resource-group $RG_NAME --name "${VM_NAME}-PublicIP"
    
    # Create NIC
    az network nic create \
        --resource-group $RG_NAME \
        --name "${VM_NAME}-NIC" \
        --vnet-name "${TEAM_NAME}-VNet" \
        --subnet "${TEAM_NAME}-Subnet" \
        --public-ip-address "${VM_NAME}-PublicIP" \
        --network-security-group "${TEAM_NAME}-NSG"
    
    # Create VM
    az vm create \
        --resource-group $RG_NAME \
        --name $VM_NAME \
        --size $VM_SIZE \
        --image "$PUBLISHER:$OFFER:$SKU:$VERSION" \
        --admin-username $ADMIN_USERNAME \
        --admin-password $ADMIN_PASSWORD \
        --nics "${VM_NAME}-NIC" \
        --os-disk-name "${VM_NAME}-OSDisk"
    
    # Add 1GB data disk
    az vm disk attach \
        --resource-group $RG_NAME \
        --vm-name $VM_NAME \
        --name "${VM_NAME}-DataDisk" \
        --size-gb 1 \
        --new
    
    # Assign role to Entra group
    VM_ID=$(az vm show --resource-group $RG_NAME --name $VM_NAME --query id -o tsv)
    az role assignment create --assignee-object-id $CUSTOMER_GROUP_ID --role "Virtual Machine Administrator Login" --scope $VM_ID
    
    echo "Customer Success VM created successfully!"
}

# Run the functions to create the VMs
create_engineering_vm
create_sales_vms
create_customer_vm

echo "All VMs have been created successfully!"