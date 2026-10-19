# try(): con enable_flow_logs = false, flow_logs puede ser null y los linters evalúan igualmente estos atributos.
resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id                   = aws_vpc.this.id
  log_destination_type     = "s3"
  log_destination          = try(var.flow_logs.s3_bucket_arn, null)
  traffic_type             = try(var.flow_logs.traffic_type, "ALL")
  max_aggregation_interval = try(var.flow_logs.max_aggregation_interval, 600)
  log_format               = local.flow_log_format

  tags = merge(var.tags, { Name = local.name })
}
