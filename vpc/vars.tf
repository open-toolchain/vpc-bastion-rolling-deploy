##############################################################################
# VPC Variables
##############################################################################

variable "ibm_region" {
  description = "IBM Cloud region where all resources will be deployed"
}

variable "resource_group_name" {
  description = "ID for IBM Cloud Resource Group"
}

variable "az_list" {
  description = "IBM Cloud availability zones"
}

variable "generation" {
  description = "VPC generation"
  default     = 2
}

# unique vpc name
variable "unique_id" {
  description = "The vpc unique id"
}


variable "rolling_count" {
  description = "number of rolling pool zones"
  default     = 1
}

##############################################################################
# Network variables
##############################################################################

variable "rolling_cidr_blocks" {
}
##############################################################################



