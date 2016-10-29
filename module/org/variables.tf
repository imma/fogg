variable "domain_name" {}

variable "aws_region" {}

output "aws_account_id" {
  value = "${data.aws_caller_identity.current.account_id}"
}

output "domain_name" {
  value = "${var.domain_name}"
}
