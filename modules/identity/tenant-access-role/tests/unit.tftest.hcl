mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  project           = "acme"
  environment       = "prod"
  trusted_role_arns = ["arn:aws:iam::123456789012:role/acme-prod-api"]

  dynamodb_tables = {
    orders = { table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/acme-prod-orders" }
  }
}

run "trust_requires_exactly_the_tenant_session_tag" {
  command = plan

  assert {
    condition     = length(data.aws_iam_policy_document.trust.statement) == 1
    error_message = "La trust policy tiene una sola sentencia."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.trust.statement :
      toset(s.actions) == toset(["sts:AssumeRole", "sts:TagSession"]) &&
      alltrue([for p in s.principals : p.type == "AWS" && toset(p.identifiers) == toset(["arn:aws:iam::123456789012:role/acme-prod-api"])])
    ])
    error_message = "Solo los roles de la aplicación asumen el rol, con AssumeRole y TagSession."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.trust.statement :
      length([for c in s.condition : c if c.test == "StringLike" && c.variable == "aws:RequestTag/tenant" && toset(c.values) == toset(["?*"])]) == 1 &&
      length([for c in s.condition : c if c.test == "ForAllValues:StringEquals" && c.variable == "aws:TagKeys" && toset(c.values) == toset(["tenant"])]) == 1 &&
      length([for c in s.condition : c if c.test == "Null" && c.variable == "aws:TagKeys" && toset(c.values) == toset(["false"])]) == 1
    ])
    error_message = "La trust policy exige la etiqueta tenant no vacía, solo esa etiqueta, y un Null junto al ForAllValues en la misma sentencia."
  }
}

run "role_is_capped_at_one_hour_and_tagged" {
  command = plan

  assert {
    condition     = aws_iam_role.this.name == "acme-prod-tenant-access" && aws_iam_role.this.max_session_duration == 3600
    error_message = "Rol <project>-<env>-tenant-access con sesiones de 1 hora (límite del encadenamiento de roles)."
  }

  assert {
    condition     = aws_iam_role.this.tags["TenantIsolation"] == "session-tag"
    error_message = "El rol se etiqueta TenantIsolation = session-tag para auditoría."
  }
}

run "everything_is_denied_without_the_tenant_tag" {
  command = plan

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "DenyWithoutTenantTag" && s.effect == "Deny" && toset(s.actions) == toset(["*"]) &&
      length([for c in s.condition : c if c.test == "Null" && c.variable == "aws:PrincipalTag/tenant" && toset(c.values) == toset(["true"])]) == 1
    ]) == 1
    error_message = "Debe existir un Deny de todo cuando falta la etiqueta de tenant en la sesión."
  }
}

run "dynamodb_is_limited_to_the_tenant_partition_and_fails_closed" {
  command = plan

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "TenantItemsOrders" && s.effect == "Allow" &&
      toset(s.resources) == toset(["arn:aws:dynamodb:us-east-1:123456789012:table/acme-prod-orders", "arn:aws:dynamodb:us-east-1:123456789012:table/acme-prod-orders/index/*"]) &&
      length([for c in s.condition : c if c.test == "ForAllValues:StringEquals" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["$${aws:PrincipalTag/tenant}"])]) == 1 &&
      length([for c in s.condition : c if c.test == "Null" && c.variable == "dynamodb:LeadingKeys" && toset(c.values) == toset(["false"])]) == 1
    ]) == 1
    error_message = "La sentencia de la tabla debe cubrir tabla e índices con LeadingKeys = tenant y un Null en la misma sentencia."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.permissions.statement :
      !contains(s.actions, "dynamodb:Scan") && !contains(s.actions, "dynamodb:*") if s.effect == "Allow"
    ])
    error_message = "Ninguna sentencia Allow concede Scan ni comodines de DynamoDB."
  }

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "DenyFullTableReads" && s.effect == "Deny" &&
      contains(s.actions, "dynamodb:Scan") && contains(s.actions, "dynamodb:PartiQLSelect") &&
      contains(s.resources, "arn:aws:dynamodb:us-east-1:123456789012:table/acme-prod-orders/index/*")
    ]) == 1
    error_message = "Scan y PartiQL se deniegan explícitamente sobre la tabla y sus índices."
  }
}

run "read_only_table_without_indexes" {
  command = plan

  variables {
    dynamodb_tables = {
      order-audit = {
        table_arn       = "arn:aws:dynamodb:us-east-1:123456789012:table/acme-prod-audit"
        include_indexes = false
        read_only       = true
      }
    }
  }

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "TenantItemsOrderAudit" &&
      toset(s.actions) == toset(["dynamodb:BatchGetItem", "dynamodb:ConditionCheckItem", "dynamodb:GetItem", "dynamodb:Query"]) &&
      toset(s.resources) == toset(["arn:aws:dynamodb:us-east-1:123456789012:table/acme-prod-audit"])
    ]) == 1
    error_message = "read_only concede solo lecturas e include_indexes = false excluye los índices (Sid derivado de la clave)."
  }
}

