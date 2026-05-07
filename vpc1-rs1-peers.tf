data "external" "wait_for_router1" {
  program = ["bash", "${path.module}/scripts/wait_for_instance.sh"]
  depends_on = [module.hcp]

  query = {
    tag_key   = "bgp_router_subnet"
    tag_value = "1"
    region    = var.aws_region
    timeout_s = 3600
    sleep_s   = 10
  }
}
data "external" "wait_for_router2" {
  program = ["bash", "${path.module}/scripts/wait_for_instance.sh"]
  depends_on = [module.hcp]

  query = {
    tag_key   = "bgp_router_subnet"
    tag_value = "2"
    region    = var.aws_region
    timeout_s = 3600
    sleep_s   = 10
  }
}
data "external" "wait_for_router3" {
  program = ["bash", "${path.module}/scripts/wait_for_instance.sh"]
  depends_on = [module.hcp]

  query = {
    tag_key   = "bgp_router_subnet"
    tag_value = "3"
    region    = var.aws_region
    timeout_s = 3600
    sleep_s   = 10
  }
}



# Use the found instance id in other resources
locals {
  router1_ip = data.external.wait_for_router1.result.private_ip
  router2_ip = data.external.wait_for_router2.result.private_ip
  router3_ip = data.external.wait_for_router3.result.private_ip
}

# create route server peers for router worker node in subnet1

resource "aws_vpc_route_server_peer" "subnet1_ep1_rosa_router1" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.vpc1-rs1-subnet1-ep1.route_server_endpoint_id
  peer_address = data.external.wait_for_router1.result.private_ip
  depends_on = [module.hcp]
  bgp_options {
    peer_asn = var.rosa_bgp_asn
    peer_liveness_detection = "bgp-keepalive" #need to check why bfd isnt working
  }
  tags = merge(
    local.tags,
    {
      Name = "rs1-subnet1_ep1_rosa_router1_peer"
    }
  )
}
resource "aws_vpc_route_server_peer" "subnet1_ep2_rosa_router1" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.vpc1-rs1-subnet1-ep2.route_server_endpoint_id
  peer_address = data.external.wait_for_router1.result.private_ip
  depends_on = [module.hcp]
  bgp_options {
    peer_asn = var.rosa_bgp_asn
    peer_liveness_detection = "bgp-keepalive" #need to check why bfd isnt working
  }
  tags = merge(
    local.tags,
    {
      Name = "rs1_subnet1_ep2_rosa_router1_peer"
    }
  )
}

resource "aws_vpc_route_server_peer" "subnet2_ep1_rosa_router2" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.vpc1-rs1-subnet2-ep1.route_server_endpoint_id
  peer_address = data.external.wait_for_router2.result.private_ip
  depends_on = [module.hcp]
  bgp_options {
    peer_asn = var.rosa_bgp_asn
    peer_liveness_detection = "bgp-keepalive" #need to check why bfd isnt working
  }
  tags = merge(
    local.tags,
    {
      Name = "rs1_subnet2_ep1_rosa_router2_peer"
    }
  )
}
resource "aws_vpc_route_server_peer" "subnet2_ep2_rosa_router2" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.vpc1-rs1-subnet2-ep2.route_server_endpoint_id
  peer_address = data.external.wait_for_router2.result.private_ip
  depends_on = [module.hcp]
  bgp_options {
    peer_asn = var.rosa_bgp_asn
    peer_liveness_detection = "bgp-keepalive" #need to check why bfd isnt working
  }
  tags = merge(
    local.tags,
    {
      Name = "rs1_subnet2_ep2_rosa_router2_peer"
    }
  )
}

resource "aws_vpc_route_server_peer" "subnet3_ep1_rosa_router3" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.vpc1-rs1-subnet3-ep1.route_server_endpoint_id
  peer_address = data.external.wait_for_router3.result.private_ip
  depends_on = [module.hcp]
  bgp_options {
    peer_asn = var.rosa_bgp_asn
    peer_liveness_detection = "bgp-keepalive" #need to check why bfd isnt working
  }
  tags = merge(
    local.tags,
    {
    Name = "rs1_subnet3_ep1_rosa_router3_peer"
    }
  )
}
resource "aws_vpc_route_server_peer" "subnet3_ep2_rosa_router3" {
  route_server_endpoint_id = aws_vpc_route_server_endpoint.vpc1-rs1-subnet3-ep2.route_server_endpoint_id
  peer_address = data.external.wait_for_router3.result.private_ip
  depends_on = [module.hcp]
  bgp_options {
    peer_asn = var.rosa_bgp_asn
    peer_liveness_detection = "bgp-keepalive" #need to check why bfd isnt working
  }
  tags = merge(
    local.tags,
    {
      Name = "rs1_subnet3_ep2_rosa_router3_peer"
    }
  )
}

# run script to disable src/dst checking of all ec2 instances with tag bgp_router=true
resource "null_resource" "disable_src_dst_check_sh" {
  triggers = {
    router1_ip = data.external.wait_for_router1.result.private_ip
    router2_ip = data.external.wait_for_router2.result.private_ip
    router3_ip = data.external.wait_for_router3.result.private_ip
  }

  provisioner "local-exec" {
    command     = "${path.module}/scripts/disable_src_dst_check.sh ${var.aws_region}"
    interpreter = ["/bin/bash"]
  }

  depends_on = [aws_vpc_route_server_peer.subnet1_ep1_rosa_router1, aws_vpc_route_server_peer.subnet2_ep1_rosa_router2, aws_vpc_route_server_peer.subnet3_ep1_rosa_router3]
}
