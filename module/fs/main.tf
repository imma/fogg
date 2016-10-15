variable env_remote_state {}

variable fs_name {}

variable az_count {}

variable subnets {
  default = []
}

variable want_fs {
  default = "1"
}

data "terraform_remote_state" "env" {
  backend = "local"

  config {
    path = "${var.env_remote_state}"
  }
}

resource "aws_security_group" "fs" {
  name        = "${data.terraform_remote_state.env.env_name}-${var.fs_name}-efs"
  description = "Environment ${data.terraform_remote_state.env.env_name} ${var.fs_name}"
  vpc_id      = "${data.terraform_remote_state.env.vpc_id}"

  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name} ${var.fs_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
    "ManagedBy" = "terraform"
  }

  count = "${var.want_fs}"
}

resource "aws_security_group_rule" "fs" {
  type              = "ingress"
  from_port         = 2049
  to_port           = 2049
  protocol          = "tcp"
  cidr_blocks       = ["${data.terraform_remote_state.env.env_cidr}"]
  security_group_id = "${aws_security_group.fs.id}"
  count             = "${var.want_fs}"
}

resource "aws_efs_file_system" "fs" {
  tags {
    "Name"      = "${data.terraform_remote_state.env.env_name} ${var.fs_name}"
    "Env"       = "${data.terraform_remote_state.env.env_name}"
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
