data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${var.global_remote_state}"
  }
}

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

resource "aws_internet_gateway" "env" {
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
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
