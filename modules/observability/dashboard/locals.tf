locals {
  name   = coalesce(var.name, "${var.project}-${var.environment}")
  region = data.aws_region.current.region
  period = var.period_seconds

  # Cada fila de métricas es [namespace, métrica, dimensión, valor, ..., {opciones}].
  alb_widgets = flatten([
    for k, a in var.alb : [
      {
        title  = "ALB ${k}: tráfico y errores"
        region = local.region
        stat   = "Sum"
        metrics = [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", a.alb_arn_suffix, { label = "Peticiones" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", a.alb_arn_suffix, { label = "5XX de los targets" }],
          ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", a.alb_arn_suffix, { label = "5XX del ALB" }],
        ]
      },
      {
        title  = "ALB ${k}: latencia de los targets"
        region = local.region
        stat   = "Average"
        metrics = [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", a.alb_arn_suffix, { stat = "p50", label = "p50" }],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", a.alb_arn_suffix, { stat = "p99", label = "p99" }],
        ]
      },
      {
        title  = "ALB ${k}: targets saludables"
        region = local.region
        stat   = "Maximum"
        metrics = [
          ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", a.alb_arn_suffix, "TargetGroup", a.target_group_arn_suffix, { label = "Saludables" }],
          ["AWS/ApplicationELB", "UnHealthyHostCount", "LoadBalancer", a.alb_arn_suffix, "TargetGroup", a.target_group_arn_suffix, { label = "No saludables" }],
        ]
      },
    ]
  ])

  ecs_widgets = flatten([
    for k, s in var.ecs_services : [
      {
        title  = "ECS ${k}: CPU y memoria (%)"
        region = local.region
        stat   = "Average"
        metrics = [
          ["AWS/ECS", "CPUUtilization", "ClusterName", s.cluster_name, "ServiceName", s.service_name, { label = "CPU" }],
          ["AWS/ECS", "MemoryUtilization", "ClusterName", s.cluster_name, "ServiceName", s.service_name, { label = "Memoria" }],
        ]
      },
      {
        title  = "ECS ${k}: tareas"
        region = local.region
        stat   = "Average"
        metrics = [
          ["ECS/ContainerInsights", "RunningTaskCount", "ClusterName", s.cluster_name, "ServiceName", s.service_name, { label = "En ejecución" }],
          ["ECS/ContainerInsights", "DesiredTaskCount", "ClusterName", s.cluster_name, "ServiceName", s.service_name, { label = "Deseadas" }],
        ]
      },
    ]
  ])

  aurora_widgets = flatten([
    for k, c in var.aurora_clusters : [
      {
        title  = "Aurora ${k}: CPU (%) y conexiones"
        region = local.region
        stat   = "Average"
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", c.cluster_id, { label = "CPU" }],
          ["AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", c.cluster_id, { label = "Conexiones", yAxis = "right" }],
        ]
      },
      {
        title  = "Aurora ${k}: memoria libre y retraso de réplica"
        region = local.region
        stat   = "Average"
        metrics = [
          ["AWS/RDS", "FreeableMemory", "DBClusterIdentifier", c.cluster_id, { label = "Memoria libre (bytes)" }],
          ["AWS/RDS", "AuroraReplicaLag", "DBClusterIdentifier", c.cluster_id, { label = "Retraso de réplica (ms)", yAxis = "right" }],
        ]
      },
    ]
  ])

  rds_widgets = flatten([
    for k, i in var.rds_instances : [
      {
        title  = "RDS ${k}: CPU (%) y conexiones"
        region = local.region
        stat   = "Average"
        metrics = [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", i.instance_id, { label = "CPU" }],
          ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", i.instance_id, { label = "Conexiones", yAxis = "right" }],
        ]
      },
      {
        title  = "RDS ${k}: memoria y almacenamiento libres"
        region = local.region
        stat   = "Average"
        metrics = [
          ["AWS/RDS", "FreeableMemory", "DBInstanceIdentifier", i.instance_id, { label = "Memoria libre (bytes)" }],
          ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", i.instance_id, { label = "Almacenamiento libre (bytes)", yAxis = "right" }],
        ]
      },
    ]
  ])

  cache_nodes = {
    for k, g in var.elasticache : k => [for n in range(1, g.node_count + 1) : format("%s-%03d", g.replication_group_id, n)]
  }

  cache_widgets = flatten([
    for k, nodes in local.cache_nodes : [
      {
        title  = "ElastiCache ${k}: CPU del motor y memoria (%)"
        region = local.region
        stat   = "Average"
        # concat y no flatten: flatten aplanaría también cada fila de métricas.
        metrics = concat(
          [for n in nodes : ["AWS/ElastiCache", "EngineCPUUtilization", "CacheClusterId", n, { label = "CPU ${n}" }]],
          [for n in nodes : ["AWS/ElastiCache", "DatabaseMemoryUsagePercentage", "CacheClusterId", n, { label = "Memoria ${n}", yAxis = "right" }]],
        )
      },
      {
        title  = "ElastiCache ${k}: expulsiones y conexiones"
        region = local.region
        stat   = "Sum"
        metrics = concat(
          [for n in nodes : ["AWS/ElastiCache", "Evictions", "CacheClusterId", n, { label = "Expulsiones ${n}" }]],
          [for n in nodes : ["AWS/ElastiCache", "CurrConnections", "CacheClusterId", n, { label = "Conexiones ${n}", stat = "Average", yAxis = "right" }]],
        )
      },
    ]
  ])

  dynamodb_widgets = flatten([
    for k, t in var.dynamodb_tables : [
      {
        title  = "DynamoDB ${k}: capacidad consumida"
        region = local.region
        stat   = "Sum"
        metrics = [
          ["AWS/DynamoDB", "ConsumedReadCapacityUnits", "TableName", t.table_name, { label = "Lectura" }],
          ["AWS/DynamoDB", "ConsumedWriteCapacityUnits", "TableName", t.table_name, { label = "Escritura" }],
        ]
      },
      {
        title  = "DynamoDB ${k}: limitaciones"
        region = local.region
        stat   = "Sum"
        metrics = [
          ["AWS/DynamoDB", "ReadThrottleEvents", "TableName", t.table_name, { label = "Lecturas limitadas" }],
          ["AWS/DynamoDB", "WriteThrottleEvents", "TableName", t.table_name, { label = "Escrituras limitadas" }],
        ]
      },
    ]
  ])

  lambda_widgets = flatten([
    for k, f in var.lambda_functions : [
      {
        title  = "Lambda ${k}: invocaciones, errores y limitaciones"
        region = local.region
        stat   = "Sum"
        metrics = [
          ["AWS/Lambda", "Invocations", "FunctionName", f.function_name, { label = "Invocaciones" }],
          ["AWS/Lambda", "Errors", "FunctionName", f.function_name, { label = "Errores" }],
          ["AWS/Lambda", "Throttles", "FunctionName", f.function_name, { label = "Limitadas" }],
        ]
      },
      {
        title  = "Lambda ${k}: duración (ms)"
        region = local.region
        stat   = "Average"
        metrics = [
          ["AWS/Lambda", "Duration", "FunctionName", f.function_name, { stat = "p50", label = "p50" }],
          ["AWS/Lambda", "Duration", "FunctionName", f.function_name, { stat = "p95", label = "p95" }],
          ["AWS/Lambda", "Duration", "FunctionName", f.function_name, { stat = "Maximum", label = "máx." }],
        ]
      },
    ]
  ])

  api_widgets = concat(
    flatten([
      for k, a in var.rest_apis : [
        {
          title  = "API REST ${k}: peticiones y errores"
          region = local.region
          stat   = "Sum"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiName", a.api_name, "Stage", a.stage, { label = "Peticiones" }],
            ["AWS/ApiGateway", "4XXError", "ApiName", a.api_name, "Stage", a.stage, { label = "4XX" }],
            ["AWS/ApiGateway", "5XXError", "ApiName", a.api_name, "Stage", a.stage, { label = "5XX" }],
          ]
        },
        {
          title  = "API REST ${k}: latencia (ms)"
          region = local.region
          stat   = "Average"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", a.api_name, "Stage", a.stage, { stat = "p50", label = "p50" }],
            ["AWS/ApiGateway", "Latency", "ApiName", a.api_name, "Stage", a.stage, { stat = "p95", label = "p95" }],
            ["AWS/ApiGateway", "IntegrationLatency", "ApiName", a.api_name, "Stage", a.stage, { stat = "p95", label = "integración p95" }],
          ]
        },
      ]
    ]),
    flatten([
      for k, a in var.http_apis : [
        {
          title  = "API HTTP ${k}: peticiones y errores"
          region = local.region
          stat   = "Sum"
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", a.api_id, "Stage", a.stage, { label = "Peticiones" }],
            ["AWS/ApiGateway", "4xx", "ApiId", a.api_id, "Stage", a.stage, { label = "4xx" }],
            ["AWS/ApiGateway", "5xx", "ApiId", a.api_id, "Stage", a.stage, { label = "5xx" }],
          ]
        },
        {
          title  = "API HTTP ${k}: latencia (ms)"
          region = local.region
          stat   = "Average"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", a.api_id, "Stage", a.stage, { stat = "p50", label = "p50" }],
            ["AWS/ApiGateway", "Latency", "ApiId", a.api_id, "Stage", a.stage, { stat = "p95", label = "p95" }],
          ]
        },
      ]
    ]),
  )

  cloudfront_widgets = flatten([
    for k, d in var.cloudfront_distributions : [
      {
        title  = "CloudFront ${k}: peticiones"
        region = "us-east-1"
        stat   = "Sum"
        metrics = [
          ["AWS/CloudFront", "Requests", "DistributionId", d.distribution_id, "Region", "Global", { label = "Peticiones" }],
        ]
      },
      {
        title  = "CloudFront ${k}: tasa de error (%)"
        region = "us-east-1"
        stat   = "Average"
        metrics = [
          ["AWS/CloudFront", "4xxErrorRate", "DistributionId", d.distribution_id, "Region", "Global", { label = "4xx" }],
          ["AWS/CloudFront", "5xxErrorRate", "DistributionId", d.distribution_id, "Region", "Global", { label = "5xx" }],
        ]
      },
    ]
  ])

  waf_widgets = flatten([
    for k, w in var.waf_web_acls : [
      {
        title  = "WAF ${k}: peticiones permitidas y bloqueadas"
        region = w.region_dimension == "Global" ? "us-east-1" : w.region_dimension
        stat   = "Sum"
        metrics = [
          ["AWS/WAFV2", "AllowedRequests", "WebACL", w.web_acl_name, "Rule", "ALL", "Region", w.region_dimension, { label = "Permitidas" }],
          ["AWS/WAFV2", "BlockedRequests", "WebACL", w.web_acl_name, "Rule", "ALL", "Region", w.region_dimension, { label = "Bloqueadas" }],
        ]
      },
    ]
  ])

  # Application Signals: la disponibilidad se calcula como 1 - fallos / peticiones (nº de muestras de Latency).
  app_signals_dims = var.application_signals == null ? [] : ["Service", var.application_signals.service_name, "Environment", var.application_signals.environment_name]

  app_signals_widgets = flatten([for svc in var.application_signals == null ? [] : [var.application_signals] : [
    {
      title  = "Application Signals ${svc.service_name}: latencia (ms)"
      region = local.region
      stat   = "Average"
      metrics = [
        concat(["ApplicationSignals", "Latency"], local.app_signals_dims, [{ stat = "p50", label = "p50" }]),
        concat(["ApplicationSignals", "Latency"], local.app_signals_dims, [{ stat = "p99", label = "p99" }]),
      ]
    },
    {
      title  = "Application Signals ${svc.service_name}: fallos y errores"
      region = local.region
      stat   = "Sum"
      metrics = [
        concat(["ApplicationSignals", "Fault"], local.app_signals_dims, [{ label = "Fallos (5xx)" }]),
        concat(["ApplicationSignals", "Error"], local.app_signals_dims, [{ label = "Errores (4xx)" }]),
      ]
    },
    {
      title  = "Application Signals ${svc.service_name}: disponibilidad (%)"
      region = local.region
      stat   = "Sum"
      metrics = [
        [{ expression = "100 * (1 - fault / total)", label = "Disponibilidad", id = "availability" }],
        concat(["ApplicationSignals", "Fault"], local.app_signals_dims, [{ id = "fault", visible = false }]),
        concat(["ApplicationSignals", "Latency"], local.app_signals_dims, [{ id = "total", stat = "SampleCount", visible = false }]),
      ]
    },
    ]
  ])

  metric_widgets = concat(
    local.app_signals_widgets,
    local.cloudfront_widgets,
    local.waf_widgets,
    local.alb_widgets,
    local.ecs_widgets,
    local.lambda_widgets,
    local.api_widgets,
    local.aurora_widgets,
    local.rds_widgets,
    local.cache_widgets,
    local.dynamodb_widgets,
  )

  # Cuadrícula de 2 columnas (12 de ancho cada una) bajo el widget de alarmas, que ocupa 24 x 3 si existe.
  alarm_widgets = length(var.alarm_arns) == 0 ? [] : [
    {
      type   = "alarm"
      x      = 0
      y      = 0
      width  = 24
      height = 3
      properties = {
        title  = "Estado de las alarmas"
        alarms = sort(values(var.alarm_arns))
      }
    }
  ]

  grid_top = length(var.alarm_arns) == 0 ? 0 : 3

  grid_widgets = [
    for i, w in local.metric_widgets : {
      type   = "metric"
      x      = (i % 2) * 12
      y      = local.grid_top + floor(i / 2) * 6
      width  = 12
      height = 6
      properties = {
        view    = "timeSeries"
        stacked = false
        title   = w.title
        region  = w.region
        stat    = w.stat
        period  = local.period
        metrics = w.metrics
      }
    }
  ]

  widgets = concat(local.alarm_widgets, local.grid_widgets)
}
