variable "global_bucket" {}
variable "global_key" {}
variable "global_region" {}

data "terraform_remote_state" "global" {
  backend = "s3"

  config {
    bucket         = "${var.global_bucket}"
    key            = "${var.global_key}"
    region         = "${var.global_region}"
    dynamodb_table = "terraform_state_lock"
  }
}

data "aws_instance" "this" {
  filter {
    name   = "tag:Name"
    values = ["${var.instance_name}"]
  }
}

data "aws_route53_zone" "public" {
  name         = "${coalesce(var.public_zone,data.terraform_remote_state.global.domain_name)}"
  private_zone = false
}

resource "aws_eip" "this" {
  vpc   = true
  count = "${var.want_eip}"
}

resource "aws_route53_record" "public" {
  zone_id = "${data.aws_route53_zone.public.zone_id}"
  name    = "${var.public_name}.${data.aws_route53_zone.public.name}"
  type    = "A"
  ttl     = "60"
  records = ["${aws_eip.this.public_ip}"]
  count   = "${var.want_eip}"
}

resource "aws_eip_association" "this" {
  instance_id   = "${data.aws_instance.this.id}"
  allocation_id = "${aws_eip.this.id}"
  count         = "${var.want_eip}"
}

resource "aws_ebs_volume" "this" {
  availability_zone = "${data.aws_instance.this.availability_zone}"
  size              = 2
  count             = "${var.ebs_count}"
}

resource "aws_volume_attachment" "this" {
  device_name = "${var.devices[count.index]}"
  volume_id   = "${aws_ebs_volume.this.*.id[count.index]}"
  instance_id = "${data.aws_instance.this.id}"
  count       = "${var.ebs_count}"
}
