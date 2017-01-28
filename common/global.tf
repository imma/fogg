provider "aws" {
  region = "${var.aws_region}"
}

# module
module "global" {
  source          = "../../module/global"

  aws_region      = "${var.aws_region}"
  domain_name     = "${var.domain_name}"
  s3_remote_state = "${var.s3_remote_state}"
}

# data

# output
output org {
  value = "${data.external.org.result}"
}

output sys_nets {
  value = "${var.sys_nets}"
}

output service_nets {
  value = "${var.service_nets}"
}

output s3_remote_state {
  value = "${var.s3_remote_state}"
}
