provider "aws" {
  region = "${data.terraform_remote_state.env.aws_region}"
}

# module
module "service" {
  source              = "../../../../../fogg/module/service"

  org_remote_state = "${data.terraform_remote_state.org.config["path"]}"
  env_remote_state    = "${data.terraform_remote_state.env.config["path"]}"
  app_remote_state    = "${data.terraform_remote_state.app.config["path"]}"

  az_count            = "${var.az_count}"
  service_name        = "${var.service_name}"

  public_network      = "${var.public_network}"
  want_fs             = "${var.want_fs}"
  want_nat            = "${var.want_nat}"
  instance_type       = ["${var.instance_type}"]
  user_data           = "${var.user_data}"
  public_key          = "${var.public_key}"
}

# data
data "terraform_remote_state" "org" {
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
