variable "aws_region" {
  default = "us-east-1"
}

provider "aws" {
  region = var.aws_region
}


variable "public_key_path" {}
variable "private_key_path" {}


module "vpc" {
  source = "github.com/insight-infrastructure/terraform-aws-default-vpc.git?ref=v0.1.0"
}

resource "aws_security_group" "this" {
  vpc_id = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = [
      22,
      80,
      443,
      3000,
      7100,
      9000,
      9090,
      9093,
    9094]
    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "tcp"
      cidr_blocks = [
      "0.0.0.0/0"]
    }
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
    "0.0.0.0/0"]
  }
}

module "defaults" {
  source    = "../.."
  subnet_id = module.vpc.public_subnets[0]

  vpc_security_group_ids = [
  aws_security_group.this.id]

  ebs_volume_size  = 20
  public_key_path  = var.public_key_path
  private_key_path = var.private_key_path

  playbook_vars_file = "${path.cwd}/../../configs/vars.yaml"
}

variable "keystore_name" {
  type    = string
  default = ""
}

locals {
  keystore_path = var.keystore_name == "" ? "${path.cwd}/../../test/fixtures/keystore" : "${path.cwd}/../../test/fixtures/${var.keystore_name}}"
}

module "registration" {
  source       = "github.com/insight-infrastructure/terraform-aws-icon-registration.git?ref=v0.1.0"
  network_name = "testnet"

  organization_name    = "Insight-CI1"
  organization_country = "USA"
  organization_email   = "fake@gmail.com"
  organization_city    = "CircleCI"
  organization_website = "https://google.com"

  keystore_password = "testing1."
  keystore_path     = local.keystore_path
}

module "prep" {
  source = "https://github.com/insight-icon/terraform-icon-aws-prep.git"

  minimum_specs = true

  public_ip = module.registration.public_ip

  private_key_path = var.private_key_path
  public_key_path  = var.public_key_path

  subnet_id              = module.vpc.subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.this.id]

  keystore_path     = local.keystore_path
  keystore_password = "testing1."
}