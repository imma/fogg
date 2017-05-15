data "aws_caller_identity" "current" {}

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

resource "aws_s3_bucket" "s3-meta" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3-meta"
  acl    = "log-delivery-write"

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_s3_bucket" "s3" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
  acl    = "log-delivery-write"

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3-meta"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_s3_bucket" "tf_remote_state" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-tf-remote-state"
  acl    = "private"

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_s3_bucket" "config" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-config"
  acl    = "private"

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_iam_role_policy" "config_s3" {
  name = "config-s3"
  role = "${aws_iam_role.config.id}"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AWSConfigBucketPermissionsCheck",
      "Action": [
				"s3:GetBucketAcl"
			],
      "Effect": "Allow",
      "Principal": {
        "Service": [
         "config.amazonaws.com"
        ]
      },
      "Resource": [
        "${aws_s3_bucket.config.arn}"
      ]
    },
    {
      "Sid": " AWSConfigBucketDelivery",
      "Action": [
				"s3:PutObject"
			],
      "Effect": "Allow",
      "Principal": {
        "Service": [
         "config.amazonaws.com"
        ]
      },
      "Resource": [
        "${aws_s3_bucket.config.arn}/*"
      ],
      "Condition": { 
        "StringEquals": { 
          "s3:x-amz-acl": "bucket-owner-full-control" 
        }
      }
    }
  ]
}
POLICY
}

resource "aws_iam_role" "config" {
  name = "config"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "config.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "config" {
  role       = "${aws_iam_role.config.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_config_delivery_channel" "config" {
  name           = "config"
  s3_bucket_name = "${aws_s3_bucket.config.bucket}"
}

resource "aws_config_configuration_recorder" "config" {
  name     = "config"
  role_arn = "${aws_iam_role.config.arn}"

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_configuration_recorder_status" "config" {
  name       = "${aws_config_configuration_recorder.config.name}"
  is_enabled = true
  depends_on = ["aws_config_delivery_channel.config"]
}

data "aws_billing_service_account" "global" {}

data "aws_iam_policy_document" "billing" {
  statement {
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
    ]

    resources = [
      "arn:aws:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-billing",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_billing_service_account.global.id}:root"]
    }
  }

  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-billing/AWSLogs/*",
    ]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_billing_service_account.global.id}:root"]
    }
  }
}

resource "aws_s3_bucket" "billing" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-billing"
  acl    = "private"

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-s3"
    target_prefix = "log/"
  }

  policy = "${data.aws_iam_policy_document.billing.json}"

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "global"
  }
}

resource "aws_cloudtrail" "global" {
  name                          = "global-cloudtrail"
  s3_bucket_name                = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail"
  include_global_service_events = true
  is_multi_region_trail         = true
}

data "aws_iam_policy_document" "cloudtrail" {
  statement {
    actions = [
      "s3:GetBucketAcl",
      "s3:GetBucketPolicy",
    ]

    resources = [
      "arn:aws:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
  }

  statement {
    actions = [
      "s3:PutObject",
    ]

    resources = [
      "arn:aws:s3:::b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}

resource "aws_s3_bucket" "cloudtrail" {
  bucket = "b-${format("%.8s",sha1(data.aws_caller_identity.current.account_id))}-global-cloudtrail"
  policy = "${data.aws_iam_policy_document.cloudtrail.json}"
}

resource "aws_route53_zone" "public" {
  name = "${var.domain_name}"

  tags {
    "Name"      = "${var.domain_name}"
    "Env"       = "global"
    "ManagedBy" = "terraform"
  }
}

resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "terraform_state_lock"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
