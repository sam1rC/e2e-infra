output "bucket_id" {
  description = "Nombre del bucket de estado."
  value       = module.bucket.bucket_id
}

output "bucket_arn" {
  description = "ARN del bucket de estado."
  value       = module.bucket.bucket_arn
}

output "kms_key_arn" {
  description = "ARN de la CMK de estado."
  value       = module.kms.key_arn
}

output "kms_alias_name" {
  description = "Alias de la CMK de estado."
  value       = module.kms.alias_name
}

output "backend_config" {
  description = "Bloque terraform { backend + encryption } sugerido para backend.tf (sustituye <layer>)."
  value       = <<-EOT
    terraform {
      backend "s3" {
        bucket       = "${local.bucket_name}"
        key          = "${var.environment}/<layer>/terraform.tfstate"
        region       = "${local.region}"
        encrypt      = true
        kms_key_id   = "${module.kms.alias_name}"
        use_lockfile = true
      }

      encryption {
        key_provider "aws_kms" "state" {
          kms_key_id = "${module.kms.alias_name}"
          region     = "${local.region}"
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
  EOT
}
