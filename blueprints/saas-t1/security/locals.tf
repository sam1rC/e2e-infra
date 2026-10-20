locals {
  security_account_id = module.accounts["security"].account_id

  # OU de cada destino de guardrails: prod se aplica también a las cuentas compartidas y a los silos.
  guardrail_targets = {
    nonprod = { environment = "dev", ou_ids = [aws_organizations_organizational_unit.nonprod.id] }
    prod = {
      environment = "prod"
      ou_ids = [
        aws_organizations_organizational_unit.prod.id,
        aws_organizations_organizational_unit.silo.id,
        aws_organizations_organizational_unit.security.id,
        aws_organizations_organizational_unit.infrastructure.id,
      ]
    }
  }

  ou_ids = {
    security       = aws_organizations_organizational_unit.security.id
    infrastructure = aws_organizations_organizational_unit.infrastructure.id
    nonprod        = aws_organizations_organizational_unit.nonprod.id
    prod           = aws_organizations_organizational_unit.prod.id
    silo           = aws_organizations_organizational_unit.silo.id
  }

  # Servicios delegados en la cuenta security (acceso de confianza ya habilitado en la organización).
  delegated_service_principals = var.delegated_admins ? toset(["config.amazonaws.com", "access-analyzer.amazonaws.com"]) : toset([])
}
