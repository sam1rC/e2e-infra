#!/usr/bin/env bash
# Raíces de live/ afectadas por los cambios entre dos commits (plan.yml y apply.yml).
#
#   scripts/changed-roots.sh <base> <head> [--all]
#
# Escribe en stdout, en formato $GITHUB_OUTPUT:
#   roots=<JSON con las raíces, en orden de despliegue>
#   matrix=<JSON con sus entradas de .github/live-roots.json>
# Un cambio en el catálogo vendorizado (modules/, blueprints/, policies/, CATALOG_VERSION), en el inventario de
# raíces o en el workflow reutilizable afecta a todas. Sin base (rama nueva o primer push), también.
set -euo pipefail

ROOTS_FILE=".github/live-roots.json"
base="${1:-}" head="${2:-HEAD}" all=0
[ "${3:-}" = "--all" ] && all=1
[ -f "$ROOTS_FILE" ] || { echo "changed-roots: falta $ROOTS_FILE" >&2; exit 1; }

if [ -z "$base" ] || [ "$base" = "0000000000000000000000000000000000000000" ] || ! git cat-file -e "$base^{commit}" 2>/dev/null; then
  all=1
fi

if [ "$all" -eq 1 ]; then
  selected="$(jq -c '[.[].root]' "$ROOTS_FILE")"
else
  files="$(git diff --name-only "$base" "$head")"
  if printf '%s\n' "$files" | grep -Eq '^(modules/|blueprints/|policies/|CATALOG_VERSION$|\.github/live-roots\.json$|\.github/workflows/tofu-layer\.yml$)'; then
    selected="$(jq -c '[.[].root]' "$ROOTS_FILE")"
  else
    selected="$(printf '%s\n' "$files" | jq -R -s -c --slurpfile r "$ROOTS_FILE" '
      split("\n") | map(select(length > 0)) as $f
      | [$r[0][].root | select(. as $root | any($f[]; startswith("live/" + $root + "/")))]')"
  fi
fi

echo "roots=$selected"
echo "matrix=$(jq -c --argjson s "$selected" '[.[] | select(.root as $r | $s | index($r))]' "$ROOTS_FILE")"
