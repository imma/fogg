provider "aws" {
  region = "${data.terraform_remote_state.env.aws_region}"
}

# module
module "app" {
  source              = "../../../../fogg/module/app"

  org_remote_state = "${data.terraform_remote_state.org.config["path"]}"
  env_remote_state    = "${data.terraform_remote_state.env.config["path"]}"

  az_count            = "${var.az_count}"
  app_name            = "${var.app_name}"
}

# data
data "terraform_remote_state" "org" {
  backend = "local"

  config {
    path = "../../.terraform/terraform.tfstate"
  }
}

data "terraform_remote_state" "env" {
  backend = "local"

  config {
    path = "../.terraform/terraform.tfstate"
  }
}

# output
output "env_region" {
  value = "${data.terraform_remote_state.org.env_region}"
}
