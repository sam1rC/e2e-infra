terraform {
  required_version = ">= 1.11.0"

  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = ">= 6.30, < 7.0"
      configuration_aliases = [aws.dr]
    }
  }
}
