# Example VPC to support Rolling Deployment

This Terraform example for IBM Cloud Schematics illustrates how to deploy an IBM Cloud Gen2 VPC infrastructure to support Rolling Deployments of applications to set of Virtual Machines (VSI) running within the VPC. In addition, the template also creates a bastion host to provide secure remote SSH access to the Virtual Machines within VPC. The example and Terraform modules are supplied 'as is' and only seek to implement a 'reasonable' set of best practices for rolling deployment configuration. Your own organisation may have additional requirements that may need be implemented before it can be used.

## Rolling Deployment

The Rolling Deployment Strategy deploys newer version of the application to a subset of the production environment while keeping the remaining environment available for the live traffic. For the sake of simplicity, assuming batch-size of 1, the rolling strategy deploys newer version of the application to 1 instance at a time. The instance is first removed/drained of the production traffic. The deployment is carried out by copying the new artifact to the instance and restarting the application. Once the deployment finishes, the acceptance tests are carried out on the instance. If successful, the instance is attached back to the backend pool of servers. The same process is carried out to all the instances of the backend pool.

The Rolling Strategy helps to keep the application available while new code is being deployed to the production environment. The downside of the approach is that two versions of the same application is visible to the user.
## VPC to support Rolling Deployment



The figure here illustrates the configuration of the VPC configuration deployed by this example.

![Rolling Deployment with Single Zone Deployment](./images/Deployment_Strategies-Rolling-SZ.jpg)

The example deploys a single tier application environment, with a public facing load balancer. This Single Zone Deployment configuration creates the application in a single-zone. This single zone application tier contains 2 VSI which can be be configured as per requirement.

Public gateway is configured to provide internet access to the virtual machines to download os-patches or third party packages required by application.

This example was written for use with IBM Cloud Schematics, therefore the provider block does not include an API Key. To run standalone with Terraform, modify the example to input your IBM Cloud API key as an input variable.

![Rolling Deployment with Multi Zone Deployment](./images/Deployment_Strategies-Rolling-MZ.jpg)

The example deploys a single tier application environment, with a public facing load balancer. This Multiple Zone Deployment configuration creates the application tier in multiple zones. By default, the template creates 2 availability zone within the region. Each region contains 1 VSI which can be configured as per requirement.

Public gateway is configured to provide internet access to the virtual machines to download os-patches or third party packages required by application.

This example was written for use with IBM Cloud Schematics, therefore the provider block does not include an API Key. To run standalone with Terraform, modify the example to input your IBM Cloud API key as an input variable.

### SSH access restrictions
A layered approach to SSH access is applied in this example. SSH access to app VSI's is restricted to connection from the bastion host only. All other SSH access from the public or private networks to the app VSIs is denied.

VPC Security Group and network ACL rules are applied to:
- Allow only inbound SSH access to the app VSIs from the bastion host
- Allow only inbound HTTP access on port 8080 from the public load-balancer to the VSIs
- Outbound access for VSIs is enabled to perform software installation or os-patches
- All other inbound and outbound traffic to the bastion host and app VSIs is denied by both ACLs and Security groups

To mitigate the security risks of SSH connections over the public network to the bastion hosts and VSIs, the network Access Control List (ACL) rules and security groups are configured to allow SSH access to the bastion host.

### Bastion host SSH configuration
The example and Terraform modules are supplied 'as is' and only seek to implement a 'reasonable' set of best practices for bastion host configuration.

The following configuration is applied to the bastion host. The default SSH config is further locked down.

```
  - yum --security update
  - sed -i "s/#MaxSessions 10/MaxSessions 50/" /etc/ssh/sshd_config
  - sed -i "s/X11Forwarding yes/X11Forwarding no/" /etc/ssh/sshd_config
  - sed -i "s/PermitRootLogin yes/PermitRootLogin prohibit-password/" /etc/ssh/sshd_config
  - echo "MaxStartups 50:30:80"  >> /etc/ssh/sshd_config
  - echo 'PasswordAuthentication no' >> /etc/ssh/sshd_config
  - echo 'UsePAM yes' >> /etc/ssh/sshd_config
  - echo 'AuthenticationMethods publickey' >> /etc/ssh/sshd_config
  - service sshd restart
```

## Deployed resources

**Single Zone Configuration**
The following resources are deployed by this template and may incur charges.

- 1 x Floating IP address
- 1 x Public Gateway
- 1 x Load Balancer
- 3 x VSIs
- 1 x VPC
- Access Control Lists
- Security Groups

**Multiple Zone Configuration**
The following resources are deployed by this template and may incur charges.

