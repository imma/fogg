data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${var.global_remote_state}"
  }
}
