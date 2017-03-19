# module
module "env" {
  source = "../../../module/env"

  global_bucket = "${var.global_bucket}"
  global_key    = "${var.global_key}"
  global_region = "${var.global_region}"

  az_count = "${var.az_count}"
  env_name = "${var.env_name}"

  public_key = "${var.public_key}"
  ami_id     = "${var.ami_id}"

  nat_count = "${var.nat_count}"
  want_fs   = "${var.want_fs}"
  want_nat  = "${var.want_nat}"

  sg_extra  = ["${var.sg_extra}"]
  iam_extra = ["${var.iam_extra}"]
}
