# module
module "app" {
  source = "../../../../module/app"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${slice(split("_",var.remote_path),0,1)}/terraform.tfstate"
  global_region = "${var.remote_region}"

  env_bucket = "${var.remote_bucket}"
  env_key    = "${slice(split("_",var.remote_path),0,2)}/terraform.tfstate"
  env_region = "${var.remote_region}"

  az_count = "${var.az_count}"
  app_name = "${var.app_name}"
}
