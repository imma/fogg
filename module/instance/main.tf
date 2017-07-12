data "aws_instance" "this" {
  instance_id = "${var.instance_id}"
}

resource "aws_eip" "this" {
  vpc   = true
  count = "${var.want_eip}"
}

resource "aws_eip_association" "this" {
  instance_id   = "${var.instance_id}"
  allocation_id = "${aws_eip.this.id}"
  count         = "${var.want_eip}"
}

resource "aws_ebs_volume" "this" {
  availability_zone = "${data.aws_instance.this.availability_zone}"
  size              = 2
  count             = "${var.ebs_count}"
}

resource "aws_volume_attachment" "this" {
  device_name = "${element(var.devices,count.index)}"
  volume_id   = "${element(aws_ebs_volume.this.*.id,count.index)}"
  instance_id = "${var.instance_id}"
  count       = "${var.ebs_count}"
}
