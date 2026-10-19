# allowed_account_ids impide aplicar en una cuenta equivocada; las etiquetas obligatorias van en default_tags
# (plan 3.3), no dentro de los módulos. assume_role solo si la identidad de CI/consola no es ya la de la cuenta.
provider "aws" {
  region              = var.region
  allowed_account_ids = [var.account_id]

  dynamic "assume_role" {
    for_each = var.assume_role_arn == null ? [] : [var.assume_role_arn]

    content {
      role_arn     = assume_role.value
      session_name = "opentofu-${var.environment}"
    }
  }

  default_tags {
    tags = local.tags
  }
}
