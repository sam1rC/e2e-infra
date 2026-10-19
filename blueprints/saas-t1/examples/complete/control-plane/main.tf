locals {
  project = "ct-${var.name_suffix}"

  tags = {
    Project            = local.project
    Environment        = "test"
    Owner              = "platform"
    ManagedBy          = "opentofu"
    Blueprint          = "saas-t1"
    CostCenter         = "catalog-test"
    DataClassification = "internal"
    TTL                = "4h"
    RunId              = var.run_id
  }
}

provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  default_tags {
    tags = local.tags
  }
}

# Zip de tests/fixtures/lambda-origin-verify/app.py: solo sirve para que la función exista.
module "artifacts" {
  source = "../../../../../modules/storage/s3-bucket"

  project       = local.project
  environment   = "dev"
  purpose       = "data"
  bucket_name   = "${local.project}-dev-artifacts-${var.account_id}"
  sse_algorithm = "AES256"
  force_destroy = true # solo porque es un ejemplo efímero
}

resource "aws_s3_object" "package" {
  bucket         = module.artifacts.bucket_id
  key            = "onboarding/app.zip"
  content_base64 = "UEsDBBQAAAAIAAAAIQBpPtBMAgIAANADAAAGAAAAYXBwLnB5bVLNjtowEL7nKSyfEglS1O0JicMKsVUu7CphqSq0ikw8gLuJHdkmXYTy7p3YJASpvtgzY38/MxZVrbQlp4oVgfDnP0bJ/qxM0B/3yqqnIMhNRRY+iItSgLQhNVBosKZikh1B0yjIrfoEafDiWkkIgoDDgeQNKwW/lcJoHhBcx1LtWUluWZcShz4kwjgAf7VbTEsEVSYG2Qit5I6+psnPZJ1vV2ny8jvPVst0tcmf0zX9GB4Zi7I6MVdDDkqThghJ0EfMwRRa7CH3BsLMbQlfIE20o1vQRiiZcLNRmcOgHzGaOAPKd0imQ2ragenuezfkXB7JjmBvPLnDeGCbkBuZ41kYZPflzGohjyMz3RqoQ/r8K1u+p+lqvaET0kVv6WqbvL5nOIXxE2yqe+F7MZQ8LvKcsbH9EPy4TkzyEnQIDc54QgolLXzZfmzKoklf65yF9ASMowUaERR3bSOf/ZoqLY5CThvQ4nDpNN6EoSCJIExewu7zxYWqaqYh5wL12RAJJsT6Lls3r8ffE93/xE39laI3ezZLxYHOyY/ZE5LtFb9g0H3pmJ+r2oRXWoEx2ARM0xel94JzkLSN2nErrgP6I+r32WxyL/We50ju+iPt1F5qB83quhQFszjTbx09bUcP/ydLfWJmo8+AsmtmTxiN2qvZ37cu6do7yrubURt58Db4B1BLAQIUAxQAAAAIAAAAIQBpPtBMAgIAANADAAAGAAAAAAAAAAAAAACkAQAAAABhcHAucHlQSwUGAAAAAAEAAQA0AAAAJgIAAAAA"
}

module "control_plane" {
  source = "../../../control-plane"

  project     = local.project
  environment = "dev"

  pools = ["basic"]

  auth = {
    callback_urls = ["https://example.com/auth/callback"]
  }

  onboarding_function = {
    s3_bucket         = module.artifacts.bucket_id
    s3_key            = aws_s3_object.package.key
    s3_object_version = aws_s3_object.package.version_id
  }

  alarm_emails = var.alarm_emails
}

output "issuers" {
  description = "Emisores de JWT (jwt_issuers de app-app)."
  value       = module.control_plane.issuers
}

output "event_bus_arn" {
  description = "Bus del control plane (metering_bus_arn de app-app)."
  value       = module.control_plane.event_bus_arn
}
