variable "consul_dc" {
  default = "dc1"
}

provider "consul" {
  datacenter = "${var.consul_dc}"
}

provider "aws" {}

provider "aws" {
  alias  = "us_west_1"
  region = "us-west-1"
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
