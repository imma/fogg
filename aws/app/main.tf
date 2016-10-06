data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${var.global_remote_state}"
  }
}

data "terraform_remote_state" "env" {
  backend = "local"

  config {
    path = "${var.env_remote_state}"
  }
}

resource "aws_security_group" "app" {
  name        = "${var.app_name}"
  description = "Application ${var.app_name}"
  vpc_id      = "${data.terraform_remote_state.env.vpc_id}"

  tags {
    "Name"      = "${var.app_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_subnet" "app" {
  vpc_id                  = "${data.terraform_remote_state.env.vpc_id}"
  availability_zone       = "${element(var.az_names,count.index)}"
  cidr_block              = "${cidrsubnet(data.terraform_remote_state.env.env_cidr,var.app_bits,element(var.app_nets,count.index))}"
  map_public_ip_on_launch = true
  count                   = "${var.az_count}"

  tags {
    "Name"      = "${var.app_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route_table" "app" {
  vpc_id = "${data.terraform_remote_state.env.vpc_id}"
  count  = "${var.az_count}"

  tags {
    "Name"      = "${var.app_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route" "app" {
  route_table_id         = "${element(aws_route_table.app.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${element(data.terraform_remote_state.env.nat_gateways,count.index)}"
  count                  = "${var.az_count}"
}

resource "aws_route_table_association" "app" {
  subnet_id      = "${element(aws_subnet.app.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.app.*.id,count.index)}"
  count          = "${var.az_count}"
}
