variable "env_remote_state" {}

variable "global_remote_state" {}

variable "app_name" {}

variable "display_name" {
  default = ""
}

variable "service_name" {}

variable "az_count" {}

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

data "aws_availability_zones" "azs" {}

data "aws_ami" "service" {
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
  availability_zone       = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block              = "${cidrsubnet(data.terraform_remote_state.env.env_cidr,var.service_bits,element(var.service_nets,count.index))}"
  map_public_ip_on_launch = "${lookup(map("1","true","0","false"),format("%d",signum(var.public_network)))}"
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
  count  = "${var.az_count*(signum(var.public_network)-1)*-1}"

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
  count                  = "${var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table_association" "service" {
  subnet_id      = "${element(aws_subnet.service.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.service.*.id,count.index)}"
  count          = "${var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table" "service_public" {
  vpc_id = "${data.terraform_remote_state.env.vpc_id}"
  count  = "${var.az_count*signum(var.public_network)}"

  tags {
    "Name"      = "${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${var.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
    "Network"   = "public"
  }
}

resource "aws_route" "service_public" {
  route_table_id         = "${element(aws_route_table.service_public.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${data.terraform_remote_state.env.igw_id}"
  count                  = "${var.az_count*signum(var.public_network)}"
}

resource "aws_route_table_association" "service_public" {
  subnet_id      = "${element(aws_subnet.service.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.service_public.*.id,0)}"
  count          = "${var.az_count*signum(var.public_network)}"
}

resource "aws_iam_role" "service" {
  name = "${var.app_name}-${var.service_name}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": { 
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "service" {
  name  = "${var.app_name}-${var.service_name}"
  roles = ["${aws_iam_role.service.name}"]
}

resource "aws_iam_group" "service" {
  name = "${var.app_name}-${var.service_name}"
}

resource "aws_launch_configuration" "service" {
  name                 = "${var.app_name}-${var.service_name}-${element(var.asg_name,count.index)}-"
  instance_type        = "${element(var.instance_type,count.index)}"
  image_id             = "${coalesce(element(var.image_id,count.index),data.aws_ami.service.id)}"
  iam_instance_profile = "${var.app_name}-${var.service_name}"
  key_name             = "${data.terraform_remote_state.env.key_name}"
  user_data            = "${element(var.user_data,count.index)}"
  security_groups      = ["${concat(list(aws_security_group.service.id),var.security_groups)}"]
  count                = "${var.asg_count}"

  lifecycle {
    create_before_destroy = true
  }

  root_block_device {
    volume_type = "gp2"
    volume_size = "${element(var.root_volume_size,count.index)}"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdb"
    virtual_name = "ephemeral0"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdc"
    virtual_name = "ephemeral1"
  }

  ephemeral_block_device {
    device_name  = "/dev/sdd"
    virtual_name = "ephemeral2"
  }

  ephemeral_block_device {
    device_name  = "/dev/sde"
    virtual_name = "ephemeral3"
  }
}

resource "aws_autoscaling_group" "service" {
  name                 = "${var.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  launch_configuration = "${element(aws_launch_configuration.service.*.name,count.index)}"
  vpc_zone_identifier  = ["${aws_subnet.service.*.id}"]
  min_size             = "${element(var.min_size,count.index)}"
  max_size             = "${element(var.max_size,count.index)}"
  termination_policies = ["${var.termination_policies}"]
  count                = "${var.asg_count}"

  tag {
    key                 = "Name"
    value               = "${var.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = "${data.terraform_remote_state.env.env_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "App"
    value               = "${var.app_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "asg ${var.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }
}
