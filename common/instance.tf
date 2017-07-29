module "instance" {
  source = "module/fogg/instance"

  global_bucket = "${var.remote_bucket}"
  global_key    = "${join("_",slice(split("_",var.remote_path),0,1))}/terraform.tfstate"
  global_region = "${var.remote_region}"
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${join("_",slice(split("_",var.remote_path),0,2))}/terraform.tfstate"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "app" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${join("_",slice(split("_",var.remote_path),0,3))}/terraform.tfstate"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "service" {
  backend = "s3"

  config {
    bucket         = "${var.remote_bucket}"
    key            = "${join("_",slice(split("_",var.remote_path),0,4))}/terraform.tfstate"
    region         = "${var.remote_region}"
    dynamodb_table = "terraform_state_lock"
  }
}
