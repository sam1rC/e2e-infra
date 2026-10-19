mock_provider "aws" {
  mock_resource "aws_lb_target_group" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/acme-prod-web/73e2d6bc24d8a067"
      arn_suffix = "targetgroup/acme-prod-web/73e2d6bc24d8a067"
    }
  }

  mock_resource "aws_lb" {
    defaults = {
      arn        = "arn:aws:elasticloadbalancing:us-east-1:123456789012:loadbalancer/app/acme-prod/50dc6c495c0c9188"
      arn_suffix = "app/acme-prod/50dc6c495c0c9188"
    }
  }

  mock_resource "aws_lb_listener" {
    defaults = {
      arn = "arn:aws:elasticloadbalancing:us-east-1:123456789012:listener/app/acme-prod/50dc6c495c0c9188/f2f7dc8efc522ab2"
    }
  }
}

variables {
  project         = "acme"
  environment     = "prod"
  vpc_id          = "vpc-0123456789abcdef0"
  subnet_ids      = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
  certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-2222-3333-4444-555555555555"

  access_logs_bucket_name = "acme-prod-logs-123456789012"

  target_groups = {
    web = { port = 8080 }
  }

  listener_rules = {
    app = {
      priority     = 10
      target_group = "web"
      host_headers = ["app.example.com"]
    }
  }

  egress_targets = {
    web = { security_group_id = "sg-0cccccccccccccccc", port = 8080 }
  }
}

run "alb_is_internal_and_hardened" {
  command = plan

  assert {
    condition = (
      aws_lb.this.internal &&
      aws_lb.this.load_balancer_type == "application" &&
      aws_lb.this.drop_invalid_header_fields &&
      aws_lb.this.desync_mitigation_mode == "strictest" &&
      aws_lb.this.name == "acme-prod" &&
      aws_lb.this.ip_address_type == "ipv4" &&
      length(aws_lb.this.subnets) == 2
    )
    error_message = "El ALB debe ser interno, con cabeceras inválidas descartadas y desync strictest."
  }
}

run "deletion_protection_only_in_prod" {
  command = plan

  assert {
    condition     = aws_lb.this.enable_deletion_protection
    error_message = "En prod el ALB lleva protección contra borrado."
  }
}

run "no_deletion_protection_in_dev" {
  command = plan

  variables {
    environment             = "dev"
    access_logs_bucket_name = null
  }

  assert {
    condition     = !aws_lb.this.enable_deletion_protection
    error_message = "En dev el ALB debe poder destruirse."
  }

  assert {
    condition     = length(aws_lb.this.access_logs) == 0
    error_message = "Sin bucket no hay bloque de logs de acceso."
  }
}

run "access_logs_enabled_to_the_bucket" {
  command = plan

  assert {
    condition = alltrue([
      for l in aws_lb.this.access_logs :
      l.enabled && l.bucket == "acme-prod-logs-123456789012" && l.prefix == "alb"
    ]) && length(aws_lb.this.access_logs) == 1
    error_message = "Los logs de acceso deben ir al bucket indicado."
  }
}

run "listener_is_https_tls13_with_404_default" {
  command = plan

  assert {
    condition = (
      aws_lb_listener.https.port == 443 &&
      aws_lb_listener.https.protocol == "HTTPS" &&
      aws_lb_listener.https.ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06" &&
      aws_lb_listener.https.certificate_arn == var.certificate_arn
    )
    error_message = "El listener debe ser HTTPS 443 con la política TLS 1.3/1.2 y el certificado regional."
  }

  assert {
    condition = alltrue([
      for a in aws_lb_listener.https.default_action :
      a.type == "fixed-response" && alltrue([for f in a.fixed_response : f.status_code == "404"])
    ])
    error_message = "La acción por defecto debe ser un fixed-response 404."
  }
}

