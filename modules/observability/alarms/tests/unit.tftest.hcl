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

  # Un JSON válido: aws_sns_topic_policy rechaza el texto aleatorio que genera el mock.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[]}"
    }
  }

  mock_resource "aws_sns_topic" {
    defaults = {
      arn = "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
  kms_key_arn = "arn:aws:kms:us-east-1:123456789012:key/11111111-2222-3333-4444-555555555555"
}

run "topic_is_encrypted_and_publishable_only_by_services_in_this_account" {
  command = plan

  assert {
    condition = (
      aws_sns_topic.this[0].name == "acme-dev-alarms" &&
      aws_sns_topic.this[0].kms_master_key_id == var.kms_key_arn
    )
    error_message = "El topic debe llamarse <project>-<env>-alarms y cifrarse con la CMK."
  }

  assert {
    condition = (
      length(data.aws_iam_policy_document.topic[0].statement) == 3 &&
      toset([for s in data.aws_iam_policy_document.topic[0].statement : s.sid]) == toset(["AllowServicesToPublish", "AllowAccountToManage", "DenyInsecureTransport"]) &&
      anytrue([
        for s in data.aws_iam_policy_document.topic[0].statement :
        s.sid == "AllowServicesToPublish" && anytrue([for c in s.condition : c.variable == "aws:SourceAccount" && toset(c.values) == toset(["123456789012"])])
      ]) &&
      anytrue([for s in data.aws_iam_policy_document.topic[0].statement : s.sid == "DenyInsecureTransport" && s.effect == "Deny"]) &&
      # SNS rechaza comodines de servicio en la política del tema.
      alltrue([for s in data.aws_iam_policy_document.topic[0].statement : alltrue([for a in s.actions : !endswith(a, ":*")])])
    )
    error_message = "La política del topic debe limitar la publicación a servicios de esta cuenta y denegar el transporte sin TLS."
  }
}

run "without_resources_no_alarm_is_created" {
  command = plan

  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.simple) == 0 &&
      length(aws_cloudwatch_metric_alarm.dynamodb) == 0 &&
      length(aws_cloudwatch_metric_alarm.waf_anomaly) == 0
    )
    error_message = "Solo deben crearse las alarmas de los recursos presentes."
  }
}

run "email_subscriptions_are_created_per_address" {
  command = plan

  variables {
    email_subscriptions = ["ops@example.com", "oncall@example.com"]
  }

  assert {
    condition = (
      toset(keys(aws_sns_topic_subscription.email)) == toset(["ops@example.com", "oncall@example.com"]) &&
      alltrue([for s in aws_sns_topic_subscription.email : s.protocol == "email"])
    )
    error_message = "Debe haber una suscripción de correo por destinatario."
  }
}

run "alb_creates_three_alarms_with_p99_and_unhealthy_hosts" {
  command = plan

  variables {
    alb = {
      web = { alb_arn_suffix = "app/acme-dev-web/50dc6c", target_group_arn_suffix = "targetgroup/acme-dev-web/73e2d6" }
    }
  }

  assert {
    condition = toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset([
      "alb-web-target-5xx", "alb-web-response-time-p99", "alb-web-unhealthy-hosts",
    ])
    error_message = "Un ALB debe generar las alarmas de 5XX, latencia p99 y targets no saludables."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["alb-web-response-time-p99"].extended_statistic == "p99" &&
      aws_cloudwatch_metric_alarm.simple["alb-web-response-time-p99"].statistic == null &&
      aws_cloudwatch_metric_alarm.simple["alb-web-target-5xx"].statistic == "Sum" &&
      aws_cloudwatch_metric_alarm.simple["alb-web-unhealthy-hosts"].dimensions["TargetGroup"] == "targetgroup/acme-dev-web/73e2d6" &&
      aws_cloudwatch_metric_alarm.simple["alb-web-unhealthy-hosts"].comparison_operator == "GreaterThanOrEqualToThreshold"
    )
    error_message = "La latencia usa percentil p99 (sin statistic), los 5XX suman y los no saludables dependen del target group."
  }
}

