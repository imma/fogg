provider "aws" {
  region = "${data.terraform_remote_state.env.aws_region}"
}

# module
module "service" {
  source              = "../../../../../module/service"

  global_remote_state = "${data.terraform_remote_state.global.config["path"]}"
  env_remote_state    = "${data.terraform_remote_state.env.config["path"]}"
  app_remote_state    = "${data.terraform_remote_state.app.config["path"]}"

  az_count            = "${var.az_count}"
  service_name        = "${var.service_name}"
  peer_count          = "${var.peer_count}"

  public_network      = "${var.public_network}"
  public_lb           = "${var.public_lb}"
  want_fs             = "${var.want_fs}"
  want_nat            = "${var.want_nat}"
  want_elb            = "${var.want_elb}"
  instance_type       = ["${var.instance_type}"]
  user_data           = "${var.user_data}"
}

# data
data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "../../../.terraform/terraform.tfstate"
  }
}

data "terraform_remote_state" "env" {
  backend = "local"

  config {
    path = "../../.terraform/terraform.tfstate"
  }
}

data "terraform_remote_state" "app" {
  backend = "local"

  config {
    path = "../.terraform/terraform.tfstate"
  }
}


output "aws_region" {
  value = "${data.terraform_remote_state.env.aws_region}"
}
