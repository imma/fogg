module "service" {
  source = "../../../../module/service"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  global_region = "${var.remote_region}"

  env_bucket = "${var.remote_bucket}"
  env_key    = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  env_region = "${var.remote_region}"

  app_bucket = "${var.remote_bucket}"
  app_key    = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
  app_region = "${var.remote_region}"
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket = "${var.remote_bucket}"
    key    = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
    region = "${var.remote_region}"
  }
}