run "ecs_alarm_on_missing_task_data_breaches" {
  command = plan

  variables {
    ecs_services = {
      web = { cluster_name = "acme-dev", service_name = "acme-dev-web", min_running_tasks = 2 }
    }
  }

  assert {
    condition     = toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset(["ecs-web-cpu", "ecs-web-memory", "ecs-web-running-tasks"])
    error_message = "Un servicio ECS debe generar alarmas de CPU, memoria y tareas en ejecución."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["ecs-web-running-tasks"].namespace == "ECS/ContainerInsights" &&
      aws_cloudwatch_metric_alarm.simple["ecs-web-running-tasks"].comparison_operator == "LessThanThreshold" &&
      aws_cloudwatch_metric_alarm.simple["ecs-web-running-tasks"].threshold == 2 &&
      aws_cloudwatch_metric_alarm.simple["ecs-web-running-tasks"].treat_missing_data == "breaching" &&
      aws_cloudwatch_metric_alarm.simple["ecs-web-cpu"].treat_missing_data == "notBreaching"
    )
    error_message = "La alarma de tareas salta si hay menos que el mínimo o no hay datos; las de CPU no se activan sin datos."
  }
}

run "aurora_replica_lag_alarm_only_with_replicas" {
  command = plan

  variables {
    aurora_clusters = {
      solo = { cluster_id = "acme-dev-aurora" }
      ha   = { cluster_id = "acme-prod-aurora", has_replicas = true }
    }
  }

  assert {
    condition = toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset([
      "aurora-solo-cpu", "aurora-solo-freeable-memory", "aurora-solo-connections",
      "aurora-ha-cpu", "aurora-ha-freeable-memory", "aurora-ha-connections", "aurora-ha-replica-lag",
    ])
    error_message = "El retraso de réplica solo se vigila si el cluster tiene réplicas."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["aurora-ha-cpu"].dimensions["DBClusterIdentifier"] == "acme-prod-aurora" &&
      aws_cloudwatch_metric_alarm.simple["aurora-ha-freeable-memory"].comparison_operator == "LessThanThreshold" &&
      aws_cloudwatch_metric_alarm.simple["aurora-ha-freeable-memory"].threshold == 268435456
    )
    error_message = "Las alarmas de Aurora usan DBClusterIdentifier y la memoria libre salta por debajo del umbral."
  }
}

run "rds_has_free_storage_alarm" {
  command = plan

  variables {
    rds_instances = {
      main = { instance_id = "acme-dev-postgres" }
    }
  }

  assert {
    condition = toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset([
      "rds-main-cpu", "rds-main-freeable-memory", "rds-main-connections", "rds-main-free-storage",
    ])
    error_message = "RDS debe vigilar CPU, memoria, conexiones y almacenamiento libre."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["rds-main-free-storage"].comparison_operator == "LessThanThreshold" &&
      aws_cloudwatch_metric_alarm.simple["rds-main-free-storage"].threshold == 10737418240 &&
      aws_cloudwatch_metric_alarm.simple["rds-main-cpu"].dimensions["DBInstanceIdentifier"] == "acme-dev-postgres"
    )
    error_message = "El almacenamiento libre salta por debajo de 10 GiB y las alarmas usan DBInstanceIdentifier."
  }
}

run "elasticache_creates_alarms_per_node_with_stable_names" {
  command = plan

  variables {
    elasticache = {
      sessions = { replication_group_id = "acme-dev-valkey", node_count = 2 }
    }
  }

  assert {
    condition = toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset([
      "cache-sessions-001-engine-cpu", "cache-sessions-001-memory", "cache-sessions-001-evictions",
      "cache-sessions-002-engine-cpu", "cache-sessions-002-memory", "cache-sessions-002-evictions",
    ])
    error_message = "Debe haber tres alarmas por nodo con claves estables <grupo>-<nnn>."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["cache-sessions-002-engine-cpu"].dimensions["CacheClusterId"] == "acme-dev-valkey-002" &&
      aws_cloudwatch_metric_alarm.simple["cache-sessions-001-evictions"].statistic == "Sum"
    )
    error_message = "Los nodos se llaman <replication_group_id>-<nnn> y las expulsiones se suman."
  }
}

