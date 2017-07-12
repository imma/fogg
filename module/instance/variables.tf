variable "instance_id" {}

variable "ebs_count" {
  default = "2"
}

variable "want_eip" {
  default = "0"
}

variable "devices" {
  default = ["/dev/sdh", "/dev/sdi"]
}

output "eip" {
  value = "${aws_eip.this.public_ip}"
}
