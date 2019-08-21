##
## lab/azure - A Lab Environment on azure
##

variable "azure_client_id" {} # Your Access Key ID                       (required)
variable "azure_client_secret" {} # Your Secret Access Key                   (required)
variable "azure_tenant_id" {} # Tenant ID
variable "azure_subscription_id" {} # Azure Subscription ID
variable "azure_network_name"   {} # Name of your NETWORK                         (required)
variable "azure_resource_group_name"   {} # Name of your resource group                         (required)
variable "azure_public_key"   {} # Location of the public Keypair file (required)
variable "azure_private_key_file" {} # Location of the private Keypair file
variable "azure_region"     {} # AZURE Region                               (required)

variable "network"        { default = "10.4" }      # First 2 octets of your /16

###############################################################

provider "azurerm" {

  client_id = "${var.azure_client_id}"
  client_secret = "${var.azure_client_secret}"
  tenant_id = "${var.azure_tenant_id}"
  subscription_id = "${var.azure_subscription_id}"

}

resource "azurerm_resource_group" "lab" {
  name = "${var.azure_resource_group_name}"
  location      = "${var.azure_region}"
}

resource "azurerm_virtual_network" "lab" {
  name          = "${var.azure_network_name}"
  address_space = ["${var.network}.0.0/16"]
  resource_group_name = "${azurerm_resource_group.lab.name}"
  location = "${azurerm_resource_group.lab.location}"
}

output "cc.net"    { value = "${var.network}" }
output "cc.dns"    { value = "${var.network}.0.2" }
output "cc.region" { value = "${var.azure_region}" }

###############################################################

 ######  ##     ## ########  ##    ## ######## ########  ######
##    ## ##     ## ##     ## ###   ## ##          ##    ##    ##
##       ##     ## ##     ## ####  ## ##          ##    ##
 ######  ##     ## ########  ## ## ## ######      ##     ######
      ## ##     ## ##     ## ##  #### ##          ##          ##
##    ## ##     ## ##     ## ##   ### ##          ##    ##    ##
 ######   #######  ########  ##    ## ########    ##     ######

###############################################################
# DMZ
resource "azurerm_subnet" "dmz" {
  name                  = "${azurerm_virtual_network.lab.name}-dmz"
  virtual_network_name  = "${azurerm_virtual_network.lab.name}"
  resource_group_name  = "${azurerm_resource_group.lab.name}"
  address_prefix        = "${var.network}.255.192/26"
}

###############################################################
# LAB
resource "azurerm_subnet" "lab" {
  name                  = "${azurerm_virtual_network.lab.name}-lab"	
  virtual_network_name  = "${azurerm_virtual_network.lab.name}"
  resource_group_name  = "${azurerm_resource_group.lab.name}"
  address_prefix        = "${var.network}.0.0/20"
}

output "azure.network.lab.prefix" { value = "${var.network}.0" }
output "azure.network.lab.cidr"   { value = "${var.network}.0.0/24" }
output "azure.network.lab.gw"     { value = "${var.network}.0.1" }
output "azure.network.lab.subnet" { value = "${azurerm_subnet.lab.id}" }



 ######  ########  ######          ######   ########   #######  ##     ## ########   ######
##    ## ##       ##    ##        ##    ##  ##     ## ##     ## ##     ## ##     ## ##    ##
##       ##       ##              ##        ##     ## ##     ## ##     ## ##     ## ##
 ######  ######   ##              ##   #### ########  ##     ## ##     ## ########   ######
      ## ##       ##              ##    ##  ##   ##   ##     ## ##     ## ##              ##
##    ## ##       ##    ## ###    ##    ##  ##    ##  ##     ## ##     ## ##        ##    ##
 ######  ########  ######  ###     ######   ##     ##  #######   #######  ##         ######

resource "azurerm_network_security_group" "open-lab" {
  name        = "open-lab"
  resource_group_name = "${azurerm_resource_group.lab.name}"
  location = "${azurerm_resource_group.lab.location}"
}

resource "azurerm_network_security_rule" "open-lab-ingress" {
  name                        = "open-lab-ingress"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.lab.name}"
  network_security_group_name = "${azurerm_network_security_group.open-lab.name}"
}

resource "azurerm_network_security_rule" "open-lab-egress" {
  name                        = "open-lab-egress"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = "${azurerm_resource_group.lab.name}"
  network_security_group_name = "${azurerm_network_security_group.open-lab.name}"
}



########     ###     ######  ######## ####  #######  ##    ##
##     ##   ## ##   ##    ##    ##     ##  ##     ## ###   ##
##     ##  ##   ##  ##          ##     ##  ##     ## ####  ##
########  ##     ##  ######     ##     ##  ##     ## ## ## ##
##     ## #########       ##    ##     ##  ##     ## ##  ####
##     ## ##     ## ##    ##    ##     ##  ##     ## ##   ###
########  ##     ##  ######     ##    ####  #######  ##    ##

resource "azurerm_public_ip" "bastion" {
  name                = "bastion-public-ip"
  location            = "${var.azure_region}"
  resource_group_name = "${azurerm_resource_group.lab.name}"
  allocation_method   = "Dynamic"
}

resource "azurerm_network_interface" "bastion" {
  name                = "bastion-nic"
  location            = "${azurerm_resource_group.lab.location}"
  resource_group_name = "${azurerm_resource_group.lab.name}"

  ip_configuration {
    name                          = "bastion-private-ip"
    subnet_id                     = "${azurerm_subnet.dmz.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = "${azurerm_public_ip.bastion.id}"
  }

}

resource "azurerm_virtual_machine" "bastion" {

  name                  = "bastion"
  location              = "${azurerm_resource_group.lab.location}"
  resource_group_name   = "${azurerm_resource_group.lab.name}"
  network_interface_ids = ["${azurerm_network_interface.bastion.id}"]
  vm_size               = "Standard_DS1_v2"

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "bastion-disk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {

    admin_username = "ubuntu"
    computer_name  = "bastion"
  }

  os_profile_linux_config {

    disable_password_authentication = true
    ssh_keys {
      path = "/home/ubuntu/.ssh/authorized_keys"
      key_data = "${var.azure_public_key}"
    }
  }
  
  provisioner "remote-exec" {
    inline = [
      "sudo curl -o /usr/local/bin/jumpbox https://raw.githubusercontent.com/starkandwayne/jumpbox/master/bin/jumpbox",
      "sudo chmod 0755 /usr/local/bin/jumpbox",
      "sudo jumpbox system"
    ]
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.azure_private_key_file}")}"
    }
  }
  provisioner "file" {
    source      = "files/gitconfig"
    destination = "/home/ubuntu/.gitconfig"
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.azure_private_key_file}")}"
    }
  }
  provisioner "file" {
    source      = "files/tmux.conf"
    destination = "/home/ubuntu/.tmux.conf"
    connection {
        type = "ssh"
        user = "ubuntu"
        private_key = "${file("${var.azure_private_key_file}")}"
    }
  }
}

data "azurerm_public_ip" "bastion" {
  name                = "${azurerm_public_ip.bastion.name}"
  resource_group_name = "${var.azure_resource_group_name}"
}

output "box.bastion.public" {
  value = "${data.azurerm_public_ip.bastion.ip_address}"
}
output "box.bastion.keyfile" {
  value = "${var.azure_private_key_file}"
}
ls
