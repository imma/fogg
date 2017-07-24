variable "global_bucket" {}
variable "global_key" {}
variable "global_region" {}

variable "env_bucket" {}
variable "env_key" {}
variable "env_region" {}

variable "app_bucket" {}
variable "app_key" {}
variable "app_region" {}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

data "terraform_remote_state" "org" {
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

  cidr_block              = "${cidrsubnet(data.aws_vpc.current.cidr_block,var.service_bits,element(concat(split(" ",lookup(data.terraform_remote_state.org.org,"service_${data.terraform_remote_state.app.app_name}_${var.service_name}","")),split(" ",lookup(data.terraform_remote_state.org.org,"service_${var.service_name}",""))),count.index))}"
  map_public_ip_on_launch = "${signum(var.public_network) == 1 ? "true" : "false"}"

  #ipv6_cidr_block                 = "${cidrsubnet(data.aws_vpc.current.ipv6_cidr_block,64,element(concat(split(" ",lookup(data.terraform_remote_state.org.org,"service_v6_${data.terraform_remote_state.app.app_name}_${var.service_name}","")),split(" ",lookup(data.terraform_remote_state.org.org,"service_v_${var.service_name}",""))),count.index))}"
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

resource "aws_route_table_association" "service" {
  subnet_id      = "${element(aws_subnet.service.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.service.*.id,count.index)}"
  count          = "${var.az_count*(signum(var.public_network)-1)*-1}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_service" {
  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.service.*.id,count.index)}"
  count           = "${var.az_count*(signum(var.public_network)-1)*-1}"
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

resource "aws_route_table_association" "service_public" {
  subnet_id      = "${element(aws_subnet.service.*.id,count.index)}"
  route_table_id = "${element(aws_route_table.service_public.*.id,count.index)}"
  count          = "${var.az_count*signum(var.public_network)}"
}

resource "aws_vpc_endpoint_route_table_association" "s3_service_public" {
  vpc_endpoint_id = "${aws_vpc_endpoint.s3.id}"
  route_table_id  = "${element(aws_route_table.service_public.*.id,count.index)}"
  count           = "${var.az_count*signum(var.public_network)}"
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

  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service" {
  name               = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  assume_role_policy = "${data.aws_iam_policy_document.service.json}"
}

resource "aws_iam_role_policy_attachment" "ecr_ro" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "ecs" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_role_policy_attachment" "ecs-container" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

resource "aws_iam_role_policy_attachment" "cc_ro" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AWSCodeCommitReadOnly"
}

resource "aws_iam_role_policy_attachment" "ssm-agent" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

resource "aws_iam_role_policy_attachment" "ssm-ro" {
  role       = "${aws_iam_role.service.name}"
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

resource "aws_iam_instance_profile" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  role = "${aws_iam_role.service.name}"
}

resource "aws_iam_group" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
}

data "template_file" "user_data_service" {
  template = "${file(var.user_data)}"

  vars {
    vpc_cidr = "${data.aws_vpc.current.cidr_block}"
    env      = "${data.terraform_remote_state.env.env_name}"
    app      = "${data.terraform_remote_state.app.app_name}"
    service  = "${var.service_name}"
  }
}

data "aws_ami" "block" {
  most_recent = true

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "tag:Block"
    values = ["${var.block}-*"]
  }

  owners = ["self"]
}

resource "aws_launch_configuration" "service" {
  name_prefix          = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}-"
  instance_type        = "${element(var.instance_type,count.index)}"
  image_id             = "${coalesce(element(var.ami_id,count.index),data.aws_ami.block.image_id)}"
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

resource "aws_ses_domain_identity" "service" {
  provider = "aws.us_east_1"
  domain   = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"
}

resource "aws_ses_receipt_rule" "s3" {
  provider      = "aws.us_east_1"
  name          = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}-s3"
  rule_set_name = "${data.terraform_remote_state.org.domain_name}"
  recipients    = ["${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"]
  enabled       = true
  scan_enabled  = true
  tls_policy    = "Require"

  s3_action {
    bucket_name       = "${data.terraform_remote_state.env.s3_env_ses}"
    object_key_prefix = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"
    topic_arn         = "${aws_sns_topic.ses.arn}"
    position          = 1
  }
}

