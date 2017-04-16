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

variable "image_id" {
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

output "asg_names" {
  value = ["${aws_autoscaling_group.service.*.name}"]
}

output "elb_names" {
  value = ["${aws_elb.service.*.name}"]
}

output "elb_dns" {
  value = ["${aws_elb.service.*.dns_name}"]
}

output "elb_sg" {
  value = "${aws_security_group.lb.id}"
}

output "service_sg" {
  value = "${aws_security_group.service.id}"
}

output "service_subnets" {
  value = [ "${aws_subnet.service.*.id}" ]
}
