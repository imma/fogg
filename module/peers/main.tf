variable "this_vpc_id" {}
variable "that_vpc_id" {}

data "aws_caller_identity" "current" {}

resource "aws_vpc_peering_connection" "peer" {
  vpc_id        = "${var.this_vpc_id}"
  peer_vpc_id   = "${var.that_vpc_id}"
  peer_owner_id = "${data.aws_caller_identity.current.account_id}"
  auto_accept   = true
}

output "peer_id" {
  value = "${aws_vpc_peering_connection.peer.id}"
}