run "dynamodb_sums_throttles_and_system_errors_across_operations" {
  command = plan

  variables {
    dynamodb_tables = {
      orders = { table_name = "acme-dev-orders", operations = ["GetItem", "PutItem", "Query"] }
    }
  }

  assert {
    condition     = toset(keys(aws_cloudwatch_metric_alarm.dynamodb)) == toset(["dynamodb-orders-throttled-requests", "dynamodb-orders-system-errors"])
    error_message = "Una tabla debe generar las alarmas de peticiones limitadas y errores del sistema."
  }

  assert {
    condition = (
      length(aws_cloudwatch_metric_alarm.dynamodb["dynamodb-orders-throttled-requests"].metric_query) == 4 &&
      anytrue([for q in aws_cloudwatch_metric_alarm.dynamodb["dynamodb-orders-throttled-requests"].metric_query : q.id == "total" && q.expression == "SUM(METRICS())" && q.return_data == true]) &&
      length([for q in aws_cloudwatch_metric_alarm.dynamodb["dynamodb-orders-system-errors"].metric_query : q if q.return_data == false]) == 3
    )
    error_message = "Debe haber una métrica por operación (sin devolver datos) y una expresión SUM(METRICS()) que sí los devuelve."
  }

  assert {
    condition = alltrue([
      for q in aws_cloudwatch_metric_alarm.dynamodb["dynamodb-orders-system-errors"].metric_query :
      alltrue([for m in q.metric : m.metric_name == "SystemErrors" && m.stat == "Sum" && m.dimensions["TableName"] == "acme-dev-orders"])
    ])
    error_message = "Cada métrica por operación debe ser SystemErrors, con Sum y la dimensión TableName."
  }
}

run "lambda_duration_threshold_follows_timeout_ratio" {
  command = plan

  variables {
    lambda_functions = {
      worker = { function_name = "acme-dev-worker", timeout_seconds = 30 }
    }
  }

  assert {
    condition     = toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset(["lambda-worker-errors", "lambda-worker-throttles", "lambda-worker-duration-p95"])
    error_message = "Una función debe generar alarmas de errores, limitaciones y duración p95."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["lambda-worker-duration-p95"].extended_statistic == "p95" &&
      aws_cloudwatch_metric_alarm.simple["lambda-worker-duration-p95"].threshold == 24000
    )
    error_message = "El umbral de duración debe ser el 80 % del timeout, en milisegundos."
  }
}

run "api_gateway_rest_and_http_use_their_own_metric_names" {
  command = plan

  variables {
    rest_apis = {
      public = { api_name = "acme-dev-api", stage = "v1" }
    }
    http_apis = {
      internal = { api_id = "a1b2c3d4e5" }
    }
  }

  assert {
    condition = toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset([
      "apigw-rest-public-5xx", "apigw-rest-public-latency-p95", "apigw-http-internal-5xx", "apigw-http-internal-latency-p95",
    ])
    error_message = "Cada API debe generar alarmas de 5xx y de latencia p95."
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["apigw-rest-public-5xx"].metric_name == "5XXError" &&
      aws_cloudwatch_metric_alarm.simple["apigw-http-internal-5xx"].metric_name == "5xx" &&
      aws_cloudwatch_metric_alarm.simple["apigw-http-internal-5xx"].dimensions["ApiId"] == "a1b2c3d4e5" &&
      aws_cloudwatch_metric_alarm.simple["apigw-http-internal-5xx"].dimensions["Stage"] == "$default"
    )
    error_message = "Las APIs REST y HTTP usan nombres de métrica y dimensiones distintos."
  }
}

