variable "env_remote_state" {}

variable "global_remote_state" {}

variable "app_name" {}

variable "display_name" {
  default = ""
}

variable "service_name" {}

variable "az_count" {}

variable "az_names" {
  default = [0]
}

variable "service_bits" {
  default = "12"
}

variable "service_nets" {
  default = [0]
}
