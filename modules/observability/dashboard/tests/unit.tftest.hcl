mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      region = "us-east-1"
    }
  }
}

variables {
  project     = "acme"
  environment = "dev"
}

run "empty_dashboard_has_no_widgets" {
  command = plan

  assert {
    condition     = aws_cloudwatch_dashboard.this.dashboard_name == "acme-dev" && length(jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets) == 0
    error_message = "Sin recursos declarados el dashboard no debe tener widgets."
  }
}

run "name_can_be_overridden_per_blueprint" {
  command = plan

  variables {
    name = "acme-prod-ecommerce-t1"
  }

  assert {
    condition     = aws_cloudwatch_dashboard.this.dashboard_name == "acme-prod-ecommerce-t1"
    error_message = "El nombre del dashboard debe poder fijarse por blueprint."
  }
}

run "each_resource_type_adds_its_widgets" {
  command = plan

  variables {
    alb             = { web = { alb_arn_suffix = "app/acme-dev-web/50dc6c", target_group_arn_suffix = "targetgroup/acme-dev-web/73e2d6" } }
    ecs_services    = { web = { cluster_name = "acme-dev", service_name = "acme-dev-web" } }
    aurora_clusters = { main = { cluster_id = "acme-dev-aurora" } }
    rds_instances   = { reports = { instance_id = "acme-dev-postgres" } }
    elasticache     = { sessions = { replication_group_id = "acme-dev-valkey", node_count = 2 } }
    dynamodb_tables = { orders = { table_name = "acme-dev-orders" } }
    lambda_functions = {
      worker = { function_name = "acme-dev-worker" }
    }
    rest_apis = { public = { api_name = "acme-dev-api", stage = "v1" } }
    http_apis = { internal = { api_id = "a1b2c3d4e5" } }
  }

  # ALB 3 + ECS 2 + Aurora 2 + RDS 2 + Valkey 2 + DynamoDB 2 + Lambda 2 + REST 2 + HTTP 2 = 19
  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets) == 19
    error_message = "Cada tipo de recurso debe añadir sus widgets (19 en total para esta configuración)."
  }

  assert {
    condition     = alltrue([for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets : w.type == "metric" && w.width == 12 && w.height == 6])
    error_message = "Sin alarmas, todos los widgets son de métricas de 12 x 6."
  }
}

run "widgets_are_laid_out_in_a_two_column_grid" {
  command = plan

  variables {
    ecs_services = { web = { cluster_name = "acme-dev", service_name = "acme-dev-web" } }
    lambda_functions = {
      worker = { function_name = "acme-dev-worker" }
    }
  }

  assert {
    condition = (
      [for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets : w.x] == [0, 12, 0, 12] &&
      [for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets : w.y] == [0, 0, 6, 6]
    )
    error_message = "Los widgets deben colocarse en dos columnas de 12 de ancho."
  }
}

run "alarm_status_widget_goes_on_top_and_pushes_the_grid_down" {
  command = plan

  variables {
    alarm_arns   = { b = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:b", a = "arn:aws:cloudwatch:us-east-1:123456789012:alarm:a" }
    ecs_services = { web = { cluster_name = "acme-dev", service_name = "acme-dev-web" } }
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].type == "alarm" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].width == 24 &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.alarms == ["arn:aws:cloudwatch:us-east-1:123456789012:alarm:a", "arn:aws:cloudwatch:us-east-1:123456789012:alarm:b"] &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[1].y == 3
    )
    error_message = "El estado de las alarmas ocupa la primera fila, con los ARN ordenados, y desplaza la cuadrícula."
  }
}

run "metric_widgets_carry_region_period_and_title" {
  command = plan

  variables {
    period_seconds = 60
    ecs_services   = { web = { cluster_name = "acme-dev", service_name = "acme-dev-web" } }
  }

  assert {
    condition = alltrue([
      for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets :
      w.properties.region == "us-east-1" && w.properties.period == 60 && length(w.properties.title) > 0 && length(w.properties.metrics) >= 1
    ])
    error_message = "Cada widget debe indicar región, resolución, título y métricas."
  }
}

run "ecs_widget_uses_service_dimensions" {
  command = plan

  variables {
    ecs_services = { web = { cluster_name = "acme-dev", service_name = "acme-dev-web" } }
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][0] == "AWS/ECS" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][1] == "CPUUtilization" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][3] == "acme-dev" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][5] == "acme-dev-web"
    )
    error_message = "Las filas de métricas deben seguir el formato [namespace, métrica, dimensión, valor, ...]."
  }
}

run "elasticache_adds_a_row_per_node" {
  command = plan

  variables {
    elasticache = { sessions = { replication_group_id = "acme-dev-valkey", node_count = 3 } }
  }

  assert {
    condition = (
      length(jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets) == 2 &&
      length(jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics) == 6 &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[2][3] == "acme-dev-valkey-003" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[5][1] == "DatabaseMemoryUsagePercentage"
    )
    error_message = "Cada nodo (<id>-001, -002...) debe tener su fila de CPU y de memoria."
  }
}

run "cloudfront_and_global_waf_widgets_point_to_us_east_1" {
  command = plan

  variables {
    cloudfront_distributions = { site = { distribution_id = "E1ABCDEFGHIJKL" } }
    waf_web_acls             = { edge = { web_acl_name = "acme-dev-edge" } }
  }

  assert {
    condition     = alltrue([for w in jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets : w.properties.region == "us-east-1"])
    error_message = "Las métricas de CloudFront y de WAF global solo existen en us-east-1."
  }
}

run "regional_waf_uses_its_own_region" {
  command = plan

  variables {
    waf_web_acls = { regional = { web_acl_name = "acme-dev-web", region_dimension = "eu-west-1" } }
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.region == "eu-west-1" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][7] == "eu-west-1"
    )
    error_message = "Un WAF regional debe consultarse en su región."
  }
}

run "application_signals_adds_latency_fault_and_availability" {
  command = plan

  variables {
    application_signals = { service_name = "acme-dev-web", environment_name = "ecs:acme-dev" }
  }

  assert {
    condition     = length(jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets) == 3
    error_message = "Application Signals debe añadir tres widgets: latencia, fallos/errores y disponibilidad."
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][0] == "ApplicationSignals" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][3] == "acme-dev-web" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[0].properties.metrics[0][5] == "ecs:acme-dev"
    )
    error_message = "Las métricas de Application Signals se filtran por Service y Environment."
  }

  assert {
    condition = (
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[2].properties.metrics[0][0].expression == "100 * (1 - fault / total)" &&
      jsondecode(aws_cloudwatch_dashboard.this.dashboard_body).widgets[2].properties.metrics[2][6].stat == "SampleCount"
    )
    error_message = "La disponibilidad es 1 - fallos / peticiones, con las peticiones como nº de muestras de Latency."
  }
}

run "rejects_period_not_multiple_of_60" {
  command = plan

  variables {
    period_seconds = 90
  }

  expect_failures = [var.period_seconds]
}

run "rejects_invalid_dashboard_name" {
  command = plan

  variables {
    name = "acme prod!"
  }

  expect_failures = [var.name]
}

run "rejects_node_count_above_6" {
  command = plan

  variables {
    elasticache = { sessions = { replication_group_id = "acme-dev-valkey", node_count = 7 } }
  }

  expect_failures = [var.elasticache]
}
