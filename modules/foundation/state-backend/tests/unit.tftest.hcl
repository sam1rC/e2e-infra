mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
}

run "state_bucket_and_key_follow_conventions" {
  command = apply

  assert {
    condition     = strcontains(output.backend_config, "bucket       = \"acme-dev-tfstate-123456789012\"")
    error_message = "El bucket de estado debe llamarse <project>-<env>-tfstate-<account_id>."
  }

  assert {
    condition     = output.kms_alias_name == "alias/acme-dev-state"
    error_message = "La clave de estado debe tener alias alias/<project>-<env>-state."
  }
}

run "backend_snippet_has_native_locking_and_enforced_encryption" {
  command = apply

  assert {
    condition     = strcontains(output.backend_config, "use_lockfile = true")
    error_message = "El backend sugerido debe usar bloqueo nativo (use_lockfile)."
  }

  assert {
    condition     = length(regexall("enforced = true", output.backend_config)) == 2
    error_message = "El cifrado de state y plan debe ser enforced."
  }

  assert {
    condition     = strcontains(output.backend_config, "alias/acme-dev-state") && strcontains(output.backend_config, "acme-dev-tfstate-123456789012")
    error_message = "El snippet debe apuntar al bucket y alias creados."
  }
}

run "rejects_short_version_retention" {
  command = plan

  variables {
    noncurrent_version_retention_days = 7
  }

  expect_failures = [var.noncurrent_version_retention_days]
}

run "rejects_invalid_object_lock_days" {
  command = plan

  variables {
    object_lock_days = 0
  }

  expect_failures = [var.object_lock_days]
}
