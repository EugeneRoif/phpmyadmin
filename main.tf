provider "aws" {
  region = local.region
}

locals {
  name           = "exam"
  region         = "eu-west-3"
  public_subnets = ["10.99.0.0/24", "10.99.1.0/24", "10.99.2.0/24"]

  key_name = "aws_key"

  domain   = "db.qmarkets.dev"
  ssh_key  = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDbg8XJFKPUicyjHj8ZdhOQVf2+5G136Dty0CO/iZU+qEP6rqqev2Ju1agTdMI87VYUVe9IPXN4vsOFcZsh6ehBzXDl8vGOoteysnAUkV3oki6dkYsNb4Im3YnPZTr9m32ZhTbs4DAZrFn04s81MSn8JJpm/ec3d3S3k8G57sl1Yw8n1BTr2HIYjECBeia0rn28jBLog09ewNnOGRJ4wf0fgI7kG5mJsOMAIEsbotTnTv9XD1kJz7hVWVn7xlRJjw9Avib4kWPwzCblVy52BF0M4+87W2PmxpIluF/P5rFiDMrsQUBsJUQ5DCY3esBkB9ZaLRJJRON26R4cf0+WjO0kwwBW171GwpFTyjpy2QS92vEPdn6Pk9Feyw2XinOCjulzsOq+PVL0LLBjHnWZ3EprQhERHHsPq5QCiNFys3AhTOir5iD2Wi12422ghGYkrbggMbE6d1aLJC6O8J6Ho2ngh1MB+a3h/0BYvgXD62dLf53sAxclkzxZ2PmBBvnj6jM= eugene@Terminal11"
  cidr     = "10.99.0.0/18"
  tls_key  = "CA/server-key.pem"
  tls_cert = "CA/server.pem"

  cert_id = data.aws_acm_certificate.issued.id
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 3.0"

  name = local.name
  cidr = local.cidr

  azs            = ["${local.region}a", "${local.region}b", "${local.region}c"]
  public_subnets = local.public_subnets
}

module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Security group for LoadBalancer"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["https-443-tcp"]
  egress_rules        = ["all-all"]
}


module "webservers" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = local.name
  description = "Security group for web servers"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["http-80-tcp"]
  egress_rules        = ["all-all"]
}

module "SSH" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 4.0"

  name        = "SSH"
  description = "Security group for example usage with EC2 instance"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = ["0.0.0.0/0"]
  ingress_rules       = ["ssh-tcp"]
  egress_rules        = ["all-all"]
}

module "db" {
  source = "terraform-aws-modules/security-group/aws"

  name        = "main-sg"
  description = "Security group for db"
  vpc_id      = module.vpc.vpc_id

  ingress_cidr_blocks = local.public_subnets
  ingress_rules       = ["mysql-tcp"]
}


data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-*-20.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

module "keypair" {
  source     = "terraform-aws-modules/key-pair/aws"
  key_name   = local.key_name
  public_key = local.ssh_key
}

module "create_web_instances" {
  for_each               = toset(["web1", "web2"])
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = each.key
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.small"
  subnet_id              = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids = [module.SSH.security_group_id, module.webservers.security_group_id]
  key_name               = local.key_name
}


module "create_db_instances" {
  for_each               = toset(["db"])
  source                 = "terraform-aws-modules/ec2-instance/aws"
  name                   = each.key
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.small"
  subnet_id              = element(module.vpc.public_subnets, 0)
  vpc_security_group_ids = [module.db.security_group_id, module.SSH.security_group_id]
  key_name               = local.key_name
}

resource "aws_acm_certificate" "dev-cert" {
  private_key      = file(local.tls_key)
  certificate_body = file(local.tls_cert)
}


data "aws_acm_certificate" "issued" {
  domain      = local.domain
  most_recent = true
  depends_on  = [aws_acm_certificate.dev-cert]
}

module "elb" {
  source = "terraform-aws-modules/elb/aws"
  name   = "elb-demo"

  subnets         = module.vpc.public_subnets
  security_groups = [module.security_group.security_group_id]
  internal        = false

  listener = [
    {
      instance_port     = "80"
      instance_protocol = "http"
      lb_port           = "443"
      lb_protocol       = "https"

      ssl_certificate_id = local.cert_id
    }
  ]

  health_check = {
    target              = "HTTP:80/"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
  }

  number_of_instances = length([for o in module.create_web_instances : o.id])
  instances           = [for o in module.create_web_instances : o.id]
}

resource "aws_lb_cookie_stickiness_policy" "sticky" {
  name                     = "foo-policy"
  load_balancer            = module.elb.elb_id
  lb_port                  = 443
  cookie_expiration_period = 600
}
