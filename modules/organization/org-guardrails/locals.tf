locals {
  name      = "${var.project}-${var.environment}"
  partition = data.aws_partition.current.partition

  bootstrap_arns = length(var.bootstrap_role_arns) > 0 ? var.bootstrap_role_arns : var.admin_role_arns

  protect_state = length(var.state_bucket_arns) > 0 || length(var.state_kms_key_arns) > 0

  # Límite de AWS para el contenido de una política de organización.
  policy_max_chars = 5120

  attachments = {
    for pair in setproduct(var.target_ids, ["security", "region"]) :
    "${pair[0]}/${pair[1]}" => { target_id = pair[0], policy = pair[1] }
  }
}
