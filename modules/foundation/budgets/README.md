# budgets

Presupuesto mensual con alertas al 80/100/120 % del gasto real y al 100 % previsto, más detección de anomalías de costo por servicio (AWS Cost Anomaly Detection).

## Uso

```hcl
module "budgets" {
  source = "../../modules/foundation/budgets"

  project           = "acme"
  environment       = "prod"
  monthly_limit_usd = 5000
  alert_emails      = ["team@example.com"]
}
```

Más opciones en [`examples/complete`](examples/complete).

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 6.30, < 7.0 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.67.0 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_budgets_budget.monthly](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_ce_anomaly_monitor.services](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_monitor) | resource |
| [aws_ce_anomaly_subscription.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ce_anomaly_subscription) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_alert_emails"></a> [alert\_emails](#input\_alert\_emails) | Correos que reciben las alertas de presupuesto y de anomalías de costo. | `list(string)` | n/a | yes |
| <a name="input_alert_thresholds_percent"></a> [alert\_thresholds\_percent](#input\_alert\_thresholds\_percent) | Porcentajes del presupuesto (sobre el gasto real) que disparan una alerta. Además se alerta con el 100% previsto. | `list(number)` | <pre>[<br/>  80,<br/>  100,<br/>  120<br/>]</pre> | no |
| <a name="input_anomaly_threshold_usd"></a> [anomaly\_threshold\_usd](#input\_anomaly\_threshold\_usd) | Impacto absoluto mínimo, en USD, para notificar una anomalía de costo. | `number` | `100` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_existing_anomaly_monitor_arn"></a> [existing\_anomaly\_monitor\_arn](#input\_existing\_anomaly\_monitor\_arn) | ARN de un monitor de anomalías por servicio que ya exista en la cuenta. AWS crea automáticamente "Default-Services-Monitor" en las cuentas nuevas y solo admite un monitor DIMENSIONAL/SERVICE por cuenta: en ese caso pasa su ARN (aws ce get-anomaly-monitors) y el módulo solo crea la suscripción. null = el módulo crea el monitor. | `string` | `null` | no |
| <a name="input_monthly_limit_usd"></a> [monthly\_limit\_usd](#input\_monthly\_limit\_usd) | Presupuesto mensual de la cuenta, en USD. | `number` | n/a | yes |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_anomaly_monitor_arn"></a> [anomaly\_monitor\_arn](#output\_anomaly\_monitor\_arn) | ARN del monitor de anomalías de costo (el creado o el existente). |
| <a name="output_budget_name"></a> [budget\_name](#output\_budget\_name) | Nombre del presupuesto mensual. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- Sin credenciales ni secretos: solo correos de destino. Los correos son datos personales del cliente; no los subas a repositorios públicos.
- Las alertas llegan directamente por correo (sin tópico SNS propio). Tras el primer apply, comprueba en la consola que ambos servicios muestran los destinatarios y que los correos no caen en spam.
- Las alertas reales (80/100/120 %) detectan el sobrecoste ya ocurrido; la alerta prevista al 100 % da margen para actuar antes de que termine el mes.
- El monitor de anomalías es dimensional por servicio. **AWS solo admite un monitor `DIMENSIONAL`/`SERVICE` por cuenta y crea automáticamente `Default-Services-Monitor` en las cuentas nuevas** (comprobado en la cuenta sandbox el 2026-10-06: crear otro falla con `Limit exceeded on dimensional spend monitor creation`). En ese caso pasa su ARN en `existing_anomaly_monitor_arn` (`aws ce get-anomaly-monitors`) y el módulo solo crea la suscripción con los destinatarios y el umbral propios.
- Un presupuesto no frena el gasto: es una alerta, no un control. Para topes duros usa SCP o cuotas de servicio.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
