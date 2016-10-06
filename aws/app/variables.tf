variable "env_remote_state" {}

variable "global_remote_state" {}

variable "app_name" {}

variable "az_count" {}

variable "az_names" {
  default = [0]
}

output "s3_remote_state" {
  value = "${data.terraform_remote_state.global.s3_remote_state}"
}
