variable "env_remote_state" {}

variable "global_remote_state" {}

variable "app_name" {}

variable "az_count" {}

variable "az_names" {
  default = [0]
}

variable "app_bits" {
  default = "12"
}

variable "app_nets" {
  default = [0]
}
