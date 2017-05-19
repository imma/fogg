variable "az_count" {}

variable "service_name" {}

variable "service_default" {
  default = "0"
}

variable "display_name" {
  default = ""
}

variable "public_network" {
  default = "0"
}

variable "public_lb" {
  default = "0"
}

variable "want_fs" {
  default = "0"
}

variable "want_nat" {
  default = "1"
}

variable "want_ipv6" {
  default = "0"
}

variable "want_elb" {
  default = "0"
}

variable "want_eip" {
  default = "0"
}

variable "user_data" {
  default = "../../../.etc/user-data.template"
}

variable "service_bits" {
  default = "12"
}

variable "asg_count" {
  default = 2
}

variable "peer_count" {
  default = 0
}

variable "asg_name" {
  default = ["blue", "green"]
}

variable "instance_type" {
  default = ["t2.medium", "t2.medium"]
}

variable "ami_id" {
  default = ["", ""]
}

variable "root_volume_size" {
  default = ["40", "40"]
}

variable "min_size" {
  default = ["0", "0"]
}

variable "max_size" {
  default = ["5", "5"]
}

variable "termination_policies" {
  default = ["OldestInstance"]
}

variable "block" {
  default = "block-ubuntu"
}

output "asg_names" {
  value = ["${aws_autoscaling_group.service.*.name}"]
}

output "elb_names" {
  value = ["${aws_elb.service.*.name}"]
}

output "elb_dns" {
  value = ["${aws_elb.service.*.dns_name}"]
}

output "elb_dns_name" {
  value = ["${aws_elb.service.*.dns_name}"]
}

output "elb_zone_id" {
  value = ["${aws_elb.service.*.zone_id}"]
}

output "elb_sg" {
  value = "${aws_security_group.lb.id}"
}

output "env_sg" {
  value = "${data.terraform_remote_state.env.sg_env}"
}

output "app_sg" {
  value = "${data.terraform_remote_state.app.app_sg}"
}

output "service_sg" {
  value = "${aws_security_group.service.id}"
}

output "service_subnets" {
  value = ["${aws_subnet.service.*.id}"]
}

output "key_name" {
  value = "${data.terraform_remote_state.env.key_name}"
}

output "service_eips" {
  value = ["${aws_eip.service.*.public_ip}"]
}

output "service_sqs" {
  value = ["${aws_sqs_queue.service.*.id}"]
}

output "service_iam_role" {
  value = "${aws_iam_role.service.name}"
}
