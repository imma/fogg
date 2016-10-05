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

output "public_zone_id" {
  value = ["${aws_route53_zone.public.zone_id}"]
}

output "public_name_servers" {
  value = ["${aws_route53_zone.public.name_servers}"]
}