- 1 x Floating IP address
- 2 x Public Gateway
- 1 x Load Balancer
- 3 x VSIs
- 2 x VPC
- Access Control Lists
- Security Groups

## Requirements


|  **Name**                  | **Version** |
|  --------------------------| -------------|
|  terraform                 | ~> 1.0.5 |
|  terraform_provider_ibm    | ~> 1.30.2 |


## Inputs

| **name**            | **description**                                                   | **type**     | **required**   | **default**          | **sensitive** |
| ------------------- | ----------------------------------------------------------------- | ------------ | ---------------| ---------------------| ----------- |
| ibm_region          | Region of deployed VPC                                            | string       |                | "us-south"           |   |
| vpc_name            | Unique VPC name                                                   | string       |                | "ssh-bastion-host"   |   |
| resource_group_name | Name of IBM Cloud Resource Group used for all VPC resources       | string       |                | "Default"            |   |
| bastion_cidr        | CIDR range for the subnet containing bastion VSI                  | string       |                | "172.22.192.0/20"    |   |
| rolling_cidr        | CIDR range for the subnet containing application VSI's            | list(string) |                | "172.16.0.0/20"      |   |
| vsi_profile         | Profile for VSIs deployed in blue and green                       | string       |                | "cx2-2x4"            |   |
| image_name          | OS image for VSI deployments. Only tested with Centos             | string       |                | "ibm-centos-8-3-minimal-amd64-3" |  |
| ssh_key_name        | Name given to public SSH key uploaded to IBM Cloud for VSI access | string       |  ✓             |                      |   |
| ssh_private_key     | Optional private key from key pair. Only required if it desired to validate remote SSH access to the bastion host and VSIs. | string  | | |  ✓   |

## Outputs

|  **name**      |    **description**  |
|  --------------------------------------- | ------------------------------------------- |
|  bastion_ip_addresses                    |  Public IP address of the bastion host      |
|  rolling_server_host_ip_addresses        |  List of private IP addresses of the subnet containing VSI's|

## Instructions

1.  Make sure that you have the [required IBM Cloud IAM permissions](https://cloud.ibm.com/docs/vpc?topic=vpc-managing-user-permissions-for-vpc-resources) to create and work with VPC infrastructure and you are [assigned the correct permissions](https://cloud.ibm.com/docs/schematics?topic=schematics-access) to create the workspace and deploy resources.
2.  [Generate an SSH key](https://cloud.ibm.com/docs/vpc?topic=vpc-ssh-keys). The SSH key is required to access the provisioned VPC virtual server instances via the bastion host. After you have created your SSH key, make sure to [upload this SSH key to your IBM Cloud account](https://cloud.ibm.com/docs/vpc-on-classic-vsi?topic=vpc-on-classic-vsi-managing-ssh-keys#managing-ssh-keys-with-ibm-cloud-console) in the VPC region and resource group where you want to deploy this example
3.  Create the Schematics workspace:
    1.  From the IBM Cloud menu select [Schematics](https://cloud.ibm.com/schematics/overview).
        - Click Create a workspace.
        - Enter a name for your workspace.
        - Click Create to create your workspace.
    2.  On the workspace **Settings** page, enter the URL of this example in the Schematics examples GitHub repository.
        - Select the Terraform version: Terraform 0.12.
        - Click **Save template information**.
        - In the **Input variables** section, review the default input variables and provide alternatives if desired. The only mandatory parameter is the name given to the SSH key that you uploaded to your IBM Cloud account.
        - Click **Save changes**.
4.  From the workspace **Settings** page, click **Generate plan** 
5.  Click **View log** to review the log files of your Terraform execution plan.
6.  Apply your Terraform template by clicking **Apply plan**.
7.  Review the log file to ensure that no errors occurred during the provisioning, modification, or deletion process.

The output of the Schematics Apply Plan will list the public IP address of the bastion host and the rolling servers.

```
Outputs:

rolling_server_host_ip_addresses = [
  [
    "172.16.0.5",
    "172.16.2.5",
  ],
]
bastion_host_ip_address = [
  "52.116.132.26",
]

app_dns_hostname = 2989c099-us-south.lb.appdomain.cloud
```

## Validating the VPC security configuration

To validate that access to VSI's in the application tier, the following SSH command can be used from a local workstation. Copy and paste the command into a terminal session, inserting the returned values for the bastion IP and one of the private IP address from `rolling_server_host_ip_addresses` and the path to the file containing the private SSH key.

```
ssh -i ~/.ssh/<key> -o ProxyCommand="ssh -i ~/.ssh/<ansible> -W %h:%p root@52.116.132.26" root@172.16.0.5
```
