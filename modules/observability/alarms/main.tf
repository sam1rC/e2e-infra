resource "aws_cloudwatch_metric_alarm" "simple" {
  for_each = local.simple_alarms

  alarm_name          = "${local.name}-${each.key}"
  alarm_description   = each.value.description
  namespace           = each.value.namespace
  metric_name         = each.value.metric_name
  dimensions          = each.value.dimensions
  statistic           = each.value.statistic == "" ? null : each.value.statistic
  extended_statistic  = each.value.extended_statistic == "" ? null : each.value.extended_statistic
  comparison_operator = each.value.comparison_operator
  threshold           = each.value.threshold
  period              = local.t.period_seconds
  evaluation_periods  = local.t.evaluation_periods
  datapoints_to_alarm = local.t.datapoints_to_alarm
  treat_missing_data  = each.value.treat_missing_data
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]

  tags = merge(var.tags, { Name = "${local.name}-${each.key}" })
}

# ThrottledRequests y SystemErrors solo existen por operación: se suman con metric math.
resource "aws_cloudwatch_metric_alarm" "dynamodb" {
  for_each = local.dynamodb_alarms

  alarm_name          = "${local.name}-${each.key}"
  alarm_description   = each.value.description
  comparison_operator = "GreaterThanThreshold"
  threshold           = each.value.threshold
  evaluation_periods  = local.t.evaluation_periods
  datapoints_to_alarm = local.t.datapoints_to_alarm
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]

  dynamic "metric_query" {
    for_each = each.value.operations

    content {
      id          = "m${metric_query.key}"
      return_data = false

      metric {
        namespace   = "AWS/DynamoDB"
        metric_name = each.value.metric_name
        dimensions  = { TableName = each.value.table_name, Operation = metric_query.value }
        period      = local.t.period_seconds
        stat        = "Sum"
      }
    }
  }

  metric_query {
    id          = "total"
    expression  = "SUM(METRICS())"
    label       = each.value.metric_name
    return_data = true
  }

  tags = merge(var.tags, { Name = "${local.name}-${each.key}" })
}

# BlockedRequests "anómalo": por encima de la banda que aprende CloudWatch de la serie histórica.
resource "aws_cloudwatch_metric_alarm" "waf_anomaly" {
  for_each = var.waf_web_acls

  alarm_name          = "${local.name}-waf-${each.key}-blocked-anomaly"
  alarm_description   = "WAF ${each.key}: peticiones bloqueadas por encima de lo habitual"
  comparison_operator = "GreaterThanUpperThreshold"
  threshold_metric_id = "band"
  evaluation_periods  = local.t.evaluation_periods
  datapoints_to_alarm = local.t.datapoints_to_alarm
  treat_missing_data  = "notBreaching"
  alarm_actions       = [local.topic_arn]
  ok_actions          = [local.topic_arn]

  metric_query {
    id          = "blocked"
    return_data = true

    metric {
      namespace   = "AWS/WAFV2"
      metric_name = "BlockedRequests"
      dimensions  = { WebACL = each.value.web_acl_name, Rule = "ALL", Region = each.value.region_dimension }
      period      = local.t.period_seconds
      stat        = "Sum"
    }
  }

  metric_query {
    id          = "band"
    expression  = "ANOMALY_DETECTION_BAND(blocked, ${local.t.waf_anomaly_band_width})"
    label       = "Banda esperada"
    return_data = true
  }

  tags = merge(var.tags, { Name = "${local.name}-waf-${each.key}-blocked-anomaly" })
}
