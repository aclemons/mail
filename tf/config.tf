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
      version = "5.20.0"
    }
  }

  required_version = "1.6.0"
}

provider "aws" {
  region = "eu-central-1"

  default_tags {
    tags = {
      Project = "mail"
    }
  }
}
