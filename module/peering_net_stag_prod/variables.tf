variable "remote_bucket" {}

variable "remote_region" {}

variable "remote_key_org" {}

variable "remote_key_net" {}

variable "remote_key_stag" {}

variable "remote_key_prod" {}

output "net_cidr_block" {
  value = "${data.aws_vpc.net.cidr_block}"
}

output "stag_cidr_block" {
  value = "${data.aws_vpc.stag.cidr_block}"
}

output "prod_cidr_block" {
  value = "${data.aws_vpc.prod.cidr_block}"
}

output "prod_stag_peer_id" {
  value = "${module.peer_prod_stag.peer_id}"
}

output "prod_net_peer_id" {
  value = "${module.peer_prod_net.peer_id}"
}

output "stag_net_peer_id" {
  value = "${module.peer_stag_net.peer_id}"
}
