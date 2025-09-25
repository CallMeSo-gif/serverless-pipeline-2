terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.13.0"

    }

    archive = {
      source = "hashicorp/archive"
      version = "2.7.1"
    }
  }
}


provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project = "CSV-to-Parquet"
      Owner   = "Sorelle Kana"
      GitRepo = "https://github.com/CallMeSo-gif/serveless-pipeline.git"
    }
  }
}
