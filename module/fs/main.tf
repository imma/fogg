variable fs_name {}

variable az_count {}

variable subnets {
  default = []
}

variable want_fs {
  default = "1"
}

variable "vpc_id" {}

variable "env_name" {}

data "aws_vpc" "current" {
  id = "${var.vpc_id}"
}

resource "aws_security_group" "fs" {
  name        = "${var.env_name}-${var.fs_name}-efs"
  description = "Environment ${var.env_name} ${var.fs_name}"
  vpc_id      = "${data.aws_vpc.current.id}"

  tags {
    "Name"      = "${var.env_name}-${var.fs_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_fs}"
}

resource "aws_security_group_rule" "fs" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = ["${data.aws_vpc.current.cidr_block}"]
  security_group_id = "${aws_security_group.fs.id}"
  count             = "${var.want_fs}"
}

resource "aws_efs_file_system" "fs" {
  tags {
    "Name"      = "${var.env_name}-${var.fs_name}"
    "Env"       = "${var.env_name}"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_fs}"
}

resource "aws_efs_mount_target" "fs" {
  file_system_id  = "${aws_efs_file_system.fs.id}"
  subnet_id       = "${element(var.subnets,count.index)}"
  security_groups = ["${aws_security_group.fs.id}"]
  count           = "${var.az_count*var.want_fs}"
}
