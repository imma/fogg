# module
module "global" {
  source = "../../module/global"

  aws_region  = "${var.aws_region}"
  domain_name = "${var.domain_name}"
}
