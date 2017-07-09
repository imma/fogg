module "app" {
  source = "../../../module/fogg/app"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  global_region = "${var.remote_region}"

  env_bucket = "${var.remote_bucket}"
  env_key    = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  env_region = "${var.remote_region}"
}
