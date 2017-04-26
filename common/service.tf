module "service" {
  source = "../../../../../module/service"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  global_region = "${var.remote_region}"

  env_bucket = "${var.remote_bucket}"
  env_key    = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
  env_region = "${var.remote_region}"

  app_bucket = "${var.remote_bucket}"
  app_key    = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
  app_region = "${var.remote_region}"

  az_count     = "${var.az_count}"
  service_name = "${var.service_name}"
  peer_count   = "${var.peer_count}"

  public_network   = "${var.public_network}"
  public_lb        = "${var.public_lb}"
  want_fs          = "${var.want_fs}"
  want_nat         = "${var.want_nat}"
  want_ipv6        = "${var.want_ipv6}"
  want_elb         = "${var.want_elb}"
  instance_type    = ["${var.instance_type}"]
  root_volume_size = ["${var.root_volume_size}"]
  user_data        = "${var.user_data}"
  service_default  = "${var.service_default}"
  ami_id           = "${var.ami_id}"
  want_eip         = "${var.want_eip}"
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket = "${var.remote_bucket}"
    key    = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
    region = "${var.remote_region}"
  }
}
