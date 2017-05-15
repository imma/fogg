variable "global_bucket" {}
variable "global_key" {}
variable "global_region" {}

variable "env_bucket" {}
variable "env_key" {}
variable "env_region" {}

variable "app_bucket" {}
variable "app_key" {}
variable "app_region" {}

data "terraform_remote_state" "global" {
  backend = "s3"

  config {
    bucket     = "${var.global_bucket}"
    key        = "${var.global_key}"
    region     = "${var.global_region}"
    lock_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "env" {
  backend = "s3"

  config {
    bucket     = "${var.env_bucket}"
    key        = "${var.env_key}"
    region     = "${var.env_region}"
    lock_table = "terraform_state_lock"
  }
}

data "terraform_remote_state" "app" {
  backend = "s3"

  config {
    bucket     = "${var.app_bucket}"
    key        = "${var.app_key}"
    region     = "${var.app_region}"
    lock_table = "terraform_state_lock"
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

resource "aws_subnet" "service" {
  vpc_id = "${data.aws_vpc.current.id}"

  availability_zone = "${element(data.aws_availability_zones.azs.names,count.index)}"

  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.service_bits,element(concat(split(" ",lookup(data.terraform_remote_state.global.org,"service_${data.terraform_remote_state.app.app_name}_${var.service_name}","")),split(" ",lookup(data.terraform_remote_state.global.org,"service_${var.service_name}",""))),count.index))}"
  map_public_ip_on_launch = "${signum(var.public_network) == 1 ? "true" : "false"}"

  #ipv6_cidr_block                 = "${cidrsubnet(data.aws_vpc.current.ipv6_cidr_block,64,element(concat(split(" ",lookup(data.terraform_remote_state.global.org,"service_v6_${data.terraform_remote_state.app.app_name}_${var.service_name}","")),split(" ",lookup(data.terraform_remote_state.global.org,"service_v_${var.service_name}",""))),count.index))}"
  assign_ipv6_address_on_creation = "${var.want_ipv6 ? "true" : "false"}"

  count = "${var.az_count}"

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

resource "aws_route" "service_v6" {
  route_table_id              = "${element(aws_route_table.service.*.id,count.index)}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${data.terraform_remote_state.env.egw_gateway}"
  count                       = "${var.want_ipv6*var.want_nat*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_peering" {
  route_table_id            = "${element(aws_route_table.service.*.id,count.index%var.az_count)}"
  destination_cidr_block    = "${lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}_cidr_${element(split(" ",lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}")),count.index/var.az_count)}")}"
  vpc_peering_connection_id = "${lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}_pcx_${element(split(" ",lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}")),count.index/var.az_count)}")}"
  count                     = "${var.az_count*var.peer_count*(signum(var.public_network)-1)*-1}"
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

resource "aws_route" "service_public_v6" {
  route_table_id              = "${element(aws_route_table.service_public.*.id,count.index)}"
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = "${data.terraform_remote_state.env.egw_id}"
  count                       = "${var.want_ipv6*var.want_nat*var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_route" "service_peering_public" {
  route_table_id            = "${element(aws_route_table.service_public.*.id,count.index%var.az_count)}"
  destination_cidr_block    = "${lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}_cidr_${element(split(" ",lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}")),count.index/var.az_count)}")}"
  vpc_peering_connection_id = "${lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}_pcx_${element(split(" ",lookup(data.terraform_remote_state.global.org,"peering_${data.terraform_remote_state.env.env_name}")),count.index/var.az_count)}")}"
  count                     = "${var.az_count*var.peer_count*signum(var.public_network)}"
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
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  role = "${element(concat(data.terraform_remote_state.env.iam_extra,list(aws_iam_role.service.name)),0)}"
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

resource "aws_eip" "service" {
  vpc   = true
  count = "${var.want_eip}"
}

resource "aws_launch_configuration" "service" {
  name_prefix          = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}-"
  instance_type        = "${element(var.instance_type,count.index)}"
  image_id             = "${coalesce(element(var.ami_id,count.index),data.terraform_remote_state.env.env_ami_id)}"
  iam_instance_profile = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  key_name             = "${data.terraform_remote_state.env.key_name}"
  user_data            = "${data.template_file.user_data_service.rendered}"
  security_groups      = ["${concat(data.terraform_remote_state.env.sg_extra,list(data.terraform_remote_state.env.sg_env,signum(var.public_network) == 1 ?  data.terraform_remote_state.env.sg_env_public : data.terraform_remote_state.env.sg_env_private,aws_security_group.service.id),list(data.terraform_remote_state.app.app_sg))}"]
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

