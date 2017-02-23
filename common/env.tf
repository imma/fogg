provider "aws" {
  region = "${data.terraform_remote_state.global.org["region_${var.env_name}"]}"
}

# module
module "env" {
  source              = "../../../module/env"

  global_remote_state = "${data.terraform_remote_state.global.config["path"]}"

  az_count            = "${var.az_count}"
  env_name            = "${var.env_name}"

  public_key          = "${var.public_key}"
  ami_id              = "${var.ami_id}"

  nat_count           = "${var.nat_count}"
  want_fs             = "${var.want_fs}"
  want_nat            = "${var.want_nat}"

  sg_extra            = ["${var.sg_extra}"]
  iam_extra           = ["${var.iam_extra}"]
}

# data
data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "../.terraform/terraform.tfstate"
  }
}

# output
output "aws_region" {
  value = "${data.terraform_remote_state.global.org["region_${var.env_name}"]}"
}
