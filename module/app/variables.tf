variable "global_bucket" {}
variable "global_key" {}
variable "global_region" {}

variable "env_bucket" {}
variable "env_key" {}
variable "env_region" {}

variable "app_name" {}

variable "az_count" {}

output "app_name" {
  value = "${var.app_name}"
}

output "app_sg" {
  value = "${aws_security_group.app.id}"
}

output "app_ami_id" {
  value = "${data.terraform_remote_state.env.env_ami_id}"
}
