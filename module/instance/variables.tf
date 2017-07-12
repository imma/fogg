variable "ebs_count" {
  default = "2"
}

variable "want_eip" {
  default = "0"
}

variable "devices" {
  default = ["/dev/sdh", "/dev/sdi"]
}
