#!/usr/bin/env bash
# Genera el .terraform.lock.hcl de cada raíz de live/ con hashes para varias plataformas (plan 0.6 y 3.2).
#
#   scripts/lock-providers.sh [dir ...]        (por defecto: live)
#
# Las raíces son los directorios con un versions.tf de composición (required_version "~> ..."). Las versiones
# seleccionadas son deterministas: AWS_PROVIDER_VERSION y RANDOM_PROVIDER_VERSION (las probadas en la sandbox,
# ADR 0001) se siembran en el lock antes de `tofu providers lock`, que así solo calcula los hashes. Se descarga
# cada provider una vez por plataforma y el resultado se reparte entre las raíces según los providers que usan.
# Plataformas: LOCK_PLATFORMS (por defecto linux_amd64 linux_arm64 darwin_arm64). LOCK_CACHE_DIR (opcional) guarda
# el lock calculado por combinación de versiones, restricciones y plataformas para no volver a descargar.
set -euo pipefail

AWS_PROVIDER_VERSION="${AWS_PROVIDER_VERSION:-6.68.0}"
RANDOM_PROVIDER_VERSION="${RANDOM_PROVIDER_VERSION:-3.9.1}"
LOCK_PLATFORMS="${LOCK_PLATFORMS:-linux_amd64 linux_arm64 darwin_arm64}"
REGISTRY="registry.opentofu.org/hashicorp"

die() { echo "lock-providers: $*" >&2; exit 1; }
command -v tofu >/dev/null || die "falta tofu en el PATH"
[ $# -gt 0 ] || set -- live

roots=()
while IFS= read -r f; do
  if grep -q 'required_version *= *"~>' "$f"; then roots+=("$(dirname "$f")"); fi
done < <(find "$@" -name versions.tf -not -path '*/.terraform/*' | sort)
[ ${#roots[@]} -gt 0 ] || die "no hay raíces de composición en: $*"

# Restricción de versión de un provider en un versions.tf (la misma plantilla en todas las raíces).
constraint() { sed -n "/^ *$1 = {/,/}/s/^ *version *= *\"\\(.*\\)\"/\\1/p" "$2" | head -1; }

# Agrupa las raíces por restricciones (normalmente una sola combinación) y calcula un lock por grupo. Las raíces
# sin random se unen al grupo con la misma restricción de aws: el bloque de random se filtra al repartir.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
groups=""
new_group() { # $1 = clave, $2 = restricción de aws, $3 = restricción de random
  mkdir -p "$work/$1"
  groups="$groups $1"
  cat > "$work/$1/versions.tf" <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "$2"
    }
    random = {
      source  = "hashicorp/random"
      version = "$3"
    }
  }
}
EOF
  # Versiones sembradas: providers lock respeta la selección del lock existente y solo añade hashes.
  cat > "$work/$1/.terraform.lock.hcl" <<EOF
provider "$REGISTRY/aws" {
  version = "$AWS_PROVIDER_VERSION"
}

provider "$REGISTRY/random" {
  version = "$RANDOM_PROVIDER_VERSION"
}
EOF
}
pending=()
for r in "${roots[@]}"; do
  aws_c="$(constraint aws "$r/versions.tf")"
  random_c="$(constraint random "$r/versions.tf")"
  [ -n "$aws_c" ] || die "$r/versions.tf no declara hashicorp/aws"
  if [ -z "$random_c" ]; then pending+=("$r"); continue; fi
  key="$(printf '%s|%s' "$aws_c" "$random_c" | shasum | cut -c1-12)"
  [ -d "$work/$key" ] || { new_group "$key" "$aws_c" "$random_c"; printf '%s\n' "$aws_c" > "$work/$key/aws"; }
  printf '%s\n' "$r" >> "$work/$key/roots"
done
for r in ${pending[@]+"${pending[@]}"}; do
  aws_c="$(constraint aws "$r/versions.tf")"
  key=""
  for g in $groups; do if [ "$(cat "$work/$g/aws")" = "$aws_c" ]; then key="$g"; break; fi; done
  if [ -z "$key" ]; then
    key="$(printf '%s|' "$aws_c" | shasum | cut -c1-12)"
    [ -d "$work/$key" ] || { new_group "$key" "$aws_c" ">= 3.6"; printf '%s\n' "$aws_c" > "$work/$key/aws"; }
  fi
  printf '%s\n' "$r" >> "$work/$key/roots"
done

platform_flags=()
for p in $LOCK_PLATFORMS; do platform_flags+=("-platform=$p"); done

for key in $groups; do
  echo "lock-providers: hashes para $LOCK_PLATFORMS (aws $AWS_PROVIDER_VERSION, random $RANDOM_PROVIDER_VERSION)"
  cache_file=""
  if [ -n "${LOCK_CACHE_DIR:-}" ]; then
    cache_id="$(cat "$work/$key/versions.tf" "$work/$key/.terraform.lock.hcl" | printf '%s|%s' "$(cat)" "$LOCK_PLATFORMS" | shasum | cut -c1-16)"
    cache_file="$LOCK_CACHE_DIR/$cache_id.terraform.lock.hcl"
  fi
  if [ -n "$cache_file" ] && [ -f "$cache_file" ]; then
    cp "$cache_file" "$work/$key/.terraform.lock.hcl"
  elif ! tofu -chdir="$work/$key" providers lock -no-color "${platform_flags[@]}" > "$work/$key/lock.log" 2>&1; then
    cat "$work/$key/lock.log" >&2
    die "tofu providers lock falló"
  elif [ -n "$cache_file" ]; then
    mkdir -p "$LOCK_CACHE_DIR" && cp "$work/$key/.terraform.lock.hcl" "$cache_file"
  fi
  grep -q "version *= *\"$AWS_PROVIDER_VERSION\"" "$work/$key/.terraform.lock.hcl" \
    || die "la versión $AWS_PROVIDER_VERSION de aws no cumple las restricciones de versions.tf"

  while IFS= read -r r; do
    # Copia la cabecera y solo los bloques de los providers que declara la raíz.
    wanted="aws"
    if grep -q 'hashicorp/random' "$r/versions.tf"; then wanted="aws random"; fi
    awk -v wanted=" $wanted " -v reg="$REGISTRY/" '
      /^provider "/ { name = $2; gsub(/"/, "", name); sub(reg, "", name); keep = index(wanted, " " name " ") > 0; inblock = 1 }
      inblock { if (keep) out[n++] = $0; if ($0 == "}") inblock = 0; next }
      { out[n++] = $0 }
      END {
        # Sin líneas en blanco repetidas ni al final: el mismo formato que escribe tofu.
        while (n > 0 && out[n - 1] == "") n--
        for (i = 0; i < n; i++) if (!(out[i] == "" && i > 0 && out[i - 1] == "")) print out[i]
      }
    ' "$work/$key/.terraform.lock.hcl" > "$r/.terraform.lock.hcl"
  done < "$work/$key/roots"
done
echo "lock-providers: ${#roots[@]} lock files actualizados"
