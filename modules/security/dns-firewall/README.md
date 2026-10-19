# security/dns-firewall

**Route 53 Resolver DNS Firewall** asociado a la VPC con las listas de dominios gestionadas por AWS (malware, botnet/C&C y amenazas agregadas) en `BLOCK`, y **logs de consultas DNS a S3**. Es el control de egress de menor coste: un AWS Network Firewall solo se justifica con requisitos de compliance explícitos. Módulo opcional, pensado para T1.

## Uso

```hcl
module "dns_firewall" {
  source = "../../modules/security/dns-firewall"

  project     = "acme"
  environment = "prod"
  vpc_id      = module.vpc.vpc_id

  # IDs de las listas gestionadas en esta región (aws route53resolver list-firewall-domain-lists)
  managed_domain_lists = {
    malware = { domain_list_id = "rslvr-fdl-...", priority = 10 } # AWSManagedDomainsMalwareDomainList
    botnet  = { domain_list_id = "rslvr-fdl-...", priority = 20 } # AWSManagedDomainsBotnetCommandandControl
    threats = { domain_list_id = "rslvr-fdl-...", priority = 30 } # AWSManagedDomainsAggregateThreatList
    # Recomendada en T1 (v2.1): AWSManagedDomainsAmazonGuardDutyThreatList
    guardduty = { domain_list_id = "rslvr-fdl-...", priority = 40 }
  }

  query_log_destination_arn = "${module.logs_bucket.bucket_arn}/dns"
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
| [aws_route53_resolver_firewall_config.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_config) | resource |
| [aws_route53_resolver_firewall_rule.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule) | resource |
| [aws_route53_resolver_firewall_rule_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule_group) | resource |
| [aws_route53_resolver_firewall_rule_group_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_firewall_rule_group_association) | resource |
| [aws_route53_resolver_query_log_config.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_query_log_config) | resource |
| [aws_route53_resolver_query_log_config_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_resolver_query_log_config_association) | resource |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_association_priority"></a> [association\_priority](#input\_association\_priority) | Prioridad del grupo de reglas en la VPC (101-9900) frente a otros grupos asociados (p. ej. los de Firewall Manager). | `number` | `101` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Entorno de despliegue. | `string` | n/a | yes |
| <a name="input_fail_open"></a> [fail\_open](#input\_fail\_open) | Si el firewall no puede evaluar una consulta: true la deja pasar (prioriza disponibilidad) y false la rechaza (prioriza seguridad, el valor por defecto de AWS). | `bool` | `false` | no |
| <a name="input_managed_domain_lists"></a> [managed\_domain\_lists](#input\_managed\_domain\_lists) | Listas de dominios gestionadas por AWS, por clave estable (p. ej. malware, botnet, threats): domain\_list\_id (rslvr-fdl-..., distinto en cada región y obtenido con `aws route53resolver list-firewall-domain-lists --query "FirewallDomainLists[?ManagedOwnerName!=null]"`), priority (1-10000, única: se evalúan de menor a mayor), action (BLOCK por defecto, ALERT para solo registrar o ALLOW) y block\_response (NXDOMAIN o NODATA). El plan recomienda AWSManagedDomainsMalwareDomainList, AWSManagedDomainsBotnetCommandandControl y AWSManagedDomainsAggregateThreatList en BLOCK, y en T1 también AWSManagedDomainsAmazonGuardDutyThreatList. | <pre>map(object({<br/>    domain_list_id = string<br/>    priority       = number<br/>    action         = optional(string, "BLOCK")<br/>    block_response = optional(string, "NXDOMAIN")<br/>  }))</pre> | n/a | yes |
| <a name="input_mutation_protection"></a> [mutation\_protection](#input\_mutation\_protection) | Impide desasociar el grupo de reglas de la VPC sin retirar antes la protección. null = activa en prod. | `bool` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | Nombre del proyecto; prefijo de los nombres de recursos. | `string` | n/a | yes |
| <a name="input_query_log_destination_arn"></a> [query\_log\_destination\_arn](#input\_query\_log\_destination\_arn) | ARN del bucket S3 (opcionalmente con prefijo: arn:aws:s3:::bucket/dns) donde se guardan los logs de consultas DNS. El bucket debe permitir la entrega de delivery.logs.amazonaws.com (s3:PutObject con bucket-owner-full-control y s3:GetBucketAcl, condicionados a aws:SourceAccount), igual que los flow logs; el bucket de logs de account-baseline no lo hace todavía. | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Etiquetas adicionales. | `map(string)` | `{}` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | VPC cuyo tráfico DNS se filtra (el del resolvedor de Route 53 de la VPC, no el de resolvedores propios). | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_query_log_config_id"></a> [query\_log\_config\_id](#output\_query\_log\_config\_id) | ID de la configuración de logs de consultas DNS. |
| <a name="output_rule_group_arn"></a> [rule\_group\_arn](#output\_rule\_group\_arn) | ARN del grupo de reglas del DNS Firewall. |
| <a name="output_rule_group_id"></a> [rule\_group\_id](#output\_rule\_group\_id) | ID del grupo de reglas del DNS Firewall. |
<!-- END_TF_DOCS -->

## Decisiones de seguridad

- **Dominios gestionados por AWS, no por el catálogo:** las reglas apuntan a las listas gestionadas, que AWS actualiza solas; el código no contiene dominios. El provider no tiene un data source por nombre para estas listas y sus IDs (`rslvr-fdl-...`) **son distintos en cada región**, así que se pasan por variable (`managed_domain_lists`); se obtienen con `aws route53resolver list-firewall-domain-lists` (las gestionadas son las que tienen `ManagedOwnerName`). El nombre exacto de las listas está en el comentario del ejemplo; además de las tres del plan, en T1 se recomienda `AWSManagedDomainsAmazonGuardDutyThreatList` (dominios de la inteligencia de amenazas de GuardDuty). IDs en us-east-1 comprobados el 2026-10-05: Malware `rslvr-fdl-2c46f2ecbfec4dcc`, Botnet `rslvr-fdl-aa970e9eb1ca4777`, AggregateThreat `rslvr-fdl-15f4860b1ad54ead`, GuardDuty `rslvr-fdl-984dae9d8bac4e2b`.
- **Acciones por lista:** `BLOCK` por defecto con respuesta `NXDOMAIN` (o `NODATA`); `ALERT` registra sin bloquear (útil para evaluar una lista nueva antes de bloquearla) y `ALLOW` exime. Las prioridades (1-10000) son explícitas y estables: añadir una lista no renumera las demás.
- **Fail closed por defecto:** `fail_open = false` (el valor por defecto de AWS) rechaza las consultas que el firewall no puede evaluar, priorizando seguridad sobre disponibilidad; ponlo a `true` solo si la resolución DNS es más crítica que el filtrado.
- **Protección contra desasociación** (`mutation_protection`): activa por defecto en prod, para que nadie quite el firewall de la VPC sin retirar antes la protección.
- **Alcance:** solo filtra el tráfico que usa el resolvedor de Route 53 de la VPC (`+2`); no cubre DNS sobre HTTPS a servidores externos ni resolvedores propios. Complementa a la salida cerrada por security groups y NACL, no la sustituye.
- **Logs de consultas a S3** (`query_log_destination_arn`, con prefijo opcional): el bucket debe permitir la entrega de `delivery.logs.amazonaws.com` (`s3:PutObject` sobre **`<prefijo>/AWSLogs/<cuenta>/*`** y `s3:GetBucketAcl`), igual que los flow logs (el bucket de logs de `account-baseline` aún no lo hace; ver CLAUDE.md). Con el prefijo `dns` la ruta es `dns/AWSLogs/<cuenta>/*`: si la política solo cubre `AWSLogs/...` la asociación queda en `FAILED` con `LogDestinationPermissionIssueException` (visto en la prueba de integración del 2026-10-06; el ejemplo `complete` ya usa el prefijo). Los logs pueden contener nombres de dominio internos: restringe su lectura.

### Cómo se verificó

- 19 tests unitarios con `mock_provider` (una regla por lista con prioridades y respuesta de bloqueo, `ALERT` sin respuesta de bloqueo, asociación a la VPC, protección contra desasociación por entorno, fail closed/open, logs de consultas con y sin prefijo y 8 validaciones que deben fallar). Los dos ejemplos validan y su grafo es acíclico.
- **Plan real offline** contra el provider 6.67.0 (credenciales falsas; el módulo no tiene data sources): 8 recursos, esquema aceptado; con IDs de lista de marcador.
- **Pendiente en sandbox:** con los IDs reales de las tres listas, resolver desde la VPC un dominio de prueba de la lista (AWS publica dominios de prueba para cada lista gestionada) devuelve `NXDOMAIN` y aparece en el log de S3 con la entrega de `delivery.logs.amazonaws.com`; comprobar el efecto de `mutation_protection` al destruir.

## Attribution

This module was created following best practices from [terraform-skill](https://github.com/antonbabenko/terraform-skill) by Anton Babenko.
Additional resources: [terraform-best-practices.com](https://terraform-best-practices.com) · [Compliance.tf](https://compliance.tf)
