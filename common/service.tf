# module
module "service" {
  source              = "../../../../../module/service"

  global_bucket = "${var.global_bucket}"
  global_key = "${var.global_key}"
  global_region = "${var.global_region}"

  env_bucket = "${var.env_bucket}"
  env_key = "${var.env_key}"
  env_region = "${var.env_region}"

  app_bucket = "${var.app_bucket}"
  app_key = "${var.app_key}"
  app_region = "${var.app_region}"

  az_count            = "${var.az_count}"
  service_name        = "${var.service_name}"
  peer_count          = "${var.peer_count}"

  public_network      = "${var.public_network}"
  public_lb           = "${var.public_lb}"
  want_fs             = "${var.want_fs}"
  want_nat            = "${var.want_nat}"
  want_elb            = "${var.want_elb}"
  instance_type       = ["${var.instance_type}"]
  user_data           = "${var.user_data}"
}

# output
output "aws_region" {
  value = "${data.terraform_remote_state.env.aws_region}"
}