resource "aws_route53_record" "verify_ses" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "_amazonses.${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "TXT"
  ttl     = "60"
  records = ["${aws_ses_domain_identity.service.verification_token}"]
}

resource "aws_route53_record" "mx" {
  zone_id = "${data.terraform_remote_state.org.public_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "MX"
  ttl     = "60"
  records = ["10 inbound-smtp.${var.env_region}.amazonaws.com"]
}

resource "aws_security_group" "lb" {
  name        = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-lb"
  description = "LB ${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id      = "${data.aws_vpc.current.id}"
  count       = "${signum(var.want_elb + var.want_alb)}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-lb"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}-lb"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_security_group_rule" "lb_to_service" {
  type                     = "ingress"
  from_port                = 32768
  to_port                  = 65535
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.lb.id}"
  security_group_id        = "${aws_security_group.service.id}"
  count                    = "${signum(var.want_elb + var.want_alb)}"
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
    target              = "TCP:8888"
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

data "aws_acm_certificate" "service" {
  domain   = "${(var.want_alb*var.asg_count) == 0 ? "${data.terraform_remote_state.org.default_acm}" : "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"}"
  statuses = ["ISSUED"]
}

resource "aws_alb" "service" {
  name    = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  count   = "${var.want_alb*var.asg_count}"
  subnets = ["${split(" ",var.public_lb ? join(" ",data.terraform_remote_state.env.public_subnets) : join(" ",aws_subnet.service.*.id))}"]

  security_groups = [
    "${data.terraform_remote_state.env.sg_env_lb}",
    "${var.public_lb ? data.terraform_remote_state.env.sg_env_lb_public : data.terraform_remote_state.env.sg_env_lb_private}",
    "${aws_security_group.lb.*.id}",
  ]

  internal = "${var.public_lb == 0 ? true : false}"

  idle_timeout = 400

  tags {
    Name      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
    Env       = "${data.terraform_remote_state.env.env_name}"
    App       = "${data.terraform_remote_state.app.app_name}"
    Service   = "${var.service_name}"
    ManagedBy = "terraform"
    Color     = "${element(var.asg_name,count.index)}"
  }
}

resource "aws_alb_listener" "service" {
  count             = "${var.want_alb*var.asg_count}"
  load_balancer_arn = "${element(aws_alb.service.*.arn,count.index)}"
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2015-05"
  certificate_arn   = "${data.aws_acm_certificate.service.arn}"

  default_action {
    target_group_arn = "${element(aws_alb_target_group.service.*.arn,count.index)}"
    type             = "forward"
  }
}

resource "aws_alb_listener_rule" "service" {
  count        = "${var.want_alb*var.asg_count}"
  listener_arn = "${element(aws_alb_listener.service.*.arn,count.index)}"
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = "${element(aws_alb_target_group.service.*.arn,count.index)}"
  }

  condition {
    field  = "path-pattern"
    values = ["/*"]
  }
}

resource "aws_alb_target_group" "service" {
  name     = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  count    = "${var.want_alb*var.asg_count}"
  port     = 8888
  protocol = "HTTP"
  vpc_id   = "${data.aws_vpc.current.id}"
}

resource "aws_route53_record" "service" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}-${element(var.asg_name,count.index)}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(concat(aws_alb.service.*.dns_name,aws_elb.service.*.dns_name),count.index)}"
    zone_id                = "${element(concat(aws_alb.service.*.zone_id,aws_elb.service.*.zone_id),count.index)}"
    evaluate_target_health = false
  }

  count = "${var.asg_count*signum(var.want_elb+var.want_alb)}"
}

resource "aws_route53_record" "service_live" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(concat(aws_alb.service.*.dns_name,aws_elb.service.*.dns_name),0)}"
    zone_id                = "${element(concat(aws_alb.service.*.zone_id,aws_elb.service.*.zone_id),0)}"
    evaluate_target_health = false
  }

  count = "${signum(var.want_elb+var.want_alb)}"
}

