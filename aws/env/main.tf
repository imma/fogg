data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${var.global_remote_state}"
  }
}

data "aws_availability_zones" "azs" {}

resource "aws_vpc" "env" {
  cidr_block           = "${var.env_cidr}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_key_pair" "env" {
  key_name   = "${var.env_name}"
  public_key = "${file("etc/key-pair.pub")}"
}

resource "aws_security_group" "env" {
  name        = "${var.env_name}"
  description = "Environment ${var.env_name}"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group_rule" "env_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.env.id}"
}

resource "aws_security_group" "env_private" {
  name        = "${var.env_name}-private"
  description = "Environment ${var.env_name} Private"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group_rule" "ping_private" {
  type              = "ingress"
  from_port         = 9
  to_port           = -1
  protocol          = "icmp"
  cidr_blocks       = ["${var.env_cidr}"]
  security_group_id = "${aws_security_group.env_private.id}"
}

resource "aws_security_group_rule" "ssh_private" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["${var.env_cidr}"]
  security_group_id = "${aws_security_group.env_private.id}"
}

resource "aws_security_group" "env_public" {
  name        = "${var.env_name}-public"
  description = "Environment ${var.env_name} Public"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_security_group" "env_lb" {
  name        = "${var.env_name}-lb"
  description = "Environment ${var.env_name} LB"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group_rule" "env_lb_egress" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = "${aws_security_group.env_lb.id}"
}

resource "aws_security_group" "env_lb_private" {
  name        = "${var.env_name}-lb-private"
  description = "Environment ${var.env_name} LB Private"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_security_group" "env_lb_public" {
  name        = "${var.env_name}-lb-public"
  description = "Environment ${var.env_name} LB Public"
  vpc_id      = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_internet_gateway" "env" {
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_eip" "nat" {
  vpc   = true
  count = "${var.az_count}"
}

resource "aws_subnet" "nat" {
  vpc_id                  = "${aws_vpc.env.id}"
  availability_zone       = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block              = "${cidrsubnet(var.env_cidr,var.nat_bits,element(var.nat_nets,count.index))}"
  map_public_ip_on_launch = true
  count                   = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route" "nat" {
  route_table_id         = "${aws_route_table.nat.id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.env.id}"
}

resource "aws_route_table_association" "nat" {
  subnet_id      = "${element(aws_subnet.nat.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.nat.*.id,count.index)}"
  count          = "${var.az_count}"
}

resource "aws_nat_gateway" "env" {
  subnet_id     = "${element(aws_subnet.nat.*.id,count.index)}"
  allocation_id = "${element(aws_eip.nat.*.id,count.index)}"
  count         = "${var.az_count}"
}

resource "aws_route_table" "nat" {
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route53_zone" "public" {
  name = "${lookup(map("1",var.env_zone,"0",var.env_name),format("%d",signum(length(var.env_zone))))}.${lookup(map("1",var.env_domain_name,"0",data.terraform_remote_state.global.domain_name),format("%d",signum(length(var.env_domain_name))))}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route53_zone" "private" {
  name   = "${lookup(map("1",var.env_zone,"0",var.env_name),format("%d",signum(length(var.env_zone))))}.${lookup(map("1",var.env_domain_name,"0",data.terraform_remote_state.global.domain_name),format("%d",signum(length(var.env_domain_name))))}"
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}
