# Runbook — Acceso humano con IAM Identity Center

La línea base (`account-baseline`) **no crea usuarios IAM**. El acceso humano a las cuentas se hace con IAM Identity Center y credenciales temporales.

## Si la organización ya tiene Identity Center
1. Crea (o reutiliza) los grupos `platform-readonly`, `platform-operators` y `platform-admins`.
2. Asigna permission sets a cada cuenta:

   | Permission set | Política base | Sesión | MFA |
   |---|---|---|---|
   | `ReadOnly` | `ReadOnlyAccess` | 8 h | obligatoria |
   | `Operator` | `PowerUserAccess` + lectura de IAM | 4 h | obligatoria |
   | `Admin` | `AdministratorAccess` | 1 h | obligatoria |

3. Exige MFA en la configuración de autenticación de Identity Center (no por usuario).

## Si no lo tiene
1. En la cuenta de **management**, habilita AWS Organizations (todas las funciones) y después IAM Identity Center, en la región de origen de la organización (no se puede cambiar después).
2. Elige la fuente de identidades: el directorio de Identity Center o el IdP del cliente (SAML/SCIM).
3. Sigue los pasos de la sección anterior.

## Acceso de emergencia (*break-glass*)
- Un rol `break-glass-*` por cuenta, asumible solo desde el grupo `platform-admins` con MFA, listado en `admin_role_arns` y `bootstrap_role_arns` de `org-guardrails`.
- Cada uso se revisa: alerta en CloudTrail sobre `AssumeRole` de ese rol.
- No se crean access keys de larga duración. El usuario root de cada cuenta tiene MFA hardware y sus credenciales guardadas en un gestor corporativo; las SCP de `org-guardrails` bloquean su uso en cuentas miembro.

## Verificación
- `aws iam list-users` en cada cuenta no devuelve usuarios (salvo excepción documentada).
- Un usuario sin MFA no puede obtener sesión.
