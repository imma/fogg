variable "env_remote_state" {}

variable "global_remote_state" {}

variable "app_name" {}

variable "az_count" {}

output "s3_remote_state" {
  value = "${data.terraform_remote_state.global.s3_remote_state}"
}

output "app_sg" {
  value = "${aws_security_group.app.id}"
}