resource "aws_security_group" "lb" {
  name        = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-lb"
  description = "LB ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"
  count       = "${var.want_elb ? 1 : 0 }"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-lb"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}-lb"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_elb" "service" {
  name    = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  count   = "${var.want_elb*var.asg_count}"
  subnets = ["${split(" ",var.public_lb ? join(" ",data.terraform_remote_state.env.public_subnets) : join(" ",aws_subnet.service.*.id))}"]

  security_groups = [
    "${data.terraform_remote_state.env.sg_env_lb}",
    "${var.public_lb ? data.terraform_remote_state.env.sg_env_lb_public : data.terraform_remote_state.env.sg_env_lb_private}",
    "${aws_security_group.lb.*.id}",
  ]

  internal = "${var.public_lb == 0 ? true : false}"

  access_logs {
    bucket        = "${data.terraform_remote_state.env.s3_env_lb}"
    bucket_prefix = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    interval      = 60
  }

  listener {
    instance_port     = 80
    instance_protocol = "tcp"
    lb_port           = 80
    lb_protocol       = "tcp"
  }

  listener {
    instance_port     = 443
    instance_protocol = "tcp"
    lb_port           = 443
    lb_protocol       = "tcp"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "TCP:80"
    interval            = 30
  }

  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 60

  tags {
    Name      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    Env       = "${data.terraform_remote_state.env.env_name}"
    App       = "${data.terraform_remote_state.app.app_name}"
    Service   = "${var.service_name}"
    ManagedBy = "terraform"
    Color     = "${element(var.asg_name,count.index)}"
  }
}

resource "aws_route53_record" "service" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(aws_elb.service.*.dns_name,count.index)}"
    zone_id                = "${element(aws_elb.service.*.zone_id,count.index)}"
    evaluate_target_health = false
  }

  count = "${var.asg_count*var.want_elb}"
}

resource "aws_route53_record" "service-eip" {
  zone_id = "${data.terraform_remote_state.global.public_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.global.domain_name}"
  type    = "A"
  ttl     = 60
  records = ["${element(aws_eip.service.*.public_ip,count.index)}"]

  count = "${var.want_eip}"
}

resource "aws_route53_record" "service-live" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(aws_elb.service.*.dns_name,0)}"
    zone_id                = "${element(aws_elb.service.*.zone_id,0)}"
    evaluate_target_health = false
  }

  count = "${var.want_elb}"
}

resource "aws_route53_record" "service-staging" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}-staging.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(aws_elb.service.*.dns_name,1)}"
    zone_id                = "${element(aws_elb.service.*.zone_id,1)}"
    evaluate_target_health = false
  }

  count = "${var.want_elb}"
}

resource "aws_sns_topic" "service" {
  name  = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  count = "${var.asg_count}"
}

resource "aws_sqs_queue" "service" {
  name   = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  policy = "${element(data.aws_iam_policy_document.service-sns-sqs.*.json,count.index)}"
  count  = "${var.asg_count}"
}

data "aws_iam_policy_document" "service-sns-sqs" {
  statement {
    actions = [
      "sqs:SendMessage",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:sqs:${var.env_region}:${data.terraform_remote_state.global.aws_account_id}:${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        "${element(aws_sns_topic.service.*.arn,count.index)}",
      ]
    }
  }

  count = "${var.asg_count}"
}

resource "aws_sns_topic_subscription" "service" {
  topic_arn = "${element(aws_sns_topic.service.*.arn,count.index)}"
  endpoint  = "${element(aws_sqs_queue.service.*.arn,count.index)}"
  protocol  = "sqs"
  count     = "${var.asg_count}"
}

resource "aws_autoscaling_group" "service" {
  name                 = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  launch_configuration = "${element(aws_launch_configuration.service.*.name,count.index)}"
  vpc_zone_identifier  = ["${aws_subnet.service.*.id}"]
  min_size             = "${element(var.min_size,count.index)}"
  max_size             = "${element(var.max_size,count.index)}"
  termination_policies = ["${var.termination_policies}"]
  count                = "${var.asg_count}"

  load_balancers = ["${compact(list(element(concat(aws_elb.service.*.name,list("","")),count.index)))}"]

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

resource "aws_autoscaling_notification" "service" {
  topic_arn = "${element(aws_sns_topic.service.*.arn,count.index)}"

  group_names = [
    "${element(aws_autoscaling_group.service.*.name,count.index)}",
  ]

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]

  count = "${var.asg_count}"
}

data "external" "asg_instance" {
  program = [
    "${path.module}/script/asg-first-instance",
    "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,0)}",
    "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,1)}",
  ]
}

resource "aws_eip_association" "service" {
  instance_id   = "${lookup(data.external.asg_instance.result,"${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}")}"
  allocation_id = "${element(aws_eip.service.*.id,count.index)}"
  count         = "${var.want_eip}"
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
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-efs.${data.terraform_remote_state.env.private_zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${element(module.fs.efs_dns_names,count.index)}"]
  count   = "${var.want_fs}"
}
