#!/usr/bin/env bash
# Configura el repositorio del cliente en GitHub para la CI de infraestructura (plan, fase 11; ADR 0018).
# Se ejecuta una vez (y al añadir entornos o tenants silo) con `gh` autenticado como administrador del repositorio.
#
#   scripts/github-setup.sh --repo <owner/repo> --reviewers <team:slug|user:login>[,...] [--branch main]
#                           [--catalog-repository <owner/repo>] [--unprotected-envs "dev staging"]
#                           [--required-approvals 1] [--allow-self-review] [--dry-run]
#
# - Un GitHub Environment por cada github_environment de .github/live-roots.json, desplegable solo desde ramas
#   protegidas. Todos salvo --unprotected-envs (por defecto dev y staging) exigen la aprobación de --reviewers, sin
#   autoaprobación salvo --allow-self-review (equipos de una persona): son los únicos desde los que el rol
#   gha-apply-<env> se puede asumir (trust en environment:<nombre>).
# - Protección de la rama: PR con --required-approvals aprobaciones (1; con 0 tampoco se exige CODEOWNERS) y revisión
#   de CODEOWNERS, check obligatorio "plan-result", conversaciones resueltas, sin force-push ni borrado, también para
#   administradores.
# - Permite que GitHub Actions cree PR (catalog-update.yml), con el token por defecto de solo lectura.
# - Etiquetas allow-destroy (desactiva la política de destrucción de conftest) y drift.
# - Variable CATALOG_REPOSITORY para catalog-update.yml (el secreto CATALOG_READ_TOKEN se carga a mano).
set -euo pipefail

repo="" reviewers="" branch="main" catalog_repository="" dry_run=0
unprotected="dev staging" approvals=1 self_review=0
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?}"; shift 2 ;;
    --reviewers) reviewers="${2:?}"; shift 2 ;;
    --branch) branch="${2:?}"; shift 2 ;;
    --catalog-repository) catalog_repository="${2:?}"; shift 2 ;;
    --unprotected-envs) unprotected="${2?}"; shift 2 ;;
    --required-approvals) approvals="${2:?}"; shift 2 ;;
    --allow-self-review) self_review=1; shift ;;
    --dry-run) dry_run=1; shift ;;
    *) echo "github-setup: argumento desconocido: $1" >&2; exit 2 ;;
  esac
done
[ -n "$repo" ] && [ -n "$reviewers" ] || { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2; }
[[ "$approvals" =~ ^[0-6]$ ]] || { echo "github-setup: --required-approvals debe ser 0-6" >&2; exit 2; }
for bin in gh jq; do command -v "$bin" >/dev/null || { echo "github-setup: falta $bin" >&2; exit 1; }; done
owner="${repo%%/*}"

api() { # método ruta [json]
  if [ "$dry_run" -eq 1 ]; then echo "gh api -X $1 $2 ${3:-}"; return; fi
  if [ -n "${3:-}" ]; then gh api -X "$1" "$2" --input - <<< "$3" > /dev/null; else gh api -X "$1" "$2" > /dev/null; fi
}

# Revisores -> [{type, id}]
reviewer_json="[]"
IFS=',' read -r -a items <<< "$reviewers"
for item in "${items[@]}"; do
  kind="${item%%:*}" name="${item#*:}"
  case "$kind" in
    team) type="Team"; id=0; [ "$dry_run" -eq 1 ] || id="$(gh api "orgs/$owner/teams/$name" --jq .id)" ;;
    user) type="User"; id=0; [ "$dry_run" -eq 1 ] || id="$(gh api "users/$name" --jq .id)" ;;
    *) echo "github-setup: revisor no válido: $item (team:<slug> o user:<login>)" >&2; exit 2 ;;
  esac
  reviewer_json="$(jq -c --arg t "$type" --argjson id "$id" '. + [{type: $t, id: $id}]' <<< "$reviewer_json")"
done

for env in $(jq -r '[.[].github_environment] | unique | .[]' .github/live-roots.json); do
  if [[ " $unprotected " == *" $env "* ]]; then
    body='{"deployment_branch_policy": {"protected_branches": true, "custom_branch_policies": false}}'
  else
    body="$(jq -c -n --argjson r "$reviewer_json" --argjson self "$self_review" '{prevent_self_review: ($self == 0),
      reviewers: $r, deployment_branch_policy: {protected_branches: true, custom_branch_policies: false}}')"
  fi
  echo "github-setup: environment $env"
  api PUT "repos/$repo/environments/$env" "$body"
done

echo "github-setup: protección de $branch"
api PUT "repos/$repo/branches/$branch/protection" "$(jq -c -n --argjson n "$approvals" '{
  required_status_checks: {strict: true, contexts: ["plan-result"]},
  enforce_admins: true,
  required_pull_request_reviews: {required_approving_review_count: $n, require_code_owner_reviews: ($n > 0), dismiss_stale_reviews: true},
  restrictions: null,
  required_conversation_resolution: true,
  allow_force_pushes: false,
  allow_deletions: false
}')"

echo "github-setup: permisos de GitHub Actions"
api PUT "repos/$repo/actions/permissions/workflow" '{"default_workflow_permissions": "read", "can_approve_pull_request_reviews": true}'

if [ "$dry_run" -eq 0 ]; then
  gh label create allow-destroy --repo "$repo" --color B60205 --force \
    --description "Permite destruir o reemplazar recursos con estado (revisar el plan)"
  gh label create drift --repo "$repo" --color FBCA04 --force --description "La infraestructura real difiere del código"
  if [ -n "$catalog_repository" ]; then gh variable set CATALOG_REPOSITORY --repo "$repo" --body "$catalog_repository"; fi
fi
echo "github-setup: listo. Carga a mano el secreto CATALOG_READ_TOKEN (y opcionalmente CATALOG_UPDATE_TOKEN e INFRACOST_API_KEY)."