run "waf_uses_anomaly_detection_band" {
  command = plan

  variables {
    waf_web_acls = {
      edge = { web_acl_name = "acme-dev-edge" }
    }
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.waf_anomaly["edge"].comparison_operator == "GreaterThanUpperThreshold" &&
      aws_cloudwatch_metric_alarm.waf_anomaly["edge"].threshold_metric_id == "band" &&
      anytrue([for q in aws_cloudwatch_metric_alarm.waf_anomaly["edge"].metric_query : q.id == "band" && q.expression == "ANOMALY_DETECTION_BAND(blocked, 4)"])
    )
    error_message = "BlockedRequests debe vigilarse con una banda de detección de anomalías."
  }

  assert {
    condition = anytrue([
      for q in aws_cloudwatch_metric_alarm.waf_anomaly["edge"].metric_query :
      anytrue([for m in q.metric : m.metric_name == "BlockedRequests" && m.dimensions["Region"] == "Global" && m.dimensions["Rule"] == "ALL"])
    ])
    error_message = "La métrica es BlockedRequests con Rule = ALL y la región Global por defecto."
  }
}

run "cloudfront_error_rate_alarm" {
  command = plan

  variables {
    cloudfront_distributions = {
      site = { distribution_id = "E1ABCDEFGHIJKL" }
    }
  }

  assert {
    condition = (
      toset(keys(aws_cloudwatch_metric_alarm.simple)) == toset(["cloudfront-site-5xx-rate"]) &&
      aws_cloudwatch_metric_alarm.simple["cloudfront-site-5xx-rate"].metric_name == "5xxErrorRate" &&
      aws_cloudwatch_metric_alarm.simple["cloudfront-site-5xx-rate"].threshold == 5 &&
      aws_cloudwatch_metric_alarm.simple["cloudfront-site-5xx-rate"].dimensions["Region"] == "Global"
    )
    error_message = "CloudFront debe vigilar 5xxErrorRate con la dimensión Region = Global."
  }
}

run "all_alarms_notify_the_topic_on_alarm_and_ok" {
  command = apply

  variables {
    alb = {
      web = { alb_arn_suffix = "app/acme-dev-web/50dc6c", target_group_arn_suffix = "targetgroup/acme-dev-web/73e2d6" }
    }
    dynamodb_tables = {
      orders = { table_name = "acme-dev-orders" }
    }
    waf_web_acls = {
      edge = { web_acl_name = "acme-dev-edge" }
    }
  }

  assert {
    condition = alltrue(concat(
      [for a in aws_cloudwatch_metric_alarm.simple : contains(a.alarm_actions, "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms") && contains(a.ok_actions, "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms")],
      [for a in aws_cloudwatch_metric_alarm.dynamodb : contains(a.alarm_actions, "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms")],
      [for a in aws_cloudwatch_metric_alarm.waf_anomaly : contains(a.alarm_actions, "arn:aws:sns:us-east-1:123456789012:acme-dev-alarms")],
    ))
    error_message = "Todas las alarmas deben notificar al topic cifrado."
  }

  assert {
    condition     = output.alarm_count == 6 && length(output.alarm_arns) == 6
    error_message = "3 de ALB + 2 de DynamoDB + 1 de WAF = 6 alarmas, todas en alarm_arns."
  }
}

run "thresholds_can_be_overridden" {
  command = plan

  variables {
    thresholds = { period_seconds = 60, evaluation_periods = 5, datapoints_to_alarm = 5, alb_target_5xx_count = 3 }
    alb = {
      web = { alb_arn_suffix = "app/acme-dev-web/50dc6c", target_group_arn_suffix = "targetgroup/acme-dev-web/73e2d6" }
    }
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.simple["alb-web-target-5xx"].threshold == 3 &&
      aws_cloudwatch_metric_alarm.simple["alb-web-target-5xx"].period == 60 &&
      aws_cloudwatch_metric_alarm.simple["alb-web-target-5xx"].evaluation_periods == 5 &&
      aws_cloudwatch_metric_alarm.simple["alb-web-target-5xx"].datapoints_to_alarm == 5
    )
    error_message = "Los umbrales y las ventanas deben poder ajustarse."
  }
}

