variable "instance_name" {}

variable "ebs_count" {
  default = "2"
}

variable "want_eip" {
  default = "0"
}

variable "devices" {
  default = ["/dev/sdh", "/dev/sdi"]
}

variable "public_zone" {
  default = ""
}

variable "public_name" {
  default = ""
}

output "eip" {
  value = "${aws_eip.this.public_ip}"
}
