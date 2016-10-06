data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${var.global_remote_state}"
  }
}

data "terraform_remote_state" "env" {
  backend = "local"

  config {
    path = "${var.env_remote_state}"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.app_name}"
  description = "Application ${var.app_name}"
  vpc_id      = "${data.terraform_remote_state.env.vpc_id}"

  tags {
    "Name"      = "${var.app_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "ManagedBy" = "terraform"
  }
}
