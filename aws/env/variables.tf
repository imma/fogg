variable "global_remote_state" {}

variable "env_name" {}

variable "az_count" {}

variable "az_names" {
  default = [0]
}

variable "env_cidr" {}

variable "nat_bits" {
  default = "12"
}

variable "nat_nets" {
  default = [0]
}

variable "env_zone" {
  default = ""
}

variable "env_domain_name" {
  default = ""
}

output "vpc_id" {
  value = "${aws_vpc.env.id}"
}

output "igw_id" {
  value = "${aws_internet_gateway.env.id}"
}

output "public_zone_id" {
  value = "${aws_route53_zone.public.zone_id}"
}

output "public_zone_servers" {
  value = "${aws_route53_zone.public.name_servers}"
}

output "public_zone_name" {
  value = "${lookup(map("1",var.env_zone,"0",var.env_name),format("%d",signum(length(var.env_zone))))}.${lookup(map("1",var.env_domain_name,"0",data.terraform_remote_state.global.domain_name),format("%d",signum(length(var.env_domain_name))))}"
}

output "private_zone_id" {
  value = "${aws_route53_zone.private.zone_id}"
}

output "private_zone_servers" {
  value = "${aws_route53_zone.private.name_servers}"
}

output "private_zone_name" {
  value = "${lookup(map("1",var.env_zone,"0",var.env_name),format("%d",signum(length(var.env_zone))))}.${lookup(map("1",var.env_domain_name,"0",data.terraform_remote_state.global.domain_name),format("%d",signum(length(var.env_domain_name))))}"
}
