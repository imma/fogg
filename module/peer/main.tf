variable "cidr_block" {}
variable "peer_id" {}
variable "route_table_id" {}

data "aws_route_table" "rt" {
  route_table_id = "${var.route_table_id}"
}

resource "aws_route" "rt" {
  route_table_id            = "${data.aws_route_table.rt.id}"
  destination_cidr_block    = "${var.cidr_block}"
  vpc_peering_connection_id = "${var.peer_id}"
}
