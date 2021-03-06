provider "aws" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region     = "${var.region}"
}

resource "aws_key_pair" "deployer" {
  count = "${var.public_key != "" ? 1 : 0}"
  key_name   = "deployer-key"
  public_key = "${var.public_key}"
}

# Declare the data source
data "aws_availability_zones" "available" {}

#All the stuff, high level
# redis module
# lambda autoscaling module
# dcc asg module
# s3 bucket

#VPC
module "vpc" {
  enabled = "${var.single_node ? 0 : 1}"
  source = "github.com/terraform-aws-modules/terraform-aws-vpc?ref=master"

  name = "dcc-vpc"
  cidr = "10.0.0.0/16"

  #TODO: parameterize this for the multi-zone params
  azs  = ["${data.aws_availability_zones.available.names[0]}"]

  create_database_subnet_group = false

  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]
  enable_nat_gateway = true
  enable_vpn_gateway = true
  single_nat_gateway = true

  tags = {
    Terraform = "true"
    Environment = "dev"
    System = "dcc"
  }
}

#S3 bucket
module "s3" {
  enabled = "${var.s3 ? 1 : 0}"
  source      = "../s3_bucket"
  access_key  = "${var.access_key}"
  secret_key  = "${var.secret_key}"
  region      = "${var.region}"
  bucket_name = "${var.bucket_name}"
  #TODO: we can get rid of the user?
  user        = "${var.user}"
}

#Redis
module "redis" {
  enabled = "${var.single_node ? 0 : 1}"
  source  = "../redis/minimal"
  region = "${var.region}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.public_subnets[0]}"
  key_name = "${aws_key_pair.deployer.key_name}"
  instance_type = "t2.micro"
}

# Autoscaling Group
module "asg" {
  enabled = "${var.single_node ? 0 : 1}"
  source  = "../asg"
  # Verify this
  redis_security_group_id = "${module.redis.security_group_id}"
  key_name = "${aws_key_pair.deployer.key_name}"
  vpc_id = "${module.vpc.vpc_id}"
  subnets = ["${concat("${module.vpc.public_subnets}")}"]
  instance_type = "${var.worker_type}"
  region = "${var.region}"
  redis_host = "${module.redis.hostname}"
  fluent_host = "${module.elk.hostname}"
  s3_access_key = "${var.access_key}"
  s3_secret_key = "${var.secret_key}"
  s3_region     = "${var.region}"
  s3_bucket     = "${module.s3.bucket_name}"
  version       = "${var.version}"
}

#Lambda scaling
module "lambda" {
  enabled = "${var.single_node ? 0 : 1}"
  source  = "../lambdas"
  subnet_ids = ["${concat("${module.vpc.public_subnets}", "${module.vpc.private_subnets}")}"]
  security_group_ids = ["${module.redis.security_group_id}"]
  redis_host = "${module.redis.hostname}"
  asg_name = "${module.asg.name}"
}

#ELK stack (logging)
module "elk" {
  enabled = "${var.single_node ? 0 : 1}"
  source  = "../elasticsearch-fluent-kibana-minimal"
  region = "${var.region}"
  vpc_id = "${module.vpc.vpc_id}"
  subnet_id = "${module.vpc.public_subnets[0]}"
  key_name = "${aws_key_pair.deployer.key_name}"
  instance_type = "t2.micro"
}

output "url" {
  value = "${module.asg.url}"
}