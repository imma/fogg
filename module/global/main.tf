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
  bucket   = "${var.s3_remote_state}"
  acl      = "private"
  provider = "aws.us_west_1"

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
