

provider "aws" {
  region = "us-east-1" 
}

module "vpc" {
  source          = "./modules/vpc"
  vpc_cidr        = "10.0.0.0/16"
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]
  azs             = ["us-east-1a", "us-east-1b"]
}

module "security" {
  source   = "./modules/security"
  vpc_id   = module.vpc.vpc_id
  admin_ip = "192.168.1.100/32" 
}

module "compute" {
  source             = "./modules/compute"
  instance_count     = 2
  ami_id             = "ami-0ecb62995f68bb549" 
  instance_type      = "t2.micro"
  subnet_ids         = module.vpc.private_subnet_ids
  security_group_ids = [module.security.ec2_sg_id]
}

module "alb" {
  source              = "./modules/alb"
  vpc_id              = module.vpc.vpc_id
  public_subnet_ids   = module.vpc.public_subnet_ids
  security_group_ids  = [module.security.alb_sg_id]
  target_instance_ids = module.compute.instance_ids 
  acm_certificate_arn = "arn:aws:acm:us-east-1:546454332581:certificate/4246b474-cbd6-4513-a2be-15d4268bd13f"
}

output "application_url" {
  value = "https://${module.alb.alb_dns_name}"
}