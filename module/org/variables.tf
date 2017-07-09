variable "domain_name" {}

output "aws_account_id" {
  value = "${data.aws_caller_identity.current.account_id}"
}

output "domain_name" {
  value = "${var.domain_name}"
}

output "public_zone_id" {
  value = "${aws_route53_zone.public.zone_id}"
}

output "public_zone_servers" {
  value = "${aws_route53_zone.public.name_servers}"
}

output "config_sqs" {
  value = "${aws_sqs_queue.config.id}"
}
