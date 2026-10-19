# Raíz mínima para ejecutar tests/integration.tftest.hcl desde el directorio del blueprint
# (`tofu test` necesita una configuración para instalar los módulos de los run). No declara recursos:
# el blueprint son sus capas y la composición de prueba está en examples/complete.
terraform {
  required_version = ">= 1.11.0"
}
