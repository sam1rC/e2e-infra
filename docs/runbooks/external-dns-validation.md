# Runbook — Validar un certificado ACM con DNS fuera de Route 53

Aplica a `edge/acm-certificate` cuando el cliente no tiene la zona en Route 53 (`zone_id = null`). Hay que repetirlo por cada instancia del módulo (certificado de CloudFront en us-east-1 y certificado regional del ALB).

## Pasos

1. **Primer apply** con `wait_for_validation = false` (valor por defecto). El módulo crea el certificado en estado *Pendiente de validación* y no bloquea.
2. **Lee los registros:**
   ```bash
   tofu output -json validation_records
   ```
   Cada dominio tiene `name`, `type` (CNAME) y `value`.
3. **Crea los CNAME en el DNS del cliente.** Respeta el nombre y el valor exactos (incluido el punto final si el proveedor lo exige). `example.com` y `*.example.com` comparten un único registro.
4. **Comprueba la propagación:**
   ```bash
   dig +short CNAME <name>
   ```
5. **Segundo apply** con `wait_for_validation = true`. El módulo espera hasta que ACM emita el certificado (puede tardar de minutos a una hora).
6. Solo entonces aplica los módulos que consumen el certificado (`cloudfront-vpc-origin`, `cloudfront-static-site`, el listener del ALB).

## Renovación
ACM renueva sin intervención mientras los CNAME de validación sigan existiendo. **No los borres** tras la emisión; si el cliente los elimina, la renovación fallará a los ~60 días y AWS Health avisará del fallo de renovación.

## Problemas habituales
- *Pending validation* tras más de una hora: el CNAME no coincide, tiene el dominio duplicado (`_x.app.cliente.com.cliente.com`) o el proveedor DNS añadió su propio sufijo.
- El segundo apply se queda esperando: revisa que creaste los registros de **ambos** certificados si hay uno en us-east-1 y otro regional.
