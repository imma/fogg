provider "aws" {
  region = "${var.aws_region}"
}

# module
module "global" {
  source          = "../../fogg/module/global"

  aws_region      = "${var.aws_region}"
  domain_name     = "${var.domain_name}"
}

# data

# output
output env_cidr {
  value = "${var.env_cidr}"
}

output env_region {
  value = "${var.env_region}"
}

output sys_nets {
  value = "${var.sys_nets}"
}

output service_nets {
  value = "${var.service_nets}"
}