run "rejects_prod_without_email" {
  command = plan

  variables {
    environment = "prod"
  }

  expect_failures = [var.email_subscriptions]
}

run "rejects_invalid_email" {
  command = plan

  variables {
    email_subscriptions = ["not-an-email"]
  }

  expect_failures = [var.email_subscriptions]
}

run "rejects_publishers_without_cloudwatch" {
  command = plan

  variables {
    publisher_service_principals = ["events.amazonaws.com"]
  }

  expect_failures = [var.publisher_service_principals]
}

run "rejects_datapoints_above_evaluation_periods" {
  command = plan

  variables {
    thresholds = { evaluation_periods = 2, datapoints_to_alarm = 3 }
  }

  expect_failures = [var.thresholds]
}

run "rejects_period_not_multiple_of_60" {
  command = plan

  variables {
    thresholds = { period_seconds = 90 }
  }

  expect_failures = [var.thresholds]
}

run "rejects_node_count_above_6" {
  command = plan

  variables {
    elasticache = {
      sessions = { replication_group_id = "acme-dev-valkey", node_count = 7 }
    }
  }

  expect_failures = [var.elasticache]
}

run "rejects_zero_min_running_tasks" {
  command = plan

  variables {
    ecs_services = {
      web = { cluster_name = "c", service_name = "s", min_running_tasks = 0 }
    }
  }

  expect_failures = [var.ecs_services]
}

run "rejects_alias_as_kms_key" {
  command = plan

  variables {
    kms_key_arn = "arn:aws:kms:us-east-1:123456789012:alias/acme"
  }

  expect_failures = [var.kms_key_arn]
}

run "existing_topic_is_reused_without_creating_one" {
  command = plan

  variables {
    existing_topic_arn = "arn:aws:sns:us-east-1:123456789012:acme-dev-platform-alarms"
    lambda_functions = {
      api = { function_name = "acme-dev-api" }
    }
  }

  assert {
    condition = (
      length(aws_sns_topic.this) == 0 &&
      length(aws_sns_topic_policy.this) == 0 &&
      length(aws_sns_topic_subscription.email) == 0 &&
      output.topic_arn == "arn:aws:sns:us-east-1:123456789012:acme-dev-platform-alarms"
    )
    error_message = "Con existing_topic_arn no se crea topic, política ni suscripciones."
  }

  assert {
    condition = length(aws_cloudwatch_metric_alarm.simple) > 0 && alltrue([
      for a in aws_cloudwatch_metric_alarm.simple :
      toset(a.alarm_actions) == toset(["arn:aws:sns:us-east-1:123456789012:acme-dev-platform-alarms"])
    ])
    error_message = "Las alarmas deben notificar al topic existente."
  }
}

run "existing_topic_satisfies_prod_recipients" {
  command = plan

  variables {
    environment        = "prod"
    existing_topic_arn = "arn:aws:sns:us-east-1:123456789012:acme-prod-platform-alarms"
  }

  assert {
    condition     = output.topic_arn == "arn:aws:sns:us-east-1:123456789012:acme-prod-platform-alarms"
    error_message = "En prod basta un topic existente (sus suscripciones se gestionan donde se creó)."
  }
}

run "rejects_emails_with_existing_topic" {
  command = plan

  variables {
    existing_topic_arn  = "arn:aws:sns:us-east-1:123456789012:acme-dev-platform-alarms"
    email_subscriptions = ["ops@example.com"]
  }

  expect_failures = [var.email_subscriptions]
}
