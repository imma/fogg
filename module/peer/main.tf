variable "peer_name" {}
variable "vpc_id" {}

data "aws_caller_identity" "current" {}

data "aws_vpc" "peer" {
  filter {
    name   = "tag:Name"
    values = ["${var.peer_name}"]
  }
}

resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = "${var.vpc_id}"
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  peer_vpc_id   = "${data.aws_vpc.peer.id}"
  auto_accept   = true
}

