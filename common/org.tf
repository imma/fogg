variable "remote_bucket" {}
variable "remote_path" {}
variable "remote_region" {}

module "org" {
  source = "module/fogg/org"

  domain_name = "${var.domain_name}"
}

output org {
  value = "${data.external.org.result}"
}
