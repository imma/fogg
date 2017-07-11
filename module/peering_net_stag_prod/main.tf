data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket     = "${var.remote_bucket}"
    key        = "${var.remote_key_org}"
    region     = "${var.remote_region}"
    lock_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env_net" {
  backend = "s3"

  config {
    bucket     = "${var.remote_bucket}"
    key        = "${var.remote_key_net}"
    region     = "${var.remote_region}"
    lock_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env_stag" {
  backend = "s3"

  config {
    bucket     = "${var.remote_bucket}"
    key        = "${var.remote_key_stag}"
    region     = "${var.remote_region}"
    lock_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env_prod" {
  backend = "s3"

  config {
    bucket     = "${var.remote_bucket}"
    key        = "${var.remote_key_prod}"
    region     = "${var.remote_region}"
    lock_table = "terraform_state_lock"
  }
}

data "aws_vpc" "net" {
  id = "${data.terraform_remote_state.env_net.vpc_id}"
}

data "aws_vpc" "stag" {
  id = "${data.terraform_remote_state.env_stag.vpc_id}"
}

data "aws_vpc" "prod" {
  id = "${data.terraform_remote_state.env_prod.vpc_id}"
}

module "peer_stag_net" {
  source      = "../peers"
  this_vpc_id = "${data.terraform_remote_state.env_stag.vpc_id}"
  that_vpc_id = "${data.terraform_remote_state.env_net.vpc_id}"
}

module "peer_prod_net" {
  source      = "../peers"
  this_vpc_id = "${data.terraform_remote_state.env_prod.vpc_id}"
  that_vpc_id = "${data.terraform_remote_state.env_net.vpc_id}"
}

module "peer_prod_stag" {
  source      = "../peers"
  this_vpc_id = "${data.terraform_remote_state.env_prod.vpc_id}"
  that_vpc_id = "${data.terraform_remote_state.env_stag.vpc_id}"
}

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
