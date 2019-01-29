# Configure the OpenStack Provider
# This example relies on OpenStack environment variables
# If you wish to set these credentials manualy please consult
# https://www.terraform.io/docs/providers/openstack/index.html
provider "openstack" {
}

# Create a Router
resource "openstack_networking_router_v2" "router_1" {
    name = "border-router"
    external_network_id = "f10ad6de-a26d-4c29-8c64-2a7418d47f8f"
}

# Create a Network
resource "openstack_networking_network_v2" "network_1" {
    name = "private-net"
    admin_state_up = "true"
}

# Create a Subnet
resource "openstack_networking_subnet_v2" "subnet_1" {
    name = "private-subnet"
    network_id = "${openstack_networking_network_v2.network_1.id}"
    allocation_pools {
        start = "10.0.0.10"
        end = "10.0.00.200"
    }
    enable_dhcp = "true"
    cidr = "10.0.0.0/24"
    ip_version = 4
}

# Create a Router interface
resource "openstack_networking_router_interface_v2" "router_interface_1" {
    router_id = "${openstack_networking_router_v2.router_1.id}"
    subnet_id = "${openstack_networking_subnet_v2.subnet_1.id}"
}

# Create a Security Group
resource "openstack_compute_secgroup_v2" "secgroup_1" {
    name = "first-instance-sg"
    description = "Network access for our first instance."
    rule {
        from_port = 22
        to_port = 22
        ip_protocol = "tcp"
        cidr = "0.0.0.0/0"
    }
}

# Upload SSH public key
# replace public_key with a valid SSH public key that you wish to use
resource "openstack_compute_keypair_v2" "keypair_1" {
  name = "first-instance-keypair"
  public_key = "ssh-rsa AAAA"
}

# Create an NVMe volume from Ubuntu18.04 image
resource "openstack_blockstorage_volume_v2" "testvol" {
  name = "testvol"
  image_id = "295b1076-b5ee-4d7b-9a51-e9118069365c"
  volume_type = "b1.sr-r3-nvme-1000"
  size = 11
}


## Create a server
resource "openstack_compute_instance_v2" "instance_1" {
    name = "first-instance"
    image_id = "295b1076-b5ee-4d7b-9a51-e9118069365c"
    flavor_id = "99fb31cc-fdad-4636-b12b-b1e23e84fb25"
    block_device {
        uuid = "${openstack_blockstorage_volume_v2.testvol.id}"
        source_type = "volume"
        boot_index = 0
        volume_size = "${openstack_blockstorage_volume_v2.testvol.size}"
        destination_type = "volume"
        delete_on_termination = false
    }
    metadata {
        group = "first-instance-group"
    }
    network {
        name = "${openstack_networking_network_v2.network_1.name}"
    }
    key_pair = "${openstack_compute_keypair_v2.keypair_1.name}"
    security_groups = ["${openstack_compute_secgroup_v2.secgroup_1.name}","default"]
}

# Request a floating IP
resource "openstack_networking_floatingip_v2" "fip_1" {
    pool = "public-net"
}

# Associate floating IP
resource "openstack_compute_floatingip_associate_v2" "fip_1" {
  floating_ip = "${openstack_networking_floatingip_v2.fip_1.address}"
  instance_id = "${openstack_compute_instance_v2.instance_1.id}"
}
