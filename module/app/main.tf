data "terraform_remote_state" "global" {
  backend = "s3"

  config {
    bucket = "${var.global_bucket}"
    key    = "${var.global_key}"
    region = "${var.global_region}"
  }
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket = "${var.env_bucket}"
    key    = "${var.env_key}"
    region = "${var.env_region}"
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
