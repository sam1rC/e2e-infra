mock_provider "aws" {
  mock_resource "aws_acm_certificate" {
    defaults = {
      arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"
      domain_validation_options = [
        {
          domain_name           = "app.example.com"
          resource_record_name  = "_a.app.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_b.acm-validations.aws."
        },
        {
          domain_name           = "www.example.com"
          resource_record_name  = "_c.www.example.com."
          resource_record_type  = "CNAME"
          resource_record_value = "_d.acm-validations.aws."
        },
      ]
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  domain_name = "app.example.com"
}

run "dns_validation_with_secure_defaults" {
  command = plan

  assert {
    condition     = aws_acm_certificate.this.validation_method == "DNS" && aws_acm_certificate.this.key_algorithm == "RSA_2048"
    error_message = "Validación DNS y RSA_2048 por defecto."
  }
}

run "external_dns_creates_no_records_and_does_not_block" {
  command = apply

  assert {
    condition     = length(aws_route53_record.validation) == 0 && length(aws_acm_certificate_validation.this) == 0
    error_message = "Sin zone_id no hay registros ni espera de validación (el apply no debe bloquearse)."
  }

  assert {
    condition     = output.certificate_arn == aws_acm_certificate.this.arn
    error_message = "Sin validación, el output es el ARN del certificado pendiente."
  }

  assert {
    condition     = output.validation_records["app.example.com"].type == "CNAME"
    error_message = "Los registros de validación deben emitirse como output."
  }
}

run "external_dns_second_pass_waits_for_validation" {
  command = plan

  variables {
    wait_for_validation = true
  }

  assert {
    condition     = length(aws_acm_certificate_validation.this) == 1 && length(aws_route53_record.validation) == 0
    error_message = "Con wait_for_validation y DNS externo se espera la emisión sin crear registros."
  }
}

run "route53_zone_creates_one_record_per_domain_and_validates" {
  command = apply

  variables {
    subject_alternative_names = ["www.example.com"]
    zone_id                   = "Z0123456789ABCDEFGHIJ"
  }

  assert {
    condition     = toset(keys(aws_route53_record.validation)) == toset(["app.example.com", "www.example.com"])
    error_message = "Debe haber un registro por dominio, con clave estable por nombre."
  }

  assert {
    condition = (
      aws_route53_record.validation["app.example.com"].name == "_a.app.example.com." &&
      aws_route53_record.validation["www.example.com"].name == "_c.www.example.com." &&
      alltrue([for r in aws_route53_record.validation : r.allow_overwrite && r.ttl == 60])
    )
    error_message = "Cada registro toma su opción de validación y permite sobrescribir (comodín + raíz)."
  }

  assert {
    condition     = length(aws_acm_certificate_validation.this) == 1
    error_message = "Con zona de Route 53 siempre se valida."
  }
}

run "san_list_is_forwarded" {
  command = plan

  variables {
    subject_alternative_names = ["www.example.com", "api.example.com"]
  }

  assert {
    condition     = toset(aws_acm_certificate.this.subject_alternative_names) == toset(["www.example.com", "api.example.com"])
    error_message = "Los nombres alternativos deben pasarse al certificado."
  }
}

run "rejects_uppercase_or_invalid_domain" {
  command = plan

  variables {
    domain_name = "App_Example"
  }

  expect_failures = [var.domain_name]
}

run "rejects_san_equal_to_primary_domain" {
  command = plan

  variables {
    subject_alternative_names = ["app.example.com"]
  }

  expect_failures = [var.subject_alternative_names]
}

run "rejects_unknown_key_algorithm" {
  command = plan

  variables {
    key_algorithm = "RSA_1024"
  }

  expect_failures = [var.key_algorithm]
}
