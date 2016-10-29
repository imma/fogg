variable "org_remote_state" {}

variable "env_remote_state" {}

data "terraform_remote_state" "org" {
  backend = "local"

  config {
    path = "${var.org_remote_state}"
  }
}

data "terraform_remote_state" "env" {
  backend = "local"

  config {
    path = "${var.env_remote_state}"
  }
}

resource "aws_security_group" "app" {
  name        = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
  description = "Application ${var.app_name}"
  vpc_id      = "${data.terraform_remote_state.env.vpc_id}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_iam_role" "app" {
  name = "${data.terraform_remote_state.env.env_name}-${var.app_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_group" "app" {
  name = "${data.terraform_remote_state.env.env_name}-${var.app_name}"
}
