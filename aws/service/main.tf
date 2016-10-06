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

resource "aws_security_group" "service" {
  name        = "${var.app_name}-${var.service_name}"
  description = "Service ${var.app_name}-${var.service_name}"
  vpc_id      = "${data.terraform_remote_state.env.vpc_id}"

  tags {
    "Name"      = "${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${var.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_subnet" "service" {
  vpc_id                  = "${data.terraform_remote_state.env.vpc_id}"
  availability_zone       = "${element(var.az_names,count.index)}"
  cidr_block              = "${cidrsubnet(data.terraform_remote_state.env.env_cidr,var.service_bits,element(var.service_nets,count.index))}"
  map_public_ip_on_launch = true
  count                   = "${var.az_count}"

  tags {
    "Name"      = "${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${var.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route_table" "service" {
  vpc_id = "${data.terraform_remote_state.env.vpc_id}"
  count  = "${var.az_count}"

  tags {
    "Name"      = "${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${var.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route" "service" {
  route_table_id         = "${element(aws_route_table.service.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(data.terraform_remote_state.env.nat_gateways,count.index)}"
  count                  = "${var.az_count}"
}

resource "aws_route_table_association" "service" {
  subnet_id      = "${element(aws_subnet.service.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.service.*.id,count.index)}"
  count          = "${var.az_count}"
}
