# Sin usuario "default": con el motor Valkey los grupos de usuarios no lo exigen y ElastiCache rechaza el
# modo no-password-required ("No-password-required is not allowed for a user with engine Valkey", sandbox
# 2026-10-14). Sin él en el grupo, ninguna conexión sin autenticar es posible.
# Con autenticación IAM, user_id y user_name deben coincidir. No hay contraseñas en ningún sitio.
resource "aws_elasticache_user" "app" {
  for_each = local.user_ids

  user_id       = each.value
  user_name     = each.value
  engine        = "valkey"
  access_string = var.iam_users[each.key].access_string

  authentication_mode {
    type = "iam"
  }

  tags = merge(var.tags, { Name = each.value })
}

resource "aws_elasticache_user_group" "this" {
  user_group_id = local.name
  engine        = "valkey"
  user_ids      = [for k in sort(keys(local.user_ids)) : aws_elasticache_user.app[k].user_id]

  tags = merge(var.tags, { Name = local.name })
}
