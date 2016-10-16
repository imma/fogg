variable "aws_account_id" {}

variable "domain_name" {}

variable "s3_remote_state" {}

output "aws_account_id" {
  value = "${var.aws_account_id}"
}

output "s3_remote_state" {
  value = "${var.s3_remote_state}"
}

output "domain_name" {
  value = "${var.domain_name}"
}
