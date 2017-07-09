module "env" {
  source = "../../module/fogg/env"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  global_region = "${var.remote_region}"
}
