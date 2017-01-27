variable "global_remote_state" {}

data "terraform_remote_state" "global" {
  backend = "local"

  config {
    path = "${var.global_remote_state}"
  }
}

data "aws_vpc" "current" {
  id = "${aws_vpc.env.id}"
}

data "aws_availability_zones" "azs" {}

data "aws_ami" "env" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "block-device-mapping.volume-type"
    values = ["gp2"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_vpc" "env" {
  cidr_block           = "${data.terraform_remote_state.global.env_cidr[var.env_name]}"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
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
    "Name"      = "${var.env_name}-nat"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_eip" "nat" {
  vpc   = true
  count = "${var.want_nat*(var.az_count*(signum(var.nat_count)-1)*-1+var.nat_count)}"
}

resource "aws_subnet" "nat" {
  vpc_id                  = "${aws_vpc.env.id}"
  availability_zone       = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.nat_bits,element(data.terraform_remote_state.global.sys_nets["nat"],count.index))}"
  map_public_ip_on_launch = true
  count                   = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}-nat"
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
  count         = "${var.want_nat*(var.az_count*(signum(var.nat_count)-1)*-1+var.nat_count)}"
}

resource "aws_route_table" "nat" {
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}-nat"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_subnet" "common" {
  vpc_id                  = "${aws_vpc.env.id}"
  availability_zone       = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.common_bits,element(data.terraform_remote_state.global.sys_nets["common"],count.index))}"
  map_public_ip_on_launch = false
  count                   = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}-common"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route" "common" {
  route_table_id         = "${element(aws_route_table.common.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(aws_nat_gateway.env.*.id,count.index%(var.az_count*(signum(var.nat_count)-1)*-1+var.nat_count))}"
  count                  = "${var.want_nat*var.az_count}"
}

resource "aws_route_table_association" "common" {
  subnet_id      = "${element(aws_subnet.common.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.common.*.id,count.index)}"
  count          = "${var.az_count}"
}

resource "aws_route_table" "common" {
  vpc_id = "${aws_vpc.env.id}"
  count  = "${var.az_count}"

  tags {
    "Name"      = "${var.env_name}-common"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route53_zone" "private" {
  name   = "${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${var.env_domain_name == 1 ? var.env_domain_name : data.terraform_remote_state.global.domain_name}"
  vpc_id = "${aws_vpc.env.id}"

  tags {
    "Name"      = "${var.env_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }
}

module "fs" {
  source   = "../fs"
  fs_name  = "${var.env_name}"
  vpc_id   = "${aws_vpc.env.id}"
  env_name = "${var.env_name}"
  subnets  = ["${aws_subnet.common.*.id}"]
  az_count = "${var.az_count}"
  want_fs  = "${var.want_fs}"
}

resource "aws_route53_record" "fs" {
  zone_id = "${aws_route53_zone.private.zone_id}"
  name    = "efs-${element(data.aws_availability_zones.azs.names,count.index)}.${signum(length(var.env_zone)) == 1 ? var.env_zone : var.env_name}.${signum(length(var.env_domain_name)) == 1 ? var.env_domain_name : var.env_domain_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${element(module.fs.efs_dns_names,count.index)}"]
  count   = "${var.az_count*var.want_fs}"
}

#resource "aws_vpc_endpoint" "s3" {

#  vpc_id       = "${aws_vpc.env.id}"

#  service_name = "com.amazonaws.${var.aws_region}.s3"

#}

resource "aws_s3_bucket" "lb" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-lb"
  acl    = "private"

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

resource "aws_cloudwatch_log_group" "flow_log" {
  name = "${var.env_name}-flow-log"
}

data "aws_iam_policy_document" "flow_log" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow_log" {
  name               = "${var.env_name}-flow-log"
  assume_role_policy = "${data.aws_iam_policy_document.flow_log.json}"
}

data "aws_iam_policy_document" "flow_log_logs" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_log" {
  name   = "${var.env_name}-flow-log"
  role   = "${aws_iam_role.flow_log.id}"
  policy = "${data.aws_iam_policy_document.flow_log_logs.json}"
}

resource "aws_flow_log" "env" {
  log_group_name = "${aws_cloudwatch_log_group.flow_log.name}"
  iam_role_arn   = "${aws_iam_role.flow_log.arn}"
  vpc_id         = "${aws_vpc.env.id}"
  traffic_type   = "ALL"
}

resource "aws_s3_bucket" "s3-meta" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-s3-meta"
  acl    = "log-delivery-write"

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

resource "aws_s3_bucket" "s3" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-s3"
  acl    = "log-delivery-write"

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-s3-meta"
    target_prefix = "log/"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

resource "aws_s3_bucket" "website" {
  bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-website"
  acl    = "private"

  logging {
    target_bucket = "b-${format("%.8s",sha1(data.terraform_remote_state.global.aws_account_id))}-${var.env_name}-s3"
    target_prefix = "log/"
  }

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  versioning {
    enabled = true
  }

  tags {
    "ManagedBy" = "terraform"
    "Env"       = "${var.env_name}"
  }
}

data "template_file" "key_pair_service" {
  template = "${file(var.public_key)}"
}

resource "aws_key_pair" "service" {
  public_key = "${data.template_file.key_pair_service.rendered}"

  lifecycle {
    create_before_destroy = true
  }
}
