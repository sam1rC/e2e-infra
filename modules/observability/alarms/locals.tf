locals {
  name = coalesce(var.name, "${var.project}-${var.environment}")

  create_topic = var.existing_topic_arn == null
  topic_arn    = local.create_topic ? aws_sns_topic.this[0].arn : var.existing_topic_arn

  t = var.thresholds

  # Valores comunes de las alarmas simples. Las métricas de recuento usan notBreaching: sin tráfico no hay error.
  base = {
    statistic           = "Average"
    extended_statistic  = ""
    comparison_operator = "GreaterThanThreshold"
    treat_missing_data  = "notBreaching"
  }

  alb_alarms = merge([
    for k, a in var.alb : {
      "alb-${k}-target-5xx" = merge(local.base, {
        description = "ALB ${k}: respuestas 5XX de los targets"
        namespace   = "AWS/ApplicationELB"
        metric_name = "HTTPCode_Target_5XX_Count"
        dimensions  = tomap({ LoadBalancer = a.alb_arn_suffix })
        statistic   = "Sum"
        threshold   = local.t.alb_target_5xx_count
      })
      "alb-${k}-response-time-p99" = merge(local.base, {
        description        = "ALB ${k}: latencia p99 de los targets"
        namespace          = "AWS/ApplicationELB"
        metric_name        = "TargetResponseTime"
        dimensions         = tomap({ LoadBalancer = a.alb_arn_suffix })
        statistic          = ""
        extended_statistic = "p99"
        threshold          = local.t.alb_response_time_p99_seconds
      })
      "alb-${k}-unhealthy-hosts" = merge(local.base, {
        description         = "ALB ${k}: targets no saludables"
        namespace           = "AWS/ApplicationELB"
        metric_name         = "UnHealthyHostCount"
        dimensions          = tomap({ LoadBalancer = a.alb_arn_suffix, TargetGroup = a.target_group_arn_suffix })
        statistic           = "Maximum"
        comparison_operator = "GreaterThanOrEqualToThreshold"
        threshold           = local.t.alb_unhealthy_hosts
      })
    }
  ]...)

  ecs_alarms = merge([
    for k, s in var.ecs_services : {
      "ecs-${k}-cpu" = merge(local.base, {
        description = "ECS ${k}: CPU alta"
        namespace   = "AWS/ECS"
        metric_name = "CPUUtilization"
        dimensions  = tomap({ ClusterName = s.cluster_name, ServiceName = s.service_name })
        threshold   = local.t.ecs_cpu_percent
      })
      "ecs-${k}-memory" = merge(local.base, {
        description = "ECS ${k}: memoria alta"
        namespace   = "AWS/ECS"
        metric_name = "MemoryUtilization"
        dimensions  = tomap({ ClusterName = s.cluster_name, ServiceName = s.service_name })
        threshold   = local.t.ecs_memory_percent
      })
      # Sin datos es que no hay tareas informando: se trata como incumplimiento.
      "ecs-${k}-running-tasks" = merge(local.base, {
        description         = "ECS ${k}: menos tareas en ejecución que el mínimo"
        namespace           = "ECS/ContainerInsights"
        metric_name         = "RunningTaskCount"
        dimensions          = tomap({ ClusterName = s.cluster_name, ServiceName = s.service_name })
        statistic           = "Minimum"
        comparison_operator = "LessThanThreshold"
        treat_missing_data  = "breaching"
        threshold           = s.min_running_tasks
      })
    }
  ]...)

  aurora_alarms = merge([
    for k, c in var.aurora_clusters : merge(
      {
        "aurora-${k}-cpu" = merge(local.base, {
          description = "Aurora ${k}: CPU alta"
          namespace   = "AWS/RDS"
          metric_name = "CPUUtilization"
          dimensions  = tomap({ DBClusterIdentifier = c.cluster_id })
          threshold   = local.t.db_cpu_percent
        })
        "aurora-${k}-freeable-memory" = merge(local.base, {
          description         = "Aurora ${k}: poca memoria libre"
          namespace           = "AWS/RDS"
          metric_name         = "FreeableMemory"
          dimensions          = tomap({ DBClusterIdentifier = c.cluster_id })
          statistic           = "Minimum"
          comparison_operator = "LessThanThreshold"
          threshold           = local.t.db_freeable_memory_bytes
        })
        "aurora-${k}-connections" = merge(local.base, {
          description = "Aurora ${k}: demasiadas conexiones"
          namespace   = "AWS/RDS"
          metric_name = "DatabaseConnections"
          dimensions  = tomap({ DBClusterIdentifier = c.cluster_id })
          statistic   = "Maximum"
          threshold   = local.t.db_connections
        })
      },
      c.has_replicas ? {
        "aurora-${k}-replica-lag" = merge(local.base, {
          description = "Aurora ${k}: retraso de réplica"
          namespace   = "AWS/RDS"
          metric_name = "AuroraReplicaLag"
          dimensions  = tomap({ DBClusterIdentifier = c.cluster_id })
          statistic   = "Maximum"
          threshold   = local.t.aurora_replica_lag_milliseconds
        })
      } : null,
    )
  ]...)

  rds_alarms = merge([
    for k, i in var.rds_instances : {
      "rds-${k}-cpu" = merge(local.base, {
        description = "RDS ${k}: CPU alta"
        namespace   = "AWS/RDS"
        metric_name = "CPUUtilization"
        dimensions  = tomap({ DBInstanceIdentifier = i.instance_id })
        threshold   = local.t.db_cpu_percent
      })
      "rds-${k}-freeable-memory" = merge(local.base, {
        description         = "RDS ${k}: poca memoria libre"
        namespace           = "AWS/RDS"
        metric_name         = "FreeableMemory"
        dimensions          = tomap({ DBInstanceIdentifier = i.instance_id })
        statistic           = "Minimum"
        comparison_operator = "LessThanThreshold"
        threshold           = local.t.db_freeable_memory_bytes
      })
      "rds-${k}-connections" = merge(local.base, {
        description = "RDS ${k}: demasiadas conexiones"
        namespace   = "AWS/RDS"
        metric_name = "DatabaseConnections"
        dimensions  = tomap({ DBInstanceIdentifier = i.instance_id })
        statistic   = "Maximum"
        threshold   = local.t.db_connections
      })
      "rds-${k}-free-storage" = merge(local.base, {
        description         = "RDS ${k}: poco almacenamiento libre"
        namespace           = "AWS/RDS"
        metric_name         = "FreeStorageSpace"
        dimensions          = tomap({ DBInstanceIdentifier = i.instance_id })
        statistic           = "Minimum"
        comparison_operator = "LessThanThreshold"
        threshold           = local.t.rds_free_storage_bytes
      })
    }
  ]...)

  # Una alarma por nodo: las métricas de ElastiCache se publican por CacheClusterId (<grupo>-001, -002...).
  cache_nodes = merge([
    for k, g in var.elasticache : {
      for n in range(1, g.node_count + 1) : "${k}-${format("%03d", n)}" => format("%s-%03d", g.replication_group_id, n)
    }
  ]...)

  cache_alarms = merge([
    for key, node_id in local.cache_nodes : {
      "cache-${key}-engine-cpu" = merge(local.base, {
        description = "ElastiCache ${key}: CPU del motor alta"
        namespace   = "AWS/ElastiCache"
        metric_name = "EngineCPUUtilization"
        dimensions  = tomap({ CacheClusterId = node_id })
        threshold   = local.t.cache_engine_cpu_percent
      })
      "cache-${key}-memory" = merge(local.base, {
        description = "ElastiCache ${key}: memoria usada alta"
        namespace   = "AWS/ElastiCache"
        metric_name = "DatabaseMemoryUsagePercentage"
        dimensions  = tomap({ CacheClusterId = node_id })
        threshold   = local.t.cache_memory_percent
      })
      "cache-${key}-evictions" = merge(local.base, {
        description = "ElastiCache ${key}: expulsiones de claves"
        namespace   = "AWS/ElastiCache"
        metric_name = "Evictions"
        dimensions  = tomap({ CacheClusterId = node_id })
        statistic   = "Sum"
        threshold   = local.t.cache_evictions
      })
    }
  ]...)

  lambda_alarms = merge([
    for k, f in var.lambda_functions : {
      "lambda-${k}-errors" = merge(local.base, {
        description = "Lambda ${k}: errores"
        namespace   = "AWS/Lambda"
        metric_name = "Errors"
        dimensions  = tomap({ FunctionName = f.function_name })
        statistic   = "Sum"
        threshold   = local.t.lambda_errors
      })
      "lambda-${k}-throttles" = merge(local.base, {
        description = "Lambda ${k}: invocaciones limitadas"
        namespace   = "AWS/Lambda"
        metric_name = "Throttles"
        dimensions  = tomap({ FunctionName = f.function_name })
        statistic   = "Sum"
        threshold   = local.t.lambda_throttles
      })
      "lambda-${k}-duration-p95" = merge(local.base, {
        description        = "Lambda ${k}: duración p95 cerca del timeout"
        namespace          = "AWS/Lambda"
        metric_name        = "Duration"
        dimensions         = tomap({ FunctionName = f.function_name })
        statistic          = ""
        extended_statistic = "p95"
        threshold          = f.timeout_seconds * 1000 * local.t.lambda_duration_p95_ratio
      })
    }
  ]...)

  api_alarms = merge(
    merge([
      for k, a in var.rest_apis : {
        "apigw-rest-${k}-5xx" = merge(local.base, {
          description = "API REST ${k}: errores 5XX"
          namespace   = "AWS/ApiGateway"
          metric_name = "5XXError"
          dimensions  = tomap({ ApiName = a.api_name, Stage = a.stage })
          statistic   = "Sum"
          threshold   = local.t.api_5xx_count
        })
        "apigw-rest-${k}-latency-p95" = merge(local.base, {
          description        = "API REST ${k}: latencia p95"
          namespace          = "AWS/ApiGateway"
          metric_name        = "Latency"
          dimensions         = tomap({ ApiName = a.api_name, Stage = a.stage })
          statistic          = ""
          extended_statistic = "p95"
          threshold          = local.t.api_latency_p95_milliseconds
        })
      }
    ]...),
    merge([
      for k, a in var.http_apis : {
        "apigw-http-${k}-5xx" = merge(local.base, {
          description = "API HTTP ${k}: errores 5xx"
          namespace   = "AWS/ApiGateway"
          metric_name = "5xx"
          dimensions  = tomap({ ApiId = a.api_id, Stage = a.stage })
          statistic   = "Sum"
          threshold   = local.t.api_5xx_count
        })
        "apigw-http-${k}-latency-p95" = merge(local.base, {
          description        = "API HTTP ${k}: latencia p95"
          namespace          = "AWS/ApiGateway"
          metric_name        = "Latency"
          dimensions         = tomap({ ApiId = a.api_id, Stage = a.stage })
          statistic          = ""
          extended_statistic = "p95"
          threshold          = local.t.api_latency_p95_milliseconds
        })
      }
    ]...),
  )

  cloudfront_alarms = merge([
    for k, d in var.cloudfront_distributions : {
      "cloudfront-${k}-5xx-rate" = merge(local.base, {
        description = "CloudFront ${k}: porcentaje de errores 5xx"
        namespace   = "AWS/CloudFront"
        metric_name = "5xxErrorRate"
        dimensions  = tomap({ DistributionId = d.distribution_id, Region = "Global" })
        threshold   = local.t.cloudfront_5xx_percent
      })
    }
  ]...)

  simple_alarms = merge(
    local.alb_alarms,
    local.ecs_alarms,
    local.aurora_alarms,
    local.rds_alarms,
    local.cache_alarms,
    local.lambda_alarms,
    local.api_alarms,
    local.cloudfront_alarms,
  )

  # Alarmas de DynamoDB (suma por operación): una clave por tabla y métrica.
  dynamodb_alarms = merge([
    for k, t in var.dynamodb_tables : {
      "dynamodb-${k}-throttled-requests" = {
        description = "DynamoDB ${k}: peticiones limitadas"
        table_name  = t.table_name
        operations  = t.operations
        metric_name = "ThrottledRequests"
        threshold   = local.t.dynamodb_throttled_requests
      }
      "dynamodb-${k}-system-errors" = {
        description = "DynamoDB ${k}: errores del sistema"
        table_name  = t.table_name
        operations  = t.operations
        metric_name = "SystemErrors"
        threshold   = local.t.dynamodb_system_errors
      }
    }
  ]...)
}
