terraform {
  backend "s3" {
    bucket  = "caffe-terraform"
    key     = "mail/terraform.tfstate"
    region  = "eu-central-1"
    encrypt = true

    dynamodb_table = "caffe-terraform"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.56.1"
    }
  }

  required_version = "1.7.2"
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project = "mail"
    }
  }
}
