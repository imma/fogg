# module
module "app" {
  source              = "../../../../module/app"

  global_bucket = "${var.global_bucket}"
  global_key = "${var.global_key}"
  global_region = "${var.global_region}"

  env_bucket = "${var.env_bucket}"
  env_key = "${var.env_key}"
  env_region = "${var.env_region}"

  az_count            = "${var.az_count}"
  app_name            = "${var.app_name}"
}

# output
output "aws_region" {
  value = "${data.terraform_remote_state.global.org["region_${var.env_name}"]}"
}
