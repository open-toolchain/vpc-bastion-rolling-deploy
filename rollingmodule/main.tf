##############################################################################
# Sample module to deploy a 'rolling' webserver VSI and security group
# No NACL is defined. As no floating (public) IPs are defined # Security Group
# configuration by itself is considered sufficient to protect access to the webserver.
# Subnets are defined in the VPC module.
#
# Redhat Ansible usage is enabled by the addition of VSI tags. All Ansible related VSI
# tags are prefixed with "ans_group:" followed by the group name.   '
# tags = ["ans_group:rolling"]'
# Correct specification of tags is essential for operation of the Ansible dynamic inventory
# script used to pass host information to Ansible. The tags here should match the roles
# defined in the site.yml playbook file.
##############################################################################

provider "ibm" {
  region = var.ibm_region
  #ibmcloud_api_key = var.ibmcloud_api_key
  #generation = local.generation
  #version    = "~> 1.30.2"
}

data "template_file" "instance_userdata" {
  template = file("${path.module}/config.yaml")
  vars = {
    app_port = var.app_port
    health_port = var.health_port
  }
}

resource "ibm_is_instance" "rolling-server" {
  count   = var.rolling_count
  name    = "${var.unique_id}-rolling-vsi-${count.index + 1}"
  image   = var.ibm_is_image_id
  profile = var.profile

  primary_network_interface {
    subnet          = var.subnet_ids[index(tolist(split(",", var.az_list)), element(split(",", var.az_list), count.index))]
    security_groups = [ibm_is_security_group.rolling.id]
  }

  vpc            = var.ibm_is_vpc_id
  zone           = trimspace(element(split(",", var.az_list), count.index))
  resource_group = var.ibm_is_resource_group_id
  keys           = [var.ibm_is_ssh_key_id]
  tags           = ["schematics:group:rolling"]
  user_data      = data.template_file.instance_userdata.rendered
}


##############################################################################
# Public load balancer
#
##############################################################################
# this is the SG applied to the alb
resource "ibm_is_security_group" "alb" {
  name           = "${var.unique_id}-alb-sg"
  vpc            = var.ibm_is_vpc_id
  resource_group = var.ibm_is_resource_group_id
}


locals {
  alb_sg_keys = ["direction", "remote", "type", "port_min", "port_max"]


  alb_sg_rules = [
    ["inbound", "0.0.0.0/0", "all", 1, 65535],
    ["outbound", "0.0.0.0/0", "all", 1, 65535]
  ]

  alb_sg_mappedrules = [
    for entry in local.alb_sg_rules :
    merge(zipmap(local.alb_sg_keys, entry))
  ]
}


