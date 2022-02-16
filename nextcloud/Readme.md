# Nextcloud

This directory contains the terraform and heat scripts for running Nextcloud.

Nextcloud is a free and open source suite of client-server software which 
manages the creation and hosting of files. It is becoming a popular alternative
to similar software such as Dropbox and Google Drive.

**It is highly recommended you start the Nextcloud container with a volume otherwise you will lose all your data should you destroy or reboot the instance**

# Heat 

To run heat and create a Nextcloud instance, **note: this will create a volume for you**

```shell
openstack stack create -t nextcloud.yaml nextcloud-stack --parameter hostname="<your-host-name>" --parameter domainname="<your-domain-name>" --parameter ddns_password="<your-ddns-password>" --parameter keyname="<your-key-name>" --parameter ddns_script_url="<your-ddns-script-url>"
```
Note: The ddns script url you use is dependent on your domain name provider. See tools/ddns for the scripts available.

# Terraform 

To run terraform and create a Nextcloud instance **with an existing volume:**

**In the terminal**

```shell
terraform init
terraform apply --var domain_name="<your-domain-name>" --var host_name="<your-host-name>" --var ddns_password="<your-ddns-password>" --var file_upload_size="<size in mega-bytes>m" --var keyname="<your-key-name>" --var volume_uuid="<volume id> --var ddns-script-url="<your-ddns-script-url>"
```

To run terraform and create a Nextcloud instance **without an existing volume:**

**In the terminal**

```shell
terraform init
terraform apply --var domain_name="<your-domain-name>" --var host_name="<your-host-name>" --var ddns_password="<your-ddns-password>" --var file_upload_size="<size in mega-bytes>m" --var keyname="<your-key-name>" --var ddns-script-url="<your-ddns-script-url>"
```

Note:
a) If you choose to use an existing volume, replace volume id with the id of your previously created volume for the
Nextcloud database. 

b) Only change the `file_upload_size` if you require more than the default (1024MB).

c) Floating IP should be generated and printed after this step, it is
recommended you take note of this as you may need it later.
