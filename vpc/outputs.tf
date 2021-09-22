output "vpc_id" {
  value = ibm_is_vpc.vpc.id
}

output "rolling_subnet_ids" {
  value = ibm_is_subnet.rolling_subnet.*.id
}