resource "ibm_is_security_group_rule" "alb_access" {
  count     = length(local.alb_sg_mappedrules)
  group     = ibm_is_security_group.alb.id
  direction = (local.alb_sg_mappedrules[count.index]).direction
  remote    = (local.alb_sg_mappedrules[count.index]).remote
  dynamic "tcp" {
    for_each = local.alb_sg_mappedrules[count.index].type == "tcp" ? [
      {
        port_max = local.alb_sg_mappedrules[count.index].port_max
        port_min = local.alb_sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = tcp.value.port_max
      port_min = tcp.value.port_min

    }
  }
  dynamic "udp" {
    for_each = local.alb_sg_mappedrules[count.index].type == "udp" ? [
      {
        port_max = local.alb_sg_mappedrules[count.index].port_max
        port_min = local.alb_sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = udp.value.port_max
      port_min = udp.value.port_min
    }
  }
  dynamic "icmp" {
    for_each = local.alb_sg_mappedrules[count.index].type == "icmp" ? [
      {
        type = local.alb_sg_mappedrules[count.index].port_max
        code = local.alb_sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      type = icmp.value.type
      code = icmp.value.code
    }
  }
}

resource "ibm_is_lb" "vsi-rolling-lb" {
  name            = "${var.unique_id}-alb"
  type            = "public"
  subnets         = toset(var.subnet_ids)
  security_groups = [ibm_is_security_group.alb.id]
  resource_group  = var.ibm_is_resource_group_id

  timeouts {
    create = "15m"
    delete = "15m"
  }


}


resource "ibm_is_lb_listener" "vsi-rolling-lb-listener" {
  lb           = ibm_is_lb.vsi-rolling-lb.id
  port         = var.app_port
  protocol     = "http"
  default_pool = element(split("/", ibm_is_lb_pool.vsi-rolling-lb-pool.id), 1)
  depends_on   = [ibm_is_lb_pool.vsi-rolling-lb-pool]
}

resource "ibm_is_lb_pool" "vsi-rolling-lb-pool" {
  lb                 = ibm_is_lb.vsi-rolling-lb.id
  name               = "vsi-rolling-lb-pool"
  protocol           = "http"
  algorithm          = "weighted_round_robin"
  health_delay       = "5"
  health_retries     = "2"
  health_timeout     = "2"
  health_type        = "http"
  health_monitor_url = "/"
  depends_on         = [ibm_is_lb.vsi-rolling-lb]
}

resource "ibm_is_lb_pool_member" "vsi-rolling-lb-pool-member-zone1" {
  count          = var.rolling_count
  lb             = ibm_is_lb.vsi-rolling-lb.id
  pool           = element(split("/", ibm_is_lb_pool.vsi-rolling-lb-pool.id), 1)
  port           = var.app_port
  target_address = ibm_is_instance.rolling-server[count.index].primary_network_interface[0].primary_ipv4_address
  depends_on     = [ibm_is_lb_pool.vsi-rolling-lb-pool]
}





# this is the SG applied to the rolling instances
resource "ibm_is_security_group" "rolling" {
  name           = "${var.unique_id}-rolling-sg"
  vpc            = var.ibm_is_vpc_id
  resource_group = var.ibm_is_resource_group_id
}


locals {
  sg_keys = ["direction", "remote", "type", "port_min", "port_max"]


  sg_rules = [
    ["inbound", var.bastion_remote_sg_id, "tcp", 22, 22],
    ["outbound", "0.0.0.0/0", "tcp", 443, 443],
    ["outbound", "0.0.0.0/0", "tcp", 80, 80],
    ["outbound", "0.0.0.0/0", "udp", 53, 53],
    ["inbound", "0.0.0.0/0", "tcp", var.health_port, var.health_port],
    ["inbound", "0.0.0.0/0", "tcp", var.app_port, var.app_port]
  ]

  sg_mappedrules = [
    for entry in local.sg_rules :
    merge(zipmap(local.sg_keys, entry))
  ]
}


resource "ibm_is_security_group_rule" "rolling_access" {
  count     = length(local.sg_mappedrules)
  group     = ibm_is_security_group.rolling.id
  direction = (local.sg_mappedrules[count.index]).direction
  remote    = (local.sg_mappedrules[count.index]).remote
  dynamic "tcp" {
    for_each = local.sg_mappedrules[count.index].type == "tcp" ? [
      {
        port_max = local.sg_mappedrules[count.index].port_max
        port_min = local.sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = tcp.value.port_max
      port_min = tcp.value.port_min

    }
  }
  dynamic "udp" {
    for_each = local.sg_mappedrules[count.index].type == "udp" ? [
      {
        port_max = local.sg_mappedrules[count.index].port_max
        port_min = local.sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      port_max = udp.value.port_max
      port_min = udp.value.port_min
    }
  }
  dynamic "icmp" {
    for_each = local.sg_mappedrules[count.index].type == "icmp" ? [
      {
        type = local.sg_mappedrules[count.index].port_max
        code = local.sg_mappedrules[count.index].port_min
      }
    ] : []
    content {
      type = icmp.value.type
      code = icmp.value.code
    }
  }
}

