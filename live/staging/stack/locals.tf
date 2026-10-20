locals {
  # Etiquetas obligatorias (plan 3.3). La versión del catálogo no se etiqueta (ADR 0005): vive en CATALOG_VERSION
  # y en el parámetro SSM /<project>/<env>/catalog_version.
  tags = merge(var.extra_tags, {
    Project            = var.project
    Environment        = var.environment
    Owner              = var.owner
    ManagedBy          = "opentofu"
    Blueprint          = var.blueprint
    CostCenter         = var.cost_center
    DataClassification = var.data_classification
  }, var.tenant == null ? null : { Tenant = var.tenant })
}
