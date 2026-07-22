#!/bin/bash
set -euo pipefail

###############################################################################
# validate.sh
#
# Static validation for the repo, invoked via `make validate`:
#   1. `kustomize build` on every kustomization.yaml in the repo
#   2. `kubeconform` schema validation against the target Kubernetes version,
#      using a CRD catalog that covers Flux, Crossplane, External Secrets
#      Operator, and Sealed Secrets custom resources (if kubeconform is
#      installed -- skipped with a warning otherwise, since it's not
#      required for local kustomize-only checks)
#
# Usage:
#   ./bin/validate.sh
#
# Requirements: kustomize (required), kubeconform (optional but recommended)
###############################################################################

K8S_VERSION="1.35.0"
CRD_CATALOG="https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json"

# Kustomization directories that are intentionally empty scaffolds in this
# repo's committed state -- populated later by bin/add-workload-cluster.sh
# and bin/add-cluster-app.sh. `kustomize build` errors on an empty
# `resources:` list, which is expected here, not a bug.
EMPTY_SCAFFOLDS=(
  "repos/gitops-system/clusters-config"
  "repos/gitops-workloads/template"
)

log() { echo "[validate] $*"; }
err() { echo "[validate] ERROR: $*" >&2; }

is_empty_scaffold() {
    local dir="$1"
    for scaffold in "${EMPTY_SCAFFOLDS[@]}"; do
        [[ "$dir" == "$scaffold" ]] && return 0
    done
    return 1
}

if ! command -v kustomize &>/dev/null; then
    err "kustomize is required but not found in PATH"
    exit 1
fi

fail=0

log "Running kustomize build on every kustomization.yaml ..."
while IFS= read -r dir; do
    if is_empty_scaffold "$dir"; then
        log "  SKIP (empty scaffold, populated at runtime): $dir"
        continue
    fi
    if kustomize build "$dir" >/tmp/validate-kb-output.yaml 2>/tmp/validate-kb-err.log; then
        log "  OK: $dir"
        if command -v kubeconform &>/dev/null; then
            if ! kubeconform \
                -kubernetes-version "$K8S_VERSION" \
                -schema-location default \
                -schema-location "$CRD_CATALOG" \
                -ignore-missing-schemas \
                -summary \
                /tmp/validate-kb-output.yaml >/tmp/validate-kc-output.log 2>&1; then
                err "  kubeconform FAILED: $dir"
                cat /tmp/validate-kc-output.log
                fail=1
            fi
        fi
    else
        err "  FAILED: $dir"
        cat /tmp/validate-kb-err.log
        fail=1
    fi
done < <(find repos -name kustomization.yaml -exec dirname {} \; | sort)

if ! command -v kubeconform &>/dev/null; then
    log "kubeconform not found -- skipped schema validation (install it to also check manifests against the Kubernetes/Flux/Crossplane/ESO/Sealed-Secrets CRD schemas)"
fi

rm -f /tmp/validate-kb-output.yaml /tmp/validate-kb-err.log /tmp/validate-kc-output.log

if [[ $fail -ne 0 ]]; then
    err "Validation failed"
    exit 1
fi

log "All kustomizations valid"
