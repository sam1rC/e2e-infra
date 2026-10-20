data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# Políticas gestionadas de CloudFront, resueltas por nombre (sin IDs fijos en el código).
data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# Para el origen de API: el endpoint de API Gateway tiene certificado de AWS para su propio nombre,
# así que aquí NO se reenvía el Host (a diferencia del ALB, ADR 0007).
data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}
