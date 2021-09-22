##############################################################################
# This file creates the VPC, Zones, subnets, acls and public gateway for the
# example VPC. It is not intended to be a full working application
# environment.
#
# Separately setup up any required load balancers, listeners, pools and members
##############################################################################

##############################################################################
# Create a VPC
##############################################################################
data "ibm_resource_group" "all_rg" {
  name = var.resource_group_name
}

resource "ibm_is_vpc" "vpc" {
  name                      = var.unique_id
  resource_group            = data.ibm_resource_group.all_rg.id
  address_prefix_management = "manual"
}

##############################################################################

##############################################################################
# Prefixes and subnets for zone 1
##############################################################################



resource "ibm_is_vpc_address_prefix" "rolling_subnet_prefix" {
  count = length(tolist(split(",", var.az_list)))
  name  = "${var.unique_id}-rolling-prefix-zone-${count.index + 1}"
  zone  = trimspace(element(split(",", var.az_list), count.index))
  vpc   = ibm_is_vpc.vpc.id
  cidr  = var.rolling_cidr_blocks[count.index]

}

##############################################################################

##############################################################################
# Create Subnets
##############################################################################




# Increase count to create subnets in all zones
resource "ibm_is_subnet" "rolling_subnet" {
  count           = length(tolist(split(",", var.az_list)))
  name            = "${var.unique_id}-rolling-subnet-${count.index + 1}"
  vpc             = ibm_is_vpc.vpc.id
  zone            = trimspace(element(split(",", var.az_list), count.index))
  ipv4_cidr_block = var.rolling_cidr_blocks[count.index]
  #network_acl     = "${ibm_is_network_acl.multizone_acl.id}"
  public_gateway = ibm_is_public_gateway.repo_gateway[count.index].id
  depends_on     = [ibm_is_vpc_address_prefix.rolling_subnet_prefix]
}

resource "ibm_is_public_gateway" "repo_gateway" {
  count = length(tolist(split(",", var.az_list)))
  name  = "${var.unique_id}-public-gtw-${count.index}"
  vpc   = ibm_is_vpc.vpc.id
  zone  = trimspace(element(split(",", var.az_list), count.index))
  //User can configure timeouts
  timeouts {
    create = "90m"
  }
}