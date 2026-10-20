mock_provider "aws" {
  # La política ya no depende del ARN del repositorio y se conoce en el plan: el mock necesita un JSON válido.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_ecr_repository" {
    defaults = {
      arn            = "arn:aws:ecr:us-east-1:123456789012:repository/acme-prod-web"
      repository_url = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-prod-web"
      registry_id    = "123456789012"
    }
  }
}

variables {
  project     = "acme"
  environment = "prod"
  name        = "web"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "repository_is_immutable_kms_and_scanned" {
  command = plan

  assert {
    condition = (
      aws_ecr_repository.this.name == "acme-prod-web" &&
      aws_ecr_repository.this.image_tag_mutability == "IMMUTABLE" &&
      !aws_ecr_repository.this.force_delete
    )
    error_message = "El repositorio debe ser IMMUTABLE y no admitir force_delete por defecto."
  }

  assert {
    condition = alltrue([
      for e in aws_ecr_repository.this.encryption_configuration :
      e.encryption_type == "KMS" && e.kms_key == var.kms_key_arn
    ]) && length(aws_ecr_repository.this.encryption_configuration) == 1
    error_message = "El repositorio debe cifrarse con la CMK indicada."
  }

  assert {
    condition     = alltrue([for s in aws_ecr_repository.this.image_scanning_configuration : s.scan_on_push])
    error_message = "Con scan_type basic se escanea al subir."
  }
}

run "enhanced_scanning_delegates_to_inspector" {
  command = plan

  variables {
    scan_type = "enhanced"
  }

  assert {
    condition     = alltrue([for s in aws_ecr_repository.this.image_scanning_configuration : !s.scan_on_push])
    error_message = "Con enhanced el escaneo lo gobierna el registro."
  }

  assert {
    condition     = length(aws_ecr_registry_scanning_configuration.this) == 0
    error_message = "El registro (único por cuenta) no se toca salvo que se pida."
  }
}

run "registry_scanning_is_opt_in" {
  command = plan

  variables {
    scan_type                = "enhanced"
    manage_registry_scanning = true
  }

  assert {
    condition = (
      length(aws_ecr_registry_scanning_configuration.this) == 1 &&
      aws_ecr_registry_scanning_configuration.this[0].scan_type == "ENHANCED" &&
      alltrue([
        for r in aws_ecr_registry_scanning_configuration.this[0].rule :
        r.scan_frequency == "CONTINUOUS_SCAN" &&
        alltrue([for f in r.repository_filter : f.filter == "acme-prod-*" && f.filter_type == "WILDCARD"])
      ])
    )
    error_message = "El escaneo del registro debe ser enhanced y continuo para los repositorios del entorno."
  }
}

run "registry_scanning_ignored_with_basic_scan" {
  command = plan

  variables {
    manage_registry_scanning = true
  }

  assert {
    condition     = length(aws_ecr_registry_scanning_configuration.this) == 0
    error_message = "manage_registry_scanning solo aplica con scan_type enhanced."
  }
}

run "lifecycle_expires_untagged_then_keeps_last_n" {
  command = plan

  variables {
    keep_last_images     = 10
    untagged_expiry_days = 3
  }

  assert {
    condition = (
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].selection.tagStatus == "untagged" &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].selection.countNumber == 3 &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[0].rulePriority == 1 &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[1].selection.tagStatus == "any" &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[1].selection.countNumber == 10 &&
      jsondecode(aws_ecr_lifecycle_policy.this.policy).rules[1].rulePriority == 2
    )
    error_message = "Primero expiran las imágenes sin etiqueta y la regla 'any' va la última con el límite N."
  }
}

run "no_repository_policy_by_default" {
  command = plan

  assert {
    condition     = length(aws_ecr_repository_policy.this) == 0
    error_message = "Sin cuentas de CI no hay política de repositorio."
  }
}

run "repository_policy_for_ci_and_pull_roles" {
  command = plan

  variables {
    ci_principal_arns   = ["arn:aws:iam::210987654321:role/ci-push"]
    pull_principal_arns = ["arn:aws:iam::210987654321:role/ecs-exec"]
  }

  assert {
    condition     = length(aws_ecr_repository_policy.this) == 1
    error_message = "Debe crearse la política de repositorio."
  }

  assert {
    condition = (
      length(data.aws_iam_policy_document.repository[0].statement) == 2 &&
      alltrue([
        for s in data.aws_iam_policy_document.repository[0].statement :
        s.effect == "Allow" && !contains(s.actions, "ecr:*") &&
        alltrue([for p in s.principals : p.type == "AWS" && !contains(p.identifiers, "*")])
      ]) &&
      alltrue([
        for s in data.aws_iam_policy_document.repository[0].statement :
        !contains(s.actions, "ecr:PutImage") if s.sid == "PullOnly"
      ]) &&
      # ECR rechaza el elemento Resource en las políticas de repositorio.
      alltrue([
        for s in data.aws_iam_policy_document.repository[0].statement :
        s.resources == null || length(coalesce(s.resources, [])) == 0
      ])
    )
    error_message = "Dos sentencias Allow con acciones explícitas, principales concretos y el pull sin PutImage."
  }
}

run "rejects_account_root_as_ci_principal" {
  command = plan

  variables {
    ci_principal_arns = ["arn:aws:iam::210987654321:root"]
  }

  expect_failures = [var.ci_principal_arns]
}

run "rejects_kms_alias" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/ecr"
  }

  expect_failures = [var.kms_key_arn]
}

run "rejects_unknown_scan_type" {
  command = plan

  variables {
    scan_type = "none"
  }

  expect_failures = [var.scan_type]
}

run "rejects_zero_images_to_keep" {
  command = plan

  variables {
    keep_last_images = 0
  }

  expect_failures = [var.keep_last_images]
}