resource "aws_route53_record" "service_staging" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}${var.service_default == "1" ? "" : "-${var.service_name}"}-staging.${data.terraform_remote_state.env.private_zone_name}"
  type    = "A"

  alias {
    name                   = "${element(concat(aws_alb.service.*.dns_name,aws_elb.service.*.dns_name),1)}"
    zone_id                = "${element(concat(aws_alb.service.*.zone_id,aws_elb.service.*.zone_id),1)}"
    evaluate_target_health = false
  }

  count = "${signum(var.asg_count - 1)*signum(var.want_elb+var.want_alb)}"
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
      "arn:aws:sqs:${var.env_region}:${data.terraform_remote_state.org.aws_account_id}:${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}",
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

resource "aws_sns_topic" "ses" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-ses"
}

resource "aws_sqs_queue" "ses" {
  name   = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-ses"
  policy = "${element(data.aws_iam_policy_document.service-sns-sqs-ses.*.json,count.index)}"
}

data "aws_iam_policy_document" "service-sns-sqs-ses" {
  statement {
    actions = [
      "sqs:SendMessage",
    ]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    resources = [
      "arn:aws:sqs:${var.env_region}:${data.terraform_remote_state.org.aws_account_id}:${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-ses",
    ]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"

      values = [
        "${element(aws_sns_topic.ses.*.arn,count.index)}",
      ]
    }
  }
}

resource "aws_sns_topic_subscription" "ses" {
  topic_arn = "${element(aws_sns_topic.ses.*.arn,count.index)}"
  endpoint  = "${element(aws_sqs_queue.ses.*.arn,count.index)}"
  protocol  = "sqs"
}

resource "aws_ecs_cluster" "service" {
  name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
}

resource "aws_autoscaling_group" "service" {
  name                 = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}-${element(var.asg_name,count.index)}"
  launch_configuration = "${element(aws_launch_configuration.service.*.name,count.index)}"
  vpc_zone_identifier  = ["${aws_subnet.service.*.id}"]
  min_size             = "${element(var.min_size,count.index)}"
  max_size             = "${element(var.max_size,count.index)}"
  termination_policies = ["${var.termination_policies}"]
  count                = "${var.asg_count}"

  load_balancers    = ["${compact(list(element(concat(aws_elb.service.*.name,list("","")),count.index)))}"]
  target_group_arns = ["${compact(list(element(concat(aws_alb_target_group.service.*.arn,list("","")),count.index)))}"]

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

module "efs" {
  source   = "../efs"
  efs_name = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  vpc_id   = "${data.terraform_remote_state.env.vpc_id}"
  env_name = "${data.terraform_remote_state.env.env_name}"
  subnets  = ["${aws_subnet.service.*.id}"]
  az_count = "${var.az_count}"
  want_efs = "${var.want_efs}"
}

resource "aws_security_group_rule" "allow_service_mount" {
  type                     = "ingress"
  from_port                = 2049
  to_port                  = 2049
  protocol                 = "tcp"
  source_security_group_id = "${aws_security_group.service.id}"
  security_group_id        = "${module.efs.efs_sg}"
  count                    = "${var.want_efs}"
}

resource "aws_route53_record" "efs" {
  zone_id = "${data.terraform_remote_state.env.private_zone_id}"
  name    = "${data.terraform_remote_state.app.app_name}-${var.service_name}-efs.${data.terraform_remote_state.env.private_zone_name}"
  type    = "CNAME"
  ttl     = "60"
  records = ["${element(module.efs.efs_dns_names,count.index)}"]
  count   = "${var.want_efs}"
}

resource "aws_kms_key" "service" {
  description         = "Service ${var.service_name}"
  enable_key_rotation = true

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "App"       = "${data.terraform_remote_state.app.app_name}"
    "Service"   = "${var.service_name}"
    "ManagedBy" = "terraform"
  }
}

resource "aws_kms_alias" "service" {
  name          = "alias/${data.terraform_remote_state.env.env_name}-${data.terraform_remote_state.app.app_name}-${var.service_name}"
  target_key_id = "${aws_kms_key.service.id}"
}
