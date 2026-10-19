# Generado por scripts/new-client.sh (patrón del plan 1.5 y ADR 0002). Un backend no admite variables:
# los valores son literales. El bucket y la clave KMS los crea live/_bootstrap/sandbox-dev (runbook bootstrap).
terraform {
  backend "s3" {
    bucket       = "e2e-dev-tfstate-654654616677"
    key          = "dev/bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    kms_key_id   = "alias/e2e-dev-state"
    use_lockfile = true
  }

  # Cifrado del estado y de los planes en el cliente (exclusivo de OpenTofu): el objeto en S3 no es legible
  # sin la CMK de estado, además del SSE-KMS del bucket.
  encryption {
    key_provider "aws_kms" "state" {
      kms_key_id = "alias/e2e-dev-state"
      region     = "us-east-1"
      key_spec   = "AES_256"
    }

    method "aes_gcm" "state" {
      keys = key_provider.aws_kms.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}
