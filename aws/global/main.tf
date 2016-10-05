provider "aws" {}

variable "s3_remote_state" {}

variable "aws_account_id" {}

variable "domain_name" {}

resource "aws_iam_policy" "remote_state" {
  name   = "remote-state"
  policy = "${file("${path.module}/iam/remote_state.json")}"
}

resource "aws_iam_role" "remote_state" {
  name   = "remote-state"
  assume_role_policy = "${file("${path.module}/iam/remote_state_instance_profile.json")}"
}

resource "aws_iam_role_policy_attachment" "remote_state" {
  role       = "${aws_iam_role.remote_state.name}"
  policy_arn = "${aws_iam_policy.remote_state.arn}"
}

resource "aws_iam_group" "remote_state" {
  name = "remote-state"
}

resource "aws_iam_group_policy_attachment" "remote_state" {
  group      = "${aws_iam_group.remote_state.name}"
  policy_arn = "${aws_iam_policy.remote_state.arn}"
}

resource "aws_iam_group" "administrators" {
  name = "administrators"
}

resource "aws_iam_group_policy_attachment" "administrators_iam_full_access" {
  group      = "${aws_iam_group.administrators.name}"
  policy_arn = "arn:aws:iam::aws:policy/IAMFullAccess"
}

resource "aws_iam_group_policy_attachment" "administrators_administrator_access" {
  group      = "${aws_iam_group.administrators.name}"
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_s3_bucket" "remote_state" {
  bucket = "${var.s3_remote_state}"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_route53_zone" "public" {
  name = "${var.domain_name}"

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}
