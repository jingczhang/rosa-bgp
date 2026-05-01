variable "aws_region" {
  default     = "eu-central-1"
}

variable "owner" {
  default = "NOBODY"
}
variable "project" {
  default = ""
}

variable "rosa_openshift_version" {
  default = "4.20.0"
}

variable "rosa_cluster_name" {
  default = "rosa1"
}

variable "rosa_bgp_asn" {
  default = "65001"
}

variable "rs_amazon_side_asn" {
  default = "65000"
}

variable "vpc1-rosa_cidr" {
  default = "10.0.0.0/16"
}

variable "vpc1-rosa_private_subnets" { 
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "vpc1-rosa_public_subnets" { 
  default = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "rosa_private_only" {
  type    = bool
  default = false
}

variable "vpc2-ext_cidr" {
  default = "192.168.0.0/16"
}
variable "vpc2-ext_private_subnets" { 
  default = ["192.168.1.0/24", "192.168.2.0/24", "192.168.3.0/24"]
}

variable "vpc2-ext_public_subnets" { 
  default = ["192.168.101.0/24", "192.168.102.0/24", "192.168.103.0/24"]
}

variable "project_id" {
  default = ""
}

variable "rosa_compute_instance_type" {
  default = "c5.metal"
}

variable "tags" {
  type = map(string)
    default = {}
}

variable "azs" {
  type        = list(string)
  default     = []
}