run "s3_objects_listing_and_bucket_key_scoped_to_the_tenant_prefix" {
  command = plan

  variables {
    dynamodb_tables = {}
    s3_buckets = {
      documents = {
        bucket_arn  = "arn:aws:s3:::acme-prod-docs"
        prefix      = "tenants/"
        kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
      }
    }
  }

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "TenantObjectsDocuments" &&
      toset(s.actions) == toset(["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]) &&
      toset(s.resources) == toset(["arn:aws:s3:::acme-prod-docs/tenants/$${aws:PrincipalTag/tenant}/*"])
    ]) == 1
    error_message = "Los objetos solo se alcanzan bajo <bucket>/tenants/<tenant>/."
  }

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "TenantPrefixListDocuments" && toset(s.actions) == toset(["s3:ListBucket"]) &&
      length([for c in s.condition : c if c.test == "StringLike" && c.variable == "s3:prefix" && toset(c.values) == toset(["tenants/$${aws:PrincipalTag/tenant}/", "tenants/$${aws:PrincipalTag/tenant}/*"])]) == 1
    ]) == 1
    error_message = "ListBucket solo con s3:prefix dentro del prefijo del tenant."
  }

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "BucketKeyDocuments" &&
      length([for c in s.condition : c if c.variable == "kms:ViaService" && toset(c.values) == toset(["s3.us-east-1.amazonaws.com"])]) == 1 &&
      length([for c in s.condition : c if c.variable == "kms:EncryptionContext:aws:s3:arn" && toset(c.values) == toset(["arn:aws:s3:::acme-prod-docs"])]) == 1
    ]) == 1
    error_message = "La CMK del bucket solo se usa vía S3 y para ese bucket."
  }

  assert {
    condition     = alltrue([for s in data.aws_iam_policy_document.permissions.statement : !startswith(s.sid, "TenantItems") && s.sid != "DenyFullTableReads"])
    error_message = "Sin tablas no hay sentencias de DynamoDB."
  }
}

run "app_level_encryption_requires_the_tenant_context" {
  command = plan

  variables {
    tenant_tag_key = "tenant_id"
    kms_keys = {
      envelope = "arn:aws:kms:us-east-1:123456789012:key/22222222-2222-3333-4444-555555555555"
    }
  }

  assert {
    condition = length([
      for s in data.aws_iam_policy_document.permissions.statement : s
      if s.sid == "TenantEncryptionContext" && !contains(s.actions, "kms:*") &&
      length([for c in s.condition : c if c.test == "StringEquals" && c.variable == "kms:EncryptionContext:tenant_id" && toset(c.values) == toset(["$${aws:PrincipalTag/tenant_id}"])]) == 1
    ]) == 1
    error_message = "La clave de la aplicación solo se usa con el contexto de cifrado del propio tenant (tenant_tag_key personalizada)."
  }

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.trust.statement :
      length([for c in s.condition : c if c.variable == "aws:RequestTag/tenant_id"]) == 1
    ])
    error_message = "tenant_tag_key cambia también la etiqueta exigida en la trust policy."
  }
}

run "rejects_account_root_as_trusted_principal" {
  command = plan

  variables {
    trusted_role_arns = ["arn:aws:iam::123456789012:root"]
  }

  expect_failures = [var.trusted_role_arns]
}

run "rejects_empty_trusted_principals" {
  command = plan

  variables {
    trusted_role_arns = []
  }

  expect_failures = [var.trusted_role_arns]
}

run "rejects_index_arn_as_table" {
  command = plan

  variables {
    dynamodb_tables = {
      orders = { table_arn = "arn:aws:dynamodb:us-east-1:123456789012:table/acme-prod-orders/index/*" }
    }
  }

  expect_failures = [var.dynamodb_tables]
}

run "rejects_role_without_any_access" {
  command = plan

  variables {
    dynamodb_tables = {}
  }

  expect_failures = [var.dynamodb_tables]
}

run "rejects_prefix_without_trailing_slash" {
  command = plan

  variables {
    s3_buckets = {
      documents = { bucket_arn = "arn:aws:s3:::acme-prod-docs", prefix = "/tenants" }
    }
  }

  expect_failures = [var.s3_buckets]
}

run "rejects_kms_alias" {
  command = plan

  variables {
    kms_keys = { envelope = "arn:aws:kms:us-east-1:123456789012:alias/tenant" }
  }

  expect_failures = [var.kms_keys]
}

run "rejects_invalid_tag_key" {
  command = plan

  variables {
    tenant_tag_key = "Tenant Id"
  }

  expect_failures = [var.tenant_tag_key]
}
