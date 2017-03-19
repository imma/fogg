variable "remote_bucket" {}
variable "remote_path" {}
variable "remote_region" {}

module "global" {
  source = "../../module/global"

  domain_name = "${var.domain_name}"
}
