output "policy_id" {
  description = "ID de la response headers policy (para response_headers_policy_id de los comportamientos)."
  value       = aws_cloudfront_response_headers_policy.this.id
}
