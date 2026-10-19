# Composición: versiones fijadas (plan 3.2, ADR 0001). El .terraform.lock.hcl de este directorio se versiona
# (scripts/lock-providers.sh, hashes para linux_amd64, linux_arm64 y darwin_arm64).
terraform {
  required_version = "~> 1.11.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.30"
    }
  }
}
