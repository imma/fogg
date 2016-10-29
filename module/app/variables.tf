variable "app_name" {}

variable "az_count" {}

output "app_name" {
  value = "${var.app_name}"
}

output "app_sg" {
  value = "${aws_security_group.app.id}"
}
