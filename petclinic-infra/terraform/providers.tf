terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.17.0"
    }
  }

  backend "s3" {
    bucket  = "terraform-state-petclinic-798974632222"
    key     = "petclinic-state/terraform.tfstate"
    region  = "eu-north-1"
    encrypt = true

  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = {
      Project = "PetClinic"
    }
  }
}