run "security_group_has_no_ingress_and_only_target_egress" {
  command = plan

  assert {
    condition     = length(aws_security_group.this.ingress) == 0
    error_message = "El SG no debe llevar reglas de entrada en línea."
  }

  assert {
    condition = alltrue([
      for k, r in aws_vpc_security_group_egress_rule.to_targets :
      r.referenced_security_group_id == "sg-0cccccccccccccccc" &&
      r.from_port == 8080 && r.to_port == 8080 && r.ip_protocol == "tcp" &&
      r.cidr_ipv4 == null && r.cidr_ipv6 == null
    ]) && toset(keys(aws_vpc_security_group_egress_rule.to_targets)) == toset(["web"])
    error_message = "La única salida es al SG del target, en el puerto de la app, sin CIDR."
  }
}

run "target_group_is_ip_with_short_deregistration" {
  command = plan

  assert {
    condition = (
      aws_lb_target_group.this["web"].target_type == "ip" &&
      aws_lb_target_group.this["web"].name == "acme-prod-web" &&
      aws_lb_target_group.this["web"].port == 8080 &&
      aws_lb_target_group.this["web"].protocol == "HTTP" &&
      aws_lb_target_group.this["web"].deregistration_delay == "30"
    )
    error_message = "Target group ip, con deregistration_delay 30."
  }

  assert {
    condition = alltrue([
      for h in aws_lb_target_group.this["web"].health_check :
      h.enabled && h.path == "/" && h.matcher == "200-399" && h.timeout < h.interval
    ])
    error_message = "El health check por defecto debe ser coherente."
  }
}

run "host_header_rule_forwards_to_target_group" {
  command = plan

  assert {
    condition = (
      aws_lb_listener_rule.this["app"].priority == 10 &&
      alltrue([for a in aws_lb_listener_rule.this["app"].action : a.type == "forward"]) &&
      alltrue([
        for c in aws_lb_listener_rule.this["app"].condition :
        alltrue([for h in c.host_header : toset(h.values) == toset(["app.example.com"])])
      ])
    )
    error_message = "La regla debe reenviar por host-header al target group."
  }
}

run "path_and_host_conditions_are_both_supported" {
  command = plan

  variables {
    listener_rules = {
      api = {
        priority      = 20
        target_group  = "web"
        host_headers  = ["app.example.com"]
        path_patterns = ["/api/*"]
      }
    }
  }

  assert {
    condition     = length(aws_lb_listener_rule.this["api"].condition) == 2
    error_message = "Debe haber una condición de host y otra de path."
  }
}

run "rejects_single_subnet" {
  command = plan

  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_legacy_tls_policy" {
  command = plan

  variables {
    ssl_policy = "ELBSecurityPolicy-2016-08"
  }

  expect_failures = [var.ssl_policy]
}

run "rejects_prod_without_access_logs" {
  command = plan

  variables {
    access_logs_bucket_name = null
  }

  expect_failures = [var.access_logs_bucket_name]
}

run "rejects_rule_without_condition" {
  command = plan

  variables {
    listener_rules = {
      all = { priority = 10, target_group = "web" }
    }
  }

  expect_failures = [var.listener_rules]
}

run "rejects_rule_to_unknown_target_group" {
  command = plan

  variables {
    listener_rules = {
      app = { priority = 10, target_group = "nope", host_headers = ["app.example.com"] }
    }
  }

  expect_failures = [var.listener_rules]
}

run "rejects_duplicate_priorities" {
  command = plan

  variables {
    listener_rules = {
      a = { priority = 10, target_group = "web", host_headers = ["a.example.com"] }
      b = { priority = 10, target_group = "web", host_headers = ["b.example.com"] }
    }
  }

  expect_failures = [var.listener_rules]
}

run "rejects_too_long_target_group_name" {
  command = plan

  variables {
    project = "a-very-long-project"
    target_groups = {
      "a-long-target-key" = { port = 80 }
    }
    listener_rules = {}
    egress_targets = {}
  }

  expect_failures = [var.target_groups]
}

run "rejects_health_check_timeout_over_interval" {
  command = plan

  variables {
    target_groups = {
      web = { port = 80, health_check = { interval = 5, timeout = 10 } }
    }
  }

  expect_failures = [var.target_groups]
}
