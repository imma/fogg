data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${var.remote_key_org}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env_net" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${var.remote_key_net}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env_stag" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${var.remote_key_stag}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env_prod" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${var.remote_key_prod}"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
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
