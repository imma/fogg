module "instance" {
  source = "module/fogg/instance"
}

data "terraform_remote_state" "org" {
  backend = "s3"

  config {
    bucket     = "${var.remote_bucket}"
    key        = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
    region     = "${var.remote_region}"
    lock_table = "terraform_state_lock"
  }
}
