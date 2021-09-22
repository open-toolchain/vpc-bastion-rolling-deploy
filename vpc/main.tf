
# provider block required with Schematics to set VPC region
provider "ibm" {
  region = var.ibm_region
  #generation = local.generation
  #version    = "~> 1.30.2"
}

