# Configure the OpenStack Provider
# This example relies on OpenStack environment variables
# If you wish to set these credentials manualy please consult
# https://www.terraform.io/docs/providers/openstack/index.html
provider "openstack" {
}

# Create a Router
resource "openstack_networking_router_v2" "router_1" {
    name = "border-router"
    external_gateway = "849ab1e9-7ac5-4618-8801-e6176fbbcf30"
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
        end = "10.0.0.200"
    }
    dns_nameservers = ["202.78.247.197","202.78.247.198","202.78.247.199"]
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
  name = "first-instance-key"
  public_key = "ssh-rsa ABC123"
}

# Request a floating IP
resource "openstack_compute_floatingip_v2" "floatingip_1" {
    pool = "public-net"
}

## Create a server
resource "openstack_compute_instance_v2" "instance_1" {
    name = "first-instance"
    image_id = "378f3322-740f-4c4d-9864-aebeb41f21ab"
    flavor_id = "28153197-6690-4485-9dbc-fc24489b0683"
    metadata {
        group = "first-instance-group"
    }
    key_pair = "${openstack_compute_keypair_v2.keypair_1.name}"
    security_groups = ["${openstack_compute_secgroup_v2.secgroup_1.name}","default"]
    network {
        floating_ip = "${openstack_compute_floatingip_v2.floatingip_1.address}"
        name = "${openstack_networking_network_v2.network_1.name}"
    }
}
