variable "global_remote_state" {}

variable "env_remote_state" {}

variable "app_remote_state" {}

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

data "terraform_remote_state" "app" {
  backend = "local"

  config {
    path = "${var.app_remote_state}"
  }
}

data "aws_availability_zones" "azs" {}

data "aws_vpc" "current" {
  id = "${data.terraform_remote_state.env.vpc_id}"
}

resource "aws_security_group" "service" {
  name        = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  description = "Service ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

output "service_sg" {
  value = "${aws_security_group.service.id}"
}

resource "aws_subnet" "service" {
  vpc_id                  = "${data.aws_vpc.current.id}"
  availability_zone       = "${element(data.aws_availability_zones.azs.names,count.index)}"
  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.service_bits,element(data.terraform_remote_state.global.service_nets["${data.terraform_remote_state.app.app_name}_${var.service_name}"],count.index))}"
  map_public_ip_on_launch = "${signum(var.public_network) == 1 ? "true" : "false"}"
  count                   = "${var.az_count}"

  lifecycle {
    create_before_destroy = true
  }

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route_table" "service" {
  vpc_id = "${data.aws_vpc.current.id}"
  count  = "${var.az_count*(signum(var.public_network)-1)*-1}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_route" "service" {
  route_table_id         = "${element(aws_route_table.service.*.id,count.index)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${element(data.terraform_remote_state.env.nat_gateways,count.index)}"
  count                  = "${var.want_nat*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table_association" "service" {
  subnet_id      = "${element(aws_subnet.service.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.service.*.id,count.index)}"
  count          = "${var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route_table" "service_public" {
  vpc_id = "${data.aws_vpc.current.id}"
  count  = "${var.az_count*signum(var.public_network)}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
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
  route_table_id = "${element(aws_route_table.service_public.*.id,count.index)}"
  count          = "${var.az_count*signum(var.public_network)}"
}

data "aws_iam_policy_document" "service" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service" {
  name               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  assume_role_policy = "${data.aws_iam_policy_document.service.json}"
}

resource "aws_iam_instance_profile" "service" {
  name  = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  roles = ["${aws_iam_role.service.name}"]
}

resource "aws_iam_group" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
}

data "template_file" "user_data_service" {
  template = "${file(var.user_data)}"

  vars {
    vpc_cidr = "${data.aws_vpc.current.cidr_block}"
  }
}

resource "aws_launch_configuration" "service" {
  name_prefix          = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}-"
  instance_type        = "${element(var.instance_type,count.index)}"
  image_id             = "${coalesce(element(var.image_id,count.index),data.terraform_remote_state.app.app_ami_id)}"
  iam_instance_profile = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  key_name             = "${data.terraform_remote_state.env.key_name}"
  user_data            = "${data.template_file.user_data_service.rendered}"
  security_groups      = ["${concat(list(data.terraform_remote_state.env.sg_env,signum(var.public_network) == 1 ?  data.terraform_remote_state.env.sg_env_public : data.terraform_remote_state.env.sg_env_private,aws_security_group.service.id),list(data.terraform_remote_state.app.app_sg))}"]
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
  name                 = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  launch_configuration = "${element(aws_launch_configuration.service.*.name,count.index)}"
  vpc_zone_identifier  = ["${aws_subnet.service.*.id}"]
  min_size             = "${element(var.min_size,count.index)}"
  max_size             = "${element(var.max_size,count.index)}"
  termination_policies = ["${var.termination_policies}"]
  count                = "${var.asg_count}"

  tag {
    key                 = "Name"
    value               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Env"
    value               = "${data.terraform_remote_state.env.env_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "App"
    value               = "${data.terraform_remote_state.app.app_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Service"
    value               = "${var.service_name}"
    propagate_at_launch = true
  }

  tag {
    key                 = "ManagedBy"
    value               = "asg ${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Color"
    value               = "${element(var.asg_name,count.index)}"
    propagate_at_launch = true
  }
}

module "fs" {
  source   = "../fs"
  fs_name  = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id   = "${data.terraform_remote_state.env.vpc_id}"
  env_name = "${data.terraform_remote_state.env.env_name}"
  subnets  = ["${aws_subnet.service.*.id}"]
  az_count = "${var.az_count}"
  want_fs  = "${var.want_fs}"
}

resource "aws_security_group_rule" "allow_service_mount" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.service.id}"
  security_group_id        = "${module.fs.efs_sg}"
  count                    = "${var.want_fs}"
}

resource "aws_route53_record" "fs" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-efs-${element(data.aws_availability_zones.azs.names,count.index)}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${element(module.fs.efs_dns_names,count.index)}"]
  count   = "${var.az_count*var.want_fs}"
}
