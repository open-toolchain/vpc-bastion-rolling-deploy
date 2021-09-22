##############################################################################
# Account Variables
##############################################################################

# target region
variable "ibm_region" {
  description = "IBM Cloud region where all resources will be deployed"
  # default     = "us-east"
  default = "us-south"
  # default     = "eu-gb"
}

variable "az_list" {
  description = "IBM Cloud availability zones"
  default     = "us-south-2,us-south-3"
}

# variable "ibmcloud_api_key" {
#   description = "IBM Cloud API key when run standalone"
# }



variable "resource_group_name" {
  description = "Name of IBM Cloud Resource Group used for all VPC resources"
  default     = "Default"
}

# #Only tested with Gen2. Gen1 requires changes to images, profile names and some VPC resources
# variable "generation" {
#   description = "VPC generation. Only tested with VPC Gen2"
#   default     = 2
# }

# unique name for the VPC in the account
variable "vpc_name" {
  description = "Name of vpc"
  default     = "vsi-deployment"
}

##############################################################################

##############################################################################
# Network variables
##############################################################################

locals {
  pub_repo_egress_cidr = "0.0.0.0/0" # cidr range required to contact public software repositories
}

# Predefine subnets for all app tiers for use with `ibm_is_address_prefix`. Single tier CIDR used for NACLs
# Each app tier uses:
# rolling_cidr_blocks = [cidrsubnet(var.rolling_cidr, 4, 0), cidrsubnet(var.rolling_cidr, 4, 2), cidrsubnet(var.rolling_cidr, 4, 4)]
# to create individual zone subnets for use with `ibm_is_address_prefix`
variable "bastion_cidr" {
  description = "Complete CIDR range across all three zones for bastion host subnets"
  default     = "172.22.192.0/20"
}

variable "rolling_cidr" {
  description = "Complete CIDR range across all three zones for rolling subnets"
  default     = "172.16.0.0/20"
}

variable "instnace_count" {
  description = "Count of the VSI instnace in the backend pool. Please create one extra instance for high availability."
  default     = 2
}
##############################################################################

# VSI profile
variable "profile" {
  description = "Profile for VSIs deployed in rolling"
  default     = "cx2-2x4"
}

# image names can be determined with the cli command `ibmcloud is images`
variable "image_name" {
  description = "OS image for VSI deployments. Only tested with Centos"
  default     = "ibm-centos-8-3-minimal-amd64-3"
}

data "ibm_is_image" "os" {
  name = var.image_name
}


##############################################################################
# Access check variables
##############################################################################

variable "ssh_private_key" {
  description = "SSH private key of SSH key pair used for VSIs and Bastion"
}

data "ibm_is_ssh_key" "sshkey" {
  name = var.ssh_key_name
}

variable "ssh_key_name" {
  description = "Name giving to public SSH key uploaded to IBM Cloud for VSI access"
}

