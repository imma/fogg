variable "global_remote_state" {}

variable "env_cidr" {}

variable "env_name" {}

variable "env_zone" {
  default = ""
}

variable "env_domain_name" {
  default = ""
}

output "vpc_id" {
  value = "${aws_vpc.env.id}"
}

output "domain_name" {
  value = "${data.terraform_remote_state.global.domain_name}"
}
