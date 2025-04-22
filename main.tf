terraform {
  required_providers {
    proxmox = {
      source = "telmate/proxmox"
      version = "2.9.14"
    }
  }
}

provider "proxmox" {
pm_tls_insecure = true
pm_api_url = ""
pm_api_token_id = "" # 
pm_api_token_secret = "" 
}


resource "proxmox_vm_qemu" "test_vm" {
  name = "terraform-test-vm"
  target_node = ""
  
  # VM General Settings
  desc = "Esther VM created by Terraform"
  cores = 2
  sockets = 1
  memory = 2048
  
  # Use one of the template VMs if possible
  # Let's try using the Ubuntu template VM with ID 105 from your screenshot
  clone = "105"
  
  # VM Network Settings
  network {
    bridge = "vmbr0"
    model = "virtio"
  }
 
  
  # Set to true to enable automatic startup
  onboot = true
}