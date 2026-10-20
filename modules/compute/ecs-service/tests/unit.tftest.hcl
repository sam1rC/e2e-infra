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

  # Un JSON válido: el recurso aws_iam_role rechaza el texto aleatorio que genera el mock.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/ecs/acme-prod-web"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      arn = "arn:aws:iam::123456789012:role/acme-prod-web-exec"
    }
  }
}

variables {
  project         = "acme"
  environment     = "prod"
  name            = "web"
  cluster_arn     = "arn:aws:ecs:us-east-1:123456789012:cluster/acme-prod"
  vpc_id          = "vpc-0123456789abcdef0"
  subnet_ids      = ["subnet-0aaaaaaaaaaaaaaaa", "subnet-0bbbbbbbbbbbbbbbb"]
  image           = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-prod-web@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  log_kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
  container_port  = 8080

  alb_security_group_id = "sg-0aaaaaaaaaaaaaaaa"
  target_group_arn      = "arn:aws:elasticloadbalancing:us-east-1:123456789012:targetgroup/acme-prod-web/73e2d6bc24d8a067"
}

run "task_definition_is_fargate_arm64_awsvpc" {
  command = plan

  assert {
    condition = (
      aws_ecs_task_definition.this.family == "acme-prod-web" &&
      toset(aws_ecs_task_definition.this.requires_compatibilities) == toset(["FARGATE"]) &&
      aws_ecs_task_definition.this.network_mode == "awsvpc" &&
      aws_ecs_task_definition.this.cpu == "512" &&
      aws_ecs_task_definition.this.memory == "1024" &&
      alltrue([for r in aws_ecs_task_definition.this.runtime_platform : r.cpu_architecture == "ARM64" && r.operating_system_family == "LINUX"])
    )
    error_message = "Task definition Fargate, awsvpc y ARM64 por defecto."
  }
}

run "x86_is_selectable" {
  command = plan

  variables {
    cpu_architecture = "X86_64"
  }

  assert {
    condition     = alltrue([for r in aws_ecs_task_definition.this.runtime_platform : r.cpu_architecture == "X86_64"])
    error_message = "cpu_architecture debe poder ser X86_64."
  }
}

run "app_container_is_hardened" {
  command = plan

  assert {
    condition = (
      length(jsondecode(aws_ecs_task_definition.this.container_definitions)) == 1 &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].name == "web" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].image == var.image &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].readonlyRootFilesystem == true &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].privileged == false &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].user == "10001:10001" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].linuxParameters.initProcessEnabled == true &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].linuxParameters.capabilities.drop[0] == "ALL"
    )
    error_message = "El contenedor debe ser de solo lectura, no root, sin privilegios, con init y sin capabilities."
  }

  assert {
    condition     = jsondecode(aws_ecs_task_definition.this.container_definitions)[0].portMappings[0].containerPort == 8080
    error_message = "Debe exponer el puerto del contenedor."
  }
}

run "tmp_is_an_ephemeral_writable_volume" {
  command = plan

  assert {
    condition = (
      toset([for v in aws_ecs_task_definition.this.volume : v.name]) == toset(["tmp"]) &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].mountPoints[0].sourceVolume == "tmp" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].mountPoints[0].containerPath == "/tmp"
    )
    error_message = "/tmp debe montarse como volumen efímero."
  }
}

run "logs_go_to_a_kms_log_group" {
  command = plan

  assert {
    condition = (
      aws_cloudwatch_log_group.this.name == "/ecs/acme-prod-web" &&
      aws_cloudwatch_log_group.this.kms_key_id == var.log_kms_key_arn &&
      aws_cloudwatch_log_group.this.retention_in_days == 90
    )
    error_message = "El log group debe tener retención y CMK."
  }

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.logDriver == "awslogs" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-group"] == "/ecs/acme-prod-web" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].logConfiguration.options["awslogs-region"] == "us-east-1"
    )
    error_message = "El contenedor debe escribir con awslogs en ese log group."
  }
}

run "secrets_are_injected_and_policy_is_limited_to_them" {
  command = plan

  variables {
    secrets = {
      DB_PASSWORD = "arn:aws:secretsmanager:us-east-1:123456789012:secret:acme/db-AbCdEf:password::"
      API_KEY     = "arn:aws:secretsmanager:us-east-1:123456789012:secret:acme/api-GhIjKl"
      FLAG        = "arn:aws:ssm:us-east-1:123456789012:parameter/acme/flag"
    }
    secrets_kms_key_arns = ["arn:aws:kms:us-east-1:123456789012:key/99999999-2222-3333-4444-555555555555"]
  }

  assert {
    condition = (
      length(jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets) == 3 &&
      toset([for s in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].secrets : s.name]) == toset(["DB_PASSWORD", "API_KEY", "FLAG"])
    )
    error_message = "Los tres secretos deben inyectarse como variables."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "ReadDeclaredSecrets" &&
      toset(s.actions) == toset(["secretsmanager:GetSecretValue"]) &&
      toset(s.resources) == toset([
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:acme/db-AbCdEf",
        "arn:aws:secretsmanager:us-east-1:123456789012:secret:acme/api-GhIjKl",
      ])
    ])
    error_message = "GetSecretValue solo sobre los secretos declarados (sin el sufijo :clave::)."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "ReadDeclaredParameters" &&
      toset(s.actions) == toset(["ssm:GetParameters"]) &&
      toset(s.resources) == toset(["arn:aws:ssm:us-east-1:123456789012:parameter/acme/flag"])
    ])
    error_message = "ssm:GetParameters solo sobre los parámetros declarados."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "DecryptDeclaredSecrets" &&
      toset(s.actions) == toset(["kms:Decrypt"]) &&
      toset(s.resources) == toset(var.secrets_kms_key_arns) &&
      anytrue([
        for c in s.condition :
        c.variable == "kms:ViaService" && toset(c.values) == toset(["secretsmanager.us-east-1.amazonaws.com", "ssm.us-east-1.amazonaws.com"])
      ])
    ])
    error_message = "kms:Decrypt solo sobre las CMK declaradas y vía Secrets Manager/SSM."
  }
}

run "no_secret_statements_without_secrets" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.execution.statement :
      !contains(["ReadDeclaredSecrets", "ReadDeclaredParameters", "DecryptDeclaredSecrets"], s.sid)
    ])
    error_message = "Sin secretos no debe haber permisos sobre secretos ni claves."
  }
}

run "execution_role_is_least_privilege" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.effect == "Allow" &&
      alltrue([for a in s.actions : !endswith(a, ":*") && a != "*"]) &&
      (s.sid == "EcrAuthorizationToken" || !contains(s.resources, "*"))
    ])
    error_message = "Acciones explícitas y recursos concretos (salvo ecr:GetAuthorizationToken)."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "PullImages" && toset(s.resources) == toset(["arn:aws:ecr:us-east-1:123456789012:repository/acme-prod-web"])
    ])
    error_message = "El repositorio ECR se deduce de la imagen."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "WriteServiceLogs" && toset(s.actions) == toset(["logs:CreateLogStream", "logs:PutLogEvents"])
    ])
    error_message = "El execution role escribe logs sin CreateLogGroup."
  }
}

run "extra_ecr_repositories_are_added" {
  command = plan

  variables {
    image               = "public.ecr.aws/nginx/nginx@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    ecr_repository_arns = ["arn:aws:ecr:us-east-1:123456789012:repository/mirror-nginx"]
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "PullImages" && toset(s.resources) == toset(["arn:aws:ecr:us-east-1:123456789012:repository/mirror-nginx"])
    ])
    error_message = "Una imagen que no es de ECR no añade repositorios; los explícitos sí."
  }
}

run "trust_policies_are_scoped_to_this_account" {
  command = plan

  assert {
    condition = alltrue([
      for s in data.aws_iam_policy_document.ecs_tasks_assume.statement :
      alltrue([for p in s.principals : p.type == "Service" && toset(p.identifiers) == toset(["ecs-tasks.amazonaws.com"])]) &&
      anytrue([for c in s.condition : c.variable == "aws:SourceAccount" && toset(c.values) == toset(["123456789012"])]) &&
      anytrue([for c in s.condition : c.variable == "aws:SourceArn" && toset(c.values) == toset(["arn:aws:ecs:us-east-1:123456789012:*"])])
    ])
    error_message = "Los roles solo los asumen tareas ECS de esta cuenta."
  }
}

run "task_role_is_empty_by_default" {
  command = plan

  assert {
    condition = (
      length(aws_iam_role_policy.task_injected) == 0 &&
      length(aws_iam_role_policy.task_otel) == 0 &&
      length(aws_iam_role_policy.task_exec_channel) == 0 &&
      aws_iam_role.task.name == "acme-prod-web-task" &&
      aws_iam_role.execution.name == "acme-prod-web-exec"
    )
    error_message = "El task role no lleva permisos por defecto."
  }
}

run "injected_policies_and_boundary_are_applied" {
  command = plan

  variables {
    task_role_policies = {
      queue = jsonencode({
        Version   = "2012-10-17"
        Statement = [{ Effect = "Allow", Action = ["sqs:SendMessage"], Resource = "arn:aws:sqs:us-east-1:123456789012:jobs" }]
      })
    }
    permissions_boundary_arn = "arn:aws:iam::123456789012:policy/acme-boundary"
  }

  assert {
    condition = (
      toset(keys(aws_iam_role_policy.task_injected)) == toset(["queue"]) &&
      aws_iam_role.task.permissions_boundary == "arn:aws:iam::123456789012:policy/acme-boundary" &&
      aws_iam_role.execution.permissions_boundary == "arn:aws:iam::123456789012:policy/acme-boundary"
    )
    error_message = "Las políticas inyectadas y la boundary deben aplicarse."
  }
}

run "service_runs_private_with_circuit_breaker_rollback" {
  command = plan

  assert {
    condition = (
      length(aws_ecs_service.managed) == 1 &&
      length(aws_ecs_service.external) == 0 &&
      aws_ecs_service.managed[0].name == "acme-prod-web" &&
      aws_ecs_service.managed[0].cluster == var.cluster_arn &&
      aws_ecs_service.managed[0].propagate_tags == "SERVICE" &&
      aws_ecs_service.managed[0].enable_execute_command == false &&
      aws_ecs_service.managed[0].deployment_minimum_healthy_percent == 100 &&
      aws_ecs_service.managed[0].deployment_maximum_percent == 200 &&
      aws_ecs_service.managed[0].desired_count == 2 &&
      aws_ecs_service.managed[0].health_check_grace_period_seconds == 60
    )
    error_message = "Servicio con propagate_tags SERVICE, 100% sano en prod y 2 tareas."
  }

  assert {
    condition = alltrue([
      for n in aws_ecs_service.managed[0].network_configuration :
      n.assign_public_ip == false && toset(n.subnets) == toset(var.subnet_ids) && length(n.security_groups) == 1
    ])
    error_message = "Las tareas no reciben IP pública y usan las subredes app."
  }

  assert {
    condition = alltrue([
      for c in aws_ecs_service.managed[0].deployment_circuit_breaker : c.enable && c.rollback
    ]) && length(aws_ecs_service.managed[0].deployment_circuit_breaker) == 1
    error_message = "El circuit breaker debe activar el rollback."
  }

  assert {
    condition = alltrue([
      for l in aws_ecs_service.managed[0].load_balancer :
      l.target_group_arn == var.target_group_arn && l.container_name == "web" && l.container_port == 8080
    ]) && length(aws_ecs_service.managed[0].load_balancer) == 1
    error_message = "El servicio se registra en el target group."
  }
}

run "dev_defaults_are_lighter" {
  command = plan

  variables {
    environment = "dev"
    subnet_ids  = ["subnet-0aaaaaaaaaaaaaaaa"]
  }

  assert {
    condition = (
      aws_ecs_service.managed[0].deployment_minimum_healthy_percent == 50 &&
      aws_ecs_service.managed[0].desired_count == 1 &&
      aws_appautoscaling_target.this.min_capacity == 1
    )
    error_message = "En dev: 50% sano y 1 tarea."
  }
}

run "worker_without_alb_has_no_load_balancer_or_ingress" {
  command = plan

  variables {
    alb_security_group_id = null
    target_group_arn      = null
  }

  assert {
    condition = (
      length(aws_ecs_service.managed[0].load_balancer) == 0 &&
      length(aws_vpc_security_group_ingress_rule.from_alb) == 0 &&
      aws_ecs_service.managed[0].health_check_grace_period_seconds == null
    )
    error_message = "Un worker no tiene balanceador, regla de entrada ni periodo de gracia."
  }
}

run "security_group_accepts_only_the_alb_and_declared_egress" {
  command = plan

  variables {
    egress_rules = {
      endpoints = { description = "HTTPS a los endpoints de VPC", port = 443, security_group_id = "sg-0eeeeeeeeeeeeeeee" }
      s3        = { description = "HTTPS al gateway de S3", port = 443, prefix_list_id = "pl-63a5400a" }
      db        = { description = "PostgreSQL", port = 5432, security_group_id = "sg-0dddddddddddddddd" }
    }
  }

  assert {
    condition = (
      length(aws_vpc_security_group_ingress_rule.from_alb) == 1 &&
      aws_vpc_security_group_ingress_rule.from_alb[0].referenced_security_group_id == "sg-0aaaaaaaaaaaaaaaa" &&
      aws_vpc_security_group_ingress_rule.from_alb[0].from_port == 8080 &&
      aws_vpc_security_group_ingress_rule.from_alb[0].to_port == 8080 &&
      aws_vpc_security_group_ingress_rule.from_alb[0].cidr_ipv4 == null
    )
    error_message = "La entrada es solo desde el SG del ALB en el puerto del contenedor."
  }

  assert {
    condition = (
      toset(keys(aws_vpc_security_group_egress_rule.this)) == toset(["endpoints", "s3", "db"]) &&
      aws_vpc_security_group_egress_rule.this["s3"].prefix_list_id == "pl-63a5400a" &&
      aws_vpc_security_group_egress_rule.this["db"].referenced_security_group_id == "sg-0dddddddddddddddd" &&
      aws_vpc_security_group_egress_rule.this["db"].from_port == 5432 &&
      aws_vpc_security_group_egress_rule.this["db"].cidr_ipv4 == null
    )
    error_message = "La salida son solo las reglas declaradas."
  }
}

run "autoscaling_tracks_cpu_at_60_with_min_two_in_prod" {
  command = plan

  assert {
    condition = (
      aws_appautoscaling_target.this.service_namespace == "ecs" &&
      aws_appautoscaling_target.this.scalable_dimension == "ecs:service:DesiredCount" &&
      aws_appautoscaling_target.this.resource_id == "service/acme-prod/acme-prod-web" &&
      aws_appautoscaling_target.this.min_capacity == 2 &&
      aws_appautoscaling_target.this.max_capacity == 4
    )
    error_message = "Autoscaling 2-4 tareas sobre el servicio."
  }

  assert {
    condition = alltrue([
      for c in aws_appautoscaling_policy.cpu.target_tracking_scaling_policy_configuration :
      c.target_value == 60 &&
      alltrue([for p in c.predefined_metric_specification : p.predefined_metric_type == "ECSServiceAverageCPUUtilization"])
    ]) && length(aws_appautoscaling_policy.cpu.target_tracking_scaling_policy_configuration) == 1
    error_message = "Target tracking de CPU al 60%."
  }

  assert {
    condition     = length(aws_appautoscaling_policy.requests) == 0
    error_message = "Sin requests_per_target no hay política por solicitudes."
  }
}

run "autoscaling_can_track_alb_requests" {
  command = plan

  variables {
    requests_per_target     = 500
    alb_arn_suffix          = "app/acme-prod/50dc6c495c0c9188"
    target_group_arn_suffix = "targetgroup/acme-prod-web/73e2d6bc24d8a067"
  }

  assert {
    condition = alltrue([
      for c in aws_appautoscaling_policy.requests[0].target_tracking_scaling_policy_configuration :
      c.target_value == 500 &&
      alltrue([
        for p in c.predefined_metric_specification :
        p.predefined_metric_type == "ALBRequestCountPerTarget" &&
        p.resource_label == "app/acme-prod/50dc6c495c0c9188/targetgroup/acme-prod-web/73e2d6bc24d8a067"
      ])
    ])
    error_message = "Target tracking por ALBRequestCountPerTarget con el resource_label del ALB y del target group."
  }
}

run "app_deploys_outside_iac_uses_the_ignoring_service" {
  command = plan

  variables {
    app_deploys_outside_iac = true
  }

  assert {
    condition = (
      length(aws_ecs_service.managed) == 0 &&
      length(aws_ecs_service.external) == 1 &&
      aws_ecs_service.external[0].name == "acme-prod-web" &&
      aws_ecs_task_definition.this.skip_destroy == true
    )
    error_message = "Con despliegue externo se usa el servicio que ignora task_definition y no se desregistran revisiones."
  }
}

run "enable_exec_adds_the_ssm_channel_permissions" {
  command = plan

  variables {
    environment = "dev"
    subnet_ids  = ["subnet-0aaaaaaaaaaaaaaaa"]
    enable_exec = true
  }

  assert {
    condition = (
      aws_ecs_service.managed[0].enable_execute_command == true &&
      length(aws_iam_role_policy.task_exec_channel) == 1 &&
      anytrue([
        for s in data.aws_iam_policy_document.exec_channel[0].statement :
        contains(s.actions, "ssmmessages:CreateDataChannel") && !contains(s.actions, "ssm:*")
      ])
    )
    error_message = "ECS Exec requiere los permisos ssmmessages en el task role."
  }
}

run "otel_sidecar_adds_a_collector_and_trace_permissions" {
  command = plan

  variables {
    enable_otel_sidecar = true
    otel_image          = "123456789012.dkr.ecr.us-east-1.amazonaws.com/adot-collector@sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
    environment_variables = {
      LOG_LEVEL = "info"
    }
  }

  assert {
    condition = (
      length(jsondecode(aws_ecs_task_definition.this.container_definitions)) == 2 &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[1].name == "otel-collector" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[1].essential == false &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[1].readonlyRootFilesystem == true &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[1].user == "10001" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].dependsOn[0].containerName == "otel-collector"
    )
    error_message = "El collector ADOT debe ser un sidecar no esencial, de solo lectura y no root."
  }

  assert {
    condition = (
      toset([for e in jsondecode(aws_ecs_task_definition.this.container_definitions)[0].environment : e.name]) ==
      toset(["LOG_LEVEL", "OTEL_EXPORTER_OTLP_ENDPOINT", "OTEL_SERVICE_NAME"])
    )
    error_message = "La aplicación recibe el endpoint OTLP local además de sus variables."
  }

  assert {
    condition = (
      length(aws_iam_role_policy.task_otel) == 1 &&
      anytrue([
        for s in data.aws_iam_policy_document.otel[0].statement :
        s.sid == "SendTraces" && toset(s.actions) == toset(["xray:PutTraceSegments", "xray:PutTelemetryRecords"])
      ]) &&
      anytrue([
        for s in data.aws_iam_policy_document.otel[0].statement :
        s.sid == "SendMetricsAsLogs" && toset(s.actions) == toset(["logs:CreateLogStream", "logs:PutLogEvents"]) &&
        !contains(s.resources, "*")
      ])
    )
    error_message = "El task role recibe permisos de trazas y de logs solo sobre su log group."
  }

  assert {
    condition = anytrue([
      for s in data.aws_iam_policy_document.execution.statement :
      s.sid == "PullImages" && toset(s.resources) == toset([
        "arn:aws:ecr:us-east-1:123456789012:repository/acme-prod-web",
        "arn:aws:ecr:us-east-1:123456789012:repository/adot-collector",
      ])
    ])
    error_message = "El execution role también descarga la imagen del collector."
  }
}

run "rejects_image_by_tag" {
  command = plan

  variables {
    image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/acme-prod-web:latest"
  }

  expect_failures = [var.image]
}

run "rejects_root_user" {
  command = plan

  variables {
    user = "0:0"
  }

  expect_failures = [var.user]
}

run "rejects_one_task_minimum_in_prod" {
  command = plan

  variables {
    min_tasks = 1
  }

  expect_failures = [var.min_tasks]
}

run "rejects_lower_healthy_percent_in_prod" {
  command = plan

  variables {
    deployment_minimum_healthy_percent = 50
  }

  expect_failures = [var.deployment_minimum_healthy_percent]
}

run "rejects_single_subnet_in_prod" {
  command = plan

  variables {
    subnet_ids = ["subnet-0aaaaaaaaaaaaaaaa"]
  }

  expect_failures = [var.subnet_ids]
}

run "rejects_invalid_cpu_memory_combination" {
  command = plan

  variables {
    cpu    = 256
    memory = 8192
  }

  expect_failures = [var.memory]
}

run "rejects_secret_that_is_not_an_arn" {
  command = plan

  variables {
    secrets = { DB_PASSWORD = "hunter2" }
  }

  expect_failures = [var.secrets]
}

run "rejects_otel_without_image" {
  command = plan

  variables {
    enable_otel_sidecar = true
  }

  expect_failures = [var.otel_image]
}

run "rejects_requests_scaling_without_suffixes" {
  command = plan

  variables {
    requests_per_target = 100
  }

  expect_failures = [var.requests_per_target]
}

run "rejects_egress_rule_with_two_destinations" {
  command = plan

  variables {
    egress_rules = {
      bad = { description = "x", port = 443, security_group_id = "sg-0eeeeeeeeeeeeeeee", cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.egress_rules]
}

run "rejects_short_log_retention_in_prod" {
  command = plan

  variables {
    log_retention_days = 14
  }

  expect_failures = [var.log_retention_days]
}

run "rejects_max_below_min" {
  command = plan

  variables {
    max_tasks = 1
  }

  expect_failures = [var.max_tasks]
}

run "alb_flag_requires_target_group_and_sg" {
  command = plan

  variables {
    alb_enabled      = true
    target_group_arn = null
  }

  expect_failures = [var.alb_enabled]
}

run "volume_permissions_init_hands_writable_paths_to_the_app_user" {
  command = plan

  variables {
    writable_paths           = ["/tmp", "/var/cache/nginx"]
    volume_permissions_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/busybox@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
    enable_otel_sidecar      = true
    otel_image               = "123456789012.dkr.ecr.us-east-1.amazonaws.com/adot-collector@sha256:fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
  }

  assert {
    condition = (
      length(jsondecode(aws_ecs_task_definition.this.container_definitions)) == 3 &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[2].name == "volume-permissions" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[2].essential == false &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[2].readonlyRootFilesystem == true &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[2].entryPoint == ["chown"] &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[2].command == ["10001:10001", "/tmp", "/var/cache/nginx"]
    )
    error_message = "El init debe ser no esencial, de solo lectura y hacer chown de las rutas escribibles al usuario de la app."
  }

  assert {
    condition = (
      !contains(jsondecode(aws_ecs_task_definition.this.container_definitions)[2].linuxParameters.capabilities.drop, "CHOWN") &&
      contains(jsondecode(aws_ecs_task_definition.this.container_definitions)[2].linuxParameters.capabilities.drop, "DAC_OVERRIDE") &&
      length(jsondecode(aws_ecs_task_definition.this.container_definitions)[2].linuxParameters.capabilities.add) == 0 &&
      toset([for m in jsondecode(aws_ecs_task_definition.this.container_definitions)[2].mountPoints : m.containerPath]) == toset(["/tmp", "/var/cache/nginx"])
    )
    error_message = "El init solo conserva CHOWN y monta los mismos volúmenes que la aplicación."
  }

  assert {
    condition = (
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].dependsOn[0].containerName == "volume-permissions" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].dependsOn[0].condition == "SUCCESS" &&
      jsondecode(aws_ecs_task_definition.this.container_definitions)[0].dependsOn[1].containerName == "otel-collector"
    )
    error_message = "La aplicación arranca cuando el init termina con éxito (y el collector ha arrancado)."
  }
}

run "volume_permissions_skipped_without_writable_paths" {
  command = plan

  variables {
    writable_paths           = []
    volume_permissions_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/busybox@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }

  assert {
    condition     = length(jsondecode(aws_ecs_task_definition.this.container_definitions)) == 1
    error_message = "Sin rutas escribibles no hace falta contenedor init."
  }
}

run "rejects_volume_permissions_with_named_user" {
  command = plan

  variables {
    user                     = "nginx"
    volume_permissions_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/busybox@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
  }

  expect_failures = [var.volume_permissions_image]
}
