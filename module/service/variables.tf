variable "service_bits" {
  default = "12"
}

variable "service_nets" {
  default = [0]
}

variable "asg_count" {
  default = 2
}

variable "asg_name" {
  default = ["blue", "green"]
}

variable "instance_type" {
  default = ["t2.small", "t2.small"]
}

variable "image_id" {
  default = ["", ""]
}

variable "root_volume_size" {
  default = ["20", "20"]
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

variable "security_groups" {
  default = [0]
}

variable "ignore_asg_changes" {
  default = [""]
}

variable "public_key" {
  default = "etc/ssh-key-pair.pub"
}

variable "user_data" {
  default = "etc/user-data.template"
}
