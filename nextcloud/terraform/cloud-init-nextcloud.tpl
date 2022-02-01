#cloud-config
package_update: true
package_upgrade: true
package_reboot_if_required: true
packages:
  - docker-ce
  - docker-ce-cli
  - containerd.io
runcmd:
  - curl -fsSL ${ ddns_script_url } > ddns-script.sh
  - chmod +x ddns-script.sh
  - curl -fsSL ${ setup_script_url } > setup-script.sh
  - chmod +x setup-script.sh
  - ./setup-script.sh ${ host_name } ${ domain_name } ${ ddns_password } ${ ip_address } ${ file_upload_size }
  - touch /deploy-complete
apt:
  sources:
    docker:
      source: deb https://download.docker.com/linux/ubuntu $RELEASE stable
      keyid: 9dc858229fc7dd38854ae2d88d81803c0ebfcd88
