# Knowledge Base: EKS Multi-Cluster GitOps

**Analysis date:** 2026-04-27  
**Last updated:** 2026-04-28 (Phases 1–9 applied)  
**Repo origin:** aws-samples/multi-cluster-gitops (re-init 2024, component versions span 2022–2024)  
**Overall staleness:** LOW — Phases 1–9 complete. Three items remain as future projects (FP-1 through FP-3) requiring live cluster access or architectural rewrite.

---

## Table of Contents

1. [Stack Summary](#1-stack-summary)
2. [CLI Tools Required](#2-cli-tools-required)
3. [FluxCD](#3-fluxcd)
4. [Crossplane Core](#4-crossplane-core)
5. [Crossplane Providers](#5-crossplane-providers)
6. [External Secrets Operator](#6-external-secrets-operator)
7. [Sealed Secrets](#7-sealed-secrets)
8. [Karpenter](#8-karpenter)
9. [AWS Load Balancer Controller](#9-aws-load-balancer-controller)
10. [AWS EBS CSI Driver](#10-aws-ebs-csi-driver)
11. [Kubecost](#11-kubecost)
12. [EKS Cluster Versions](#12-eks-cluster-versions)
13. [Application: product-catalog-api](#13-application-product-catalog-api)
14. [Application: product-catalog-fe](#14-application-product-catalog-fe)
15. [Deprecated Kubernetes API Versions](#15-deprecated-kubernetes-api-versions)
16. [Deprecated Crossplane Constructs](#16-deprecated-crossplane-constructs)
17. [Upgrade Priority Matrix](#17-upgrade-priority-matrix)
18. [Artifact Pull Reference](#18-artifact-pull-reference)
19. [Future Projects](#19-future-projects)

---

## 1. Stack Summary

| Layer | Tool | Version | Status |
|---|---|---|---|
| GitOps engine | FluxCD | v2.1.2 | Open — FP-2 (requires live cluster bootstrap) |
| Infrastructure controller | Crossplane | v1.19.2 | ✅ Updated (Phase 9) |
| AWS provider (Crossplane) | crossplane-contrib/provider-aws | v0.47.1 | Open — FP-1 (archived, major rewrite required) |
| K8s provider (Crossplane) | crossplane-contrib/provider-kubernetes | v0.16.0 | ✅ Updated (Phase 9) |
| Secrets (Git) | Sealed Secrets | chart 2.18.5 | ✅ Updated (Phase 6) |
| Secrets (AWS SM) | External Secrets Operator | chart 0.10.7 | ✅ Updated (Phase 5) |
| Node autoscaler | Karpenter | chart 1.3.1 | ✅ Updated (Phase 8) |
| Load balancer | AWS Load Balancer Controller | chart 1.11.0 | ✅ Updated (Phase 7) |
| Storage | AWS EBS CSI Driver | chart 2.38.1 | ✅ Updated (Phase 7) |
| Cost visibility | Kubecost cost-analyzer | chart 2.6.0 | ✅ Updated (Phase 7) |
| Management cluster | EKS | template → 1.31 | ✅ Template updated (Phase 2); live upgrade is operational |
| Workload cluster template | EKS | 1.31 | ✅ Updated (Phase 2) |
| API backend | Python / Flask | 3.12-slim / 3.0.3 | ✅ Python upgraded (Phase 1) |
| Web frontend | Node.js | 22-slim | ✅ Upgraded from EOL 14 (Phase 1) |
| Bootstrap environment | AWS Cloud9 | amazonlinux-2-x86_64 | ✅ Updated in README (Phase 2/3) |

---

## 2. CLI Tools Required

Versions are pinned in `initial-setup/README.md`. All updated in Phase 3.

### kubectl
| | Value |
|---|---|
| **Current pinned version** | **1.31.0** ✅ |
| Install command | `https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl` |
| Skew policy | Must be within one minor version of EKS cluster (cluster 1.31 → kubectl 1.30–1.32) |
| Current stable | 1.32.x |
| Get current | https://dl.k8s.io/release/stable.txt |

### Flux CLI
| | Value |
|---|---|
| Pinned version | v2.1.2 (implied — bootstrap generates gotk-components.yaml at this version) |
| Install | `curl -s https://fluxcd.io/install.sh | sudo bash` (fetches latest) |
| Current stable | v2.5.x |
| Releases | https://github.com/fluxcd/flux2/releases |
| **Note** | Flux CLI version must match deployed FluxCD. Upgrading requires `flux bootstrap` to regenerate `gotk-components.yaml` — see FP-2. |

### kubeseal
| | Value |
|---|---|
| **Current pinned version** | **v0.36.6** ✅ |
| Download | `https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.36.6/kubeseal-0.36.6-linux-amd64.tar.gz` |
| Matches chart | 2.18.5 (controller v0.36.x) ✅ |
| **CRITICAL** | kubeseal CLI version must always match the Sealed Secrets controller chart version. |

### eksctl
| | Value |
|---|---|
| **Current pinned version** | **v0.208.0** ✅ |
| Install | `https://github.com/eksctl-io/eksctl/releases/download/v0.208.0/eksctl_Linux_amd64.tar.gz` |
| Current stable | v0.208.x |
| Releases | https://github.com/eksctl-io/eksctl/releases |
| **Note** | Weaveworks transferred the repo to `eksctl-io/eksctl`. Install URL updated accordingly. |

### yq
| | Value |
|---|---|
| **Current pinned version** | **v4.44.3** ✅ |
| Download | `https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64` |
| Current stable | v4.45.x |
| Releases | https://github.com/mikefarah/yq/releases |

### AWS CLI
| | Value |
|---|---|
| Pinned version | v2 (latest) |
| Install | `https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip` |
| **Action** | No pin — acceptable, but lock in CI/CD contexts |

### GitHub CLI (gh)
| | Value |
|---|---|
| Pinned version | stable (apt) |
| Source | https://cli.github.com |
| **Action** | No version pin — acceptable |

---

## 3. FluxCD

### Deployment
- **Installed via:** `flux bootstrap` against `gitops-system` repo
- **Generated manifest:** `repos/gitops-system/clusters/mgmt/flux-system/gotk-components.yaml`
- **Pinned version:** v2.1.2 (stamped in gotk-components.yaml header) — **not yet upgraded (FP-2)**
- **Current stable:** v2.5.x
- **Releases:** https://github.com/fluxcd/flux2/releases
- **Changelog:** https://fluxcd.io/flux/releases/

### Components installed
`source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller`

### API versions — RESOLVED ✅ (Phase 4)

All deprecated Flux API versions have been replaced across 51 manifests:

| Old API | New API | Status |
|---|---|---|
| `helm.toolkit.fluxcd.io/v2beta1` | `helm.toolkit.fluxcd.io/v2` | ✅ Replaced |
| `source.toolkit.fluxcd.io/v1beta2` | `source.toolkit.fluxcd.io/v1` | ✅ Replaced |
| `kustomize.toolkit.fluxcd.io/v1beta2` | `kustomize.toolkit.fluxcd.io/v1` | ✅ Replaced |

`gotk-components.yaml` was intentionally excluded — it is auto-generated by `flux bootstrap` and must never be manually edited.

### Upgrade path (FP-2)
```bash
# 1. Update Flux CLI to target version
curl -s https://fluxcd.io/install.sh | sudo bash   # or pin: FLUX_VERSION=v2.5.1

# 2. Re-bootstrap (regenerates gotk-components.yaml)
flux bootstrap github \
  --owner=<org> \
  --repository=gitops-system \
  --branch=main \
  --path=clusters/mgmt
```

---

## 4. Crossplane Core

### Deployment
- **Chart:** `crossplane` from `https://charts.crossplane.io/stable`
- **Chart version:** **1.19.2** ✅ (upgraded from 1.15.0 in Phase 9)
- **File:** `repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml`
- **Releases:** https://github.com/crossplane/crossplane/releases

### ControllerConfig → DeploymentRuntimeConfig — RESOLVED ✅ (Phase 9)

`ControllerConfig` (`pkg.crossplane.io/v1alpha1`) was removed in Crossplane 1.17. Both providers have been migrated to `DeploymentRuntimeConfig` (`pkg.crossplane.io/v1beta1`):

- `repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml` ✅
- `repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml` ✅
- `repos/gitops-system/clusters/template/crossplane.yaml` — patch target updated to `DeploymentRuntimeConfig/v1beta1`, annotation path updated to `spec.deploymentTemplate.spec.template.metadata.annotations` ✅

### k8s-provider-config-job: kubectl image — RESOLVED ✅ (Phase 9)

- **File:** `repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml`
- **Old image:** `bitnami/kubectl:1.22.11` (K8s 1.22 EOL 2022-10-28)
- **New image:** `bitnami/kubectl:1.31` ✅
- **Note:** This Job + CronJob grants `cluster-admin` to the Kubernetes provider SA. This is a known workaround pattern — review whether provider-kubernetes v0.16+ resolves this without a CronJob.

---

## 5. Crossplane Providers

### AWS Provider

| | Value |
|---|---|
| Package | `xpkg.upbound.io/crossplane-contrib/provider-aws:v0.47.1` |
| File | `repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml` |
| Registry | https://marketplace.upbound.io/providers/crossplane-contrib/provider-aws |
| Status | **ARCHIVED — FP-1** — monolithic community provider no longer maintained |

**Critical architectural issue (FP-1):** Upbound replaced the monolithic `crossplane-contrib/provider-aws` with a family of granular official providers. Every resource in the Crossplane composition changes API group.

| Old (archived) | New (official Upbound) |
|---|---|
| `crossplane-contrib/provider-aws` | `upbound/provider-family-aws` (root) |
| `ec2.aws.crossplane.io/v1beta1` | `ec2.aws.upbound.io/v1beta1` |
| `eks.aws.crossplane.io/v1beta1` | `eks.aws.upbound.io/v1beta1` |
| `iam.aws.crossplane.io/v1beta1` | `iam.aws.upbound.io/v1beta1` |

**Impact:** All ~50 managed resource definitions in `tools-config/crossplane-eks-composition/composition.yaml` must be rewritten. Treat as a separate project (FP-1).

**New provider packages (Upbound Marketplace):**
- Root: `xpkg.upbound.io/upbound/provider-family-aws`
- EC2: `xpkg.upbound.io/upbound/provider-aws-ec2`
- EKS: `xpkg.upbound.io/upbound/provider-aws-eks`
- IAM: `xpkg.upbound.io/upbound/provider-aws-iam`
- Marketplace: https://marketplace.upbound.io/providers/upbound/provider-family-aws

### Kubernetes Provider

| | Value |
|---|---|
| Package | `xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.16.0` ✅ |
| File | `repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml` |
| Upgraded from | v0.13.0 (Phase 9) |
| Releases | https://github.com/crossplane-contrib/provider-kubernetes/releases |
| Marketplace | https://marketplace.upbound.io/providers/crossplane-contrib/provider-kubernetes |
| API version in use | `kubernetes.crossplane.io/v1alpha1` (Object, ProviderConfig) |

---

## 6. External Secrets Operator

### Deployment

| | Value |
|---|---|
| Chart | `external-secrets` |
| Repo | `https://charts.external-secrets.io` |
| **Chart version** | **0.10.7** ✅ (upgraded from 0.4.4 in Phase 5) |
| File | `repos/gitops-system/tools/external-secrets/external-secrets-release.yaml` |
| Releases | https://github.com/external-secrets/external-secrets/releases |

### v1alpha1 API — RESOLVED ✅ (Phase 5)

Both `SecretStore` and `ExternalSecret` in `repos/gitops-system/tools-config/external-secrets/sealed-secrets-key.yaml` have been updated from `external-secrets.io/v1alpha1` to `external-secrets.io/v1beta1`.

---

## 7. Sealed Secrets

### Deployment

| | Value |
|---|---|
| Chart | `sealed-secrets` |
| Repo | `https://bitnami-labs.github.io/sealed-secrets` |
| **Chart version** | **2.18.5** ✅ (controller v0.36.x, upgraded from 2.7.1 in Phase 6) |
| File | `repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml` |
| Releases | https://github.com/bitnami-labs/sealed-secrets/releases |

### CLI version coupling — IN SYNC ✅

```
chart 2.18.5  ↔  controller v0.36.x  ↔  kubeseal CLI v0.36.6  ✓ (in sync)
```

Both the chart (Phase 6) and the kubeseal CLI in the setup guide (Phase 3) were updated together. If the chart is upgraded again, the CLI must be updated to match.

### Re-sealing note

When the controller is upgraded to a new major version, existing SealedSecrets may need to be re-sealed if the keypair format changes. The keypair in AWS Secrets Manager (`sealed-secrets`) remains valid — only the controller binary changes.

---

## 8. Karpenter

### Deployment

| | Value |
|---|---|
| Chart | `karpenter` |
| Repo | `oci://public.ecr.aws/karpenter` (OCI registry) |
| **Chart version** | **1.3.1** ✅ (upgraded from 0.36.1 in Phase 8) |
| File | `repos/gitops-system/tools/karpenter/karpenter-release.yaml` |
| Releases | https://github.com/aws/karpenter-provider-aws/releases |
| Docs | https://karpenter.sh |

### v1beta1 → v1 API migration — RESOLVED ✅ (Phase 8)

| API | Status |
|---|---|
| `karpenter.sh/v1beta1` → `karpenter.sh/v1` | ✅ Updated in node-pool.yaml |
| `karpenter.k8s.aws/v1beta1` → `karpenter.k8s.aws/v1` | ✅ Updated in node-pool.yaml, mgmt/karpenter-config.yaml, template/karpenter-config.yaml |

### AL2 → AL2023 — RESOLVED ✅ (Phase 8)

`amiFamily: AL2` updated to `amiFamily: AL2023` in `node-pool.yaml`. Amazon Linux 2 reaches end of support June 30, 2025.

### Hardcoded OIDC thumbprint (FP-3)

In `tools-config/crossplane-eks-composition/composition.yaml`, the OIDC IdP resource hardcodes a thumbprint:
```yaml
thumbprintList:
  - '9e99a48a9960b14926bb7f3b02e22da2b0ab7280'
```
AWS now validates OIDC IdPs using the full certificate chain. The field is still required by the API — replace with `0000000000000000000000000000000000000000` or fetch dynamically. See: https://github.com/aws/containers-roadmap/issues/1864

---

## 9. AWS Load Balancer Controller

### Deployment

| | Value |
|---|---|
| Chart | `aws-load-balancer-controller` |
| Repo | `https://aws.github.io/eks-charts` |
| **Chart version** | **1.11.0** ✅ (upgraded from 1.4.6 in Phase 7) |
| File | `repos/gitops-system/tools/aws-load-balancer-controller/aws-lb-controller-release.yaml` |
| Releases | https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases |
| Docs | https://kubernetes-sigs.github.io/aws-load-balancer-controller/ |

Notable improvements since 1.4.6: IPv6 support (v2.5), Shield Advanced integration (v2.6), NLB security group support (v2.7), webhook and TLS hardening.

---

## 10. AWS EBS CSI Driver

### Deployment

| | Value |
|---|---|
| Chart | `aws-ebs-csi-driver` |
| Repo | `https://kubernetes-sigs.github.io/aws-ebs-csi-driver` |
| **Chart version** | **2.38.1** ✅ (upgraded from 2.30.0 in Phase 7) |
| File | `repos/gitops-system/tools/aws-ebs-csi/aws-ebs-csi-release.yaml` |
| Releases | https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases |

---

## 11. Kubecost

### Deployment

| | Value |
|---|---|
| Chart | `cost-analyzer` |
| Repo | `oci://public.ecr.aws/kubecost` (OCI) |
| **Chart version** | **2.6.0** ✅ (upgraded from 2.2.2 in Phase 7) |
| File | `repos/gitops-system/tools/kubecost/kubecost-release.yaml` |
| Releases | https://github.com/kubecost/cost-analyzer-helm-chart/releases |
| Docs | https://docs.kubecost.com |

All images pulled from `public.ecr.aws/kubecost/*`. The `forecasting.fullImageName` explicitly pins `kubecost-modeling:v0.1.6` — review on next chart upgrade.

---

## 12. EKS Cluster Versions

### Management Cluster

| | Value |
|---|---|
| File | `initial-setup/config/mgmt-cluster-eksctl.yaml` |
| **K8s version** | **1.31** ✅ (updated from 1.29 in Phase 2) |
| Instance type | m5.large |
| Node count | 3 |
| Networking | Single NAT gateway |
| EKS release calendar | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

**Note:** The config file is updated. The live cluster upgrade is an operational step (`eksctl upgrade cluster`).

### Workload Cluster Template

| | Value |
|---|---|
| File | `repos/gitops-system/clusters-config/template/def/eks-cluster.yaml` |
| **Default `eks-k8s-version`** | **1.31** ✅ (updated from 1.28 in Phase 2) |
| **Default `mng-k8s-version`** | **1.31** ✅ |
| EKS 1.31 support end | ~late 2026 |
| Instance type | m5.large (hardcoded in Composition) |

---

## 13. Application: product-catalog-api

### Source

- v1: `repos/apps/product-catalog-api/v1/`
- v2: `repos/apps/product-catalog-api/v2/`

### Container Base Image — RESOLVED ✅ (Phase 1)

| | Value |
|---|---|
| **Base image** | **`python:3.12-slim`** ✅ (upgraded from `python:3.9-slim`) |
| Python 3.12 EOL | October 2028 |
| Python release schedule | https://devguide.python.org/versions/ |

### Python Dependencies (identical in v1 and v2)

| Package | Pinned | Notes |
|---|---|---|
| `flask-restx` | 1.3.0 | OK |
| `Flask` | 3.0.3 | Minor update available (3.1.x) |
| `werkzeug` | 3.0.4 | Minor update available (3.1.x) |
| `gunicorn` | 23.0.0 | OK |
| `requests` | `2.32.3` ✅ | Fixed — invalid `v` prefix removed (Phase 1) |
| `flask-cors` | 4.0.2 | Major version available (5.0.x) |
| `boto3` | 1.35.39 | Update recommended (1.38.x) |
| `markupsafe` | 2.1.5 | Major version available (3.0.x) |

### Kubernetes Manifests

- Base: `repos/apps-manifests/product-catalog-api-manifests/v1/kubernetes/base/`
- Overlays: `staging/`, `prod/`
- v2 staging adds a Crossplane `infra.yaml` for DynamoDB provisioning (`dynamodb.aws.crossplane.io/v1alpha1` — affected by FP-1)

---

## 14. Application: product-catalog-fe

### Source

`repos/apps/product-catalog-fe/`

### Container Base Image — RESOLVED ✅ (Phase 1)

| | Value |
|---|---|
| **Base image** | **`node:22-slim`** ✅ (upgraded from EOL `node:14`) |
| Node.js 22 LTS EOL | April 2027 |
| Node.js release schedule | https://nodejs.org/en/about/previous-releases |

### Node.js Dependencies (`package.json`)

| Package | Pinned range | Notes |
|---|---|---|
| `express` | ^4.21.1 | Express 5 is stable — breaking changes if upgrading |
| `axios` | ^1.7.4 | Minor update available (1.8.x) |
| `ejs` | ^3.1.10 | OK |
| `body-parser` | removed ✅ | Redundant with Express 4.16+ — removed in Phase 1; using `express.urlencoded()` |
| `prom-client` | ^14.0.1 | Major version available (15.x) |
| `nodemon` (dev) | ^2.0.18 | Major version available (3.x) — dev-only, low priority |

---

## 15. Deprecated Kubernetes API Versions

| apiVersion in repo | Correct apiVersion | Status |
|---|---|---|
| `helm.toolkit.fluxcd.io/v2beta1` | `helm.toolkit.fluxcd.io/v2` | ✅ Resolved — Phase 4 |
| `source.toolkit.fluxcd.io/v1beta2` | `source.toolkit.fluxcd.io/v1` | ✅ Resolved — Phase 4 |
| `kustomize.toolkit.fluxcd.io/v1beta2` | `kustomize.toolkit.fluxcd.io/v1` | ✅ Resolved — Phase 4 |
| `external-secrets.io/v1alpha1` | `external-secrets.io/v1beta1` | ✅ Resolved — Phase 5 |
| `karpenter.sh/v1beta1` | `karpenter.sh/v1` | ✅ Resolved — Phase 8 |
| `karpenter.k8s.aws/v1beta1` | `karpenter.k8s.aws/v1` | ✅ Resolved — Phase 8 |
| `pkg.crossplane.io/v1alpha1` (ControllerConfig) | `pkg.crossplane.io/v1beta1` (DeploymentRuntimeConfig) | ✅ Resolved — Phase 9 |
| `kubernetes.crossplane.io/v1alpha1` | `kubernetes.crossplane.io/v1alpha2` | Open — low priority |
| `ec2.aws.crossplane.io/v1beta1` | `ec2.aws.upbound.io/v1beta1` | Open — FP-1 (full composition rewrite) |
| `eks.aws.crossplane.io/v1beta1` | `eks.aws.upbound.io/v1beta1` | Open — FP-1 |
| `iam.aws.crossplane.io/v1beta1` | `iam.aws.upbound.io/v1beta1` | Open — FP-1 |

---

## 16. Deprecated Crossplane Constructs

### ControllerConfig — RESOLVED ✅ (Phase 9)

Both providers now use `DeploymentRuntimeConfig` (`pkg.crossplane.io/v1beta1`):
- `aws-provider.yaml`: `controllerConfigRef` → `runtimeConfigRef` ✅
- `k8s-provider.yaml`: same migration ✅
- `clusters/template/crossplane.yaml`: patch target updated to `DeploymentRuntimeConfig/v1beta1` ✅

### Composition patchSets

`tools-config/crossplane-eks-composition/composition.yaml` uses the v1 `patchSets` syntax. Still valid in Crossplane 1.19. Review against [Composition Functions](https://docs.crossplane.io/latest/guides/function-based-composition/) if planning a significant refactor.

### k8s-provider-config Job grants cluster-admin

The CronJob/Job in `crossplane-k8s-provider-config/k8s-providerconfig.yaml` grants `cluster-admin` to the Kubernetes provider's service account dynamically. Known workaround for provider-kubernetes RBAC bootstrapping. Review whether provider-kubernetes v0.16 resolves this without a CronJob workaround.

---

## 17. Upgrade Priority Matrix

| Priority | Component | Issue | Status |
|---|---|---|---|
| **P0** | product-catalog-fe Node.js 14 | EOL April 2023 | ✅ **RESOLVED** — Phase 1 → node:22-slim |
| **P0** | EKS workload clusters K8s 1.28 | EOL November 2024 | ✅ **RESOLVED** — Phase 2 → 1.31 template |
| **P0** | External Secrets Operator 0.4.4 | v1alpha1 API removed in ESO 0.9 | ✅ **RESOLVED** — Phase 5 → 0.10.7 + v1beta1 |
| **P1** | Crossplane `crossplane-contrib/provider-aws` | Monolithic provider archived | Open — **FP-1** (architectural rewrite) |
| **P1** | Karpenter 0.36.1 → 1.x | v1beta1 API removed, AL2 EOL Jun 2025 | ✅ **RESOLVED** — Phase 8 → 1.3.1 + v1 APIs + AL2023 |
| **P1** | `ControllerConfig` → `DeploymentRuntimeConfig` | Removed in Crossplane 1.17 | ✅ **RESOLVED** — Phase 9 |
| **P1** | EKS management cluster K8s 1.29 | EOL ~July 2025 | ✅ **RESOLVED** — Phase 2 template → 1.31 (live upgrade is operational) |
| **P2** | FluxCD v2.1.2 → v2.5.x | API deprecations accumulate | Open — **FP-2** (requires live bootstrap) |
| **P2** | Flux API versions (v1beta2→v1, etc.) | Will be removed in future Flux version | ✅ **RESOLVED** — Phase 4 (51 files) |
| **P2** | Python 3.9 base image | EOL October 2025 | ✅ **RESOLVED** — Phase 1 → python:3.12-slim |
| **P2** | `requests==v2.32.3` (invalid format) | Pip rejects leading `v` | ✅ **RESOLVED** — Phase 1 → `requests==2.32.3` |
| **P2** | kubectl in setup script (1.24.7) | Cannot communicate with 1.31 clusters | ✅ **RESOLVED** — Phase 3 → 1.31.0 |
| **P3** | provider-kubernetes 0.13.0 | Minor version lag | ✅ **RESOLVED** — Phase 9 → v0.16.0 |
| **P3** | AWS LB Controller chart 1.4.6 | 7 minor versions behind | ✅ **RESOLVED** — Phase 7 → 1.11.0 |
| **P3** | AWS EBS CSI chart 2.30.0 | Minor lag | ✅ **RESOLVED** — Phase 7 → 2.38.1 |
| **P3** | Kubecost 2.2.2 | Minor lag | ✅ **RESOLVED** — Phase 7 → 2.6.0 |
| **P3** | `body-parser` package | Redundant with Express 4.16+ | ✅ **RESOLVED** — Phase 1 → express.urlencoded() |
| **P3** | kubeseal v0.19.4 | Must sync with Sealed Secrets chart | ✅ **RESOLVED** — Phase 3+6 → v0.36.6 (in sync with chart 2.18.5) |
| **P3** | AL2 amiFamily in Karpenter NodePool | EOL June 2025 | ✅ **RESOLVED** — Phase 8 → AL2023 |
| **P3** | OIDC thumbprint hardcoded in Composition | AWS changed validation method | Open — **FP-3** |
| **P3** | `bitnami/kubectl:1.22.11` in k8s-config Job | K8s 1.22 EOL | ✅ **RESOLVED** — Phase 9 → bitnami/kubectl:1.31 |

---

## 18. Artifact Pull Reference

Quick reference for fetching all artifacts from scratch.

### Helm Repositories

```bash
# Crossplane
helm repo add crossplane-stable https://charts.crossplane.io/stable

# External Secrets
helm repo add external-secrets https://charts.external-secrets.io

# Sealed Secrets
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets

# AWS charts (LB Controller + EBS CSI)
helm repo add eks https://aws.github.io/eks-charts
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver

# Karpenter (OCI — no repo add required)
# helm install karpenter oci://public.ecr.aws/karpenter/karpenter --version 1.3.1

# Kubecost (OCI — no repo add required)
# helm install kubecost oci://public.ecr.aws/kubecost/cost-analyzer --version 2.6.0

helm repo update
```

### Crossplane Provider Packages (OCI)

```bash
# Current monolithic provider (ARCHIVED — FP-1: migrate to Upbound family)
# xpkg.upbound.io/crossplane-contrib/provider-aws:v0.47.1

# Recommended: Upbound official family providers
# xpkg.upbound.io/upbound/provider-family-aws:<version>
# xpkg.upbound.io/upbound/provider-aws-ec2:<version>
# xpkg.upbound.io/upbound/provider-aws-eks:<version>
# xpkg.upbound.io/upbound/provider-aws-iam:<version>

# Kubernetes provider
# xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.16.0
```

### GitHub Releases

| Tool | Release URL |
|---|---|
| FluxCD | https://github.com/fluxcd/flux2/releases |
| Crossplane | https://github.com/crossplane/crossplane/releases |
| Sealed Secrets | https://github.com/bitnami-labs/sealed-secrets/releases |
| Karpenter | https://github.com/aws/karpenter-provider-aws/releases |
| AWS LB Controller | https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases |
| AWS EBS CSI | https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases |
| External Secrets | https://github.com/external-secrets/external-secrets/releases |
| Kubecost | https://github.com/kubecost/cost-analyzer-helm-chart/releases |
| eksctl | https://github.com/eksctl-io/eksctl/releases |
| yq | https://github.com/mikefarah/yq/releases |
| kubeseal | https://github.com/bitnami-labs/sealed-secrets/releases |

### Container Base Images

| Image | Tag | Registry |
|---|---|---|
| Python API | `python:3.12-slim` ✅ | https://hub.docker.com/_/python |
| Node.js frontend | `node:22-slim` ✅ | https://hub.docker.com/_/node |
| kubectl utility | `bitnami/kubectl:1.31` ✅ | https://hub.docker.com/r/bitnami/kubectl |

### EKS AMI / K8s Versions

- EKS release calendar: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
- EKS optimized AMI: https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html
- AL2023 migration: https://docs.aws.amazon.com/eks/latest/userguide/al2023.html

---

## 19. Future Projects

These items were scoped out of the Phase 1–9 modernization plan. Each requires either live cluster access or a significant architectural change.

### FP-1: crossplane-contrib/provider-aws → Upbound family providers

**Scope:** The monolithic archived provider must be replaced with Upbound official family providers (`provider-aws-ec2`, `provider-aws-eks`, `provider-aws-iam`). Every resource in `tools-config/crossplane-eks-composition/composition.yaml` changes API group from `*.aws.crossplane.io` to `*.aws.upbound.io`. The DynamoDB resource in `repos/apps-manifests/product-catalog-api-manifests/v2-staging/kubernetes/overlays/staging/infra.yaml` is also affected. This involves rewriting 50+ managed resource definitions and migrating live cluster state without destroying infrastructure.

**Risk:** High — requires coordination with live clusters and careful state migration.

### FP-2: FluxCD upgrade (gotk-components.yaml regeneration)

**Scope:** `gotk-components.yaml` is pinned at FluxCD v2.1.2 and must NOT be manually edited. To upgrade, re-run `flux bootstrap` against the gitops-system repo with a newer Flux CLI. Requires live management cluster access.

**Command:**
```bash
flux bootstrap github \
  --owner=<org> \
  --repository=gitops-system \
  --branch=main \
  --path=clusters/mgmt
```

### FP-3: Crossplane Composition — OIDC thumbprint

**Scope:** The hardcoded thumbprint `9e99a48a9960b14926bb7f3b02e22da2b0ab7280` in `composition.yaml` is no longer required by AWS but the field is still mandatory in the API. Replace with `0000000000000000000000000000000000000000` as a neutral placeholder, or automate thumbprint fetching during cluster provisioning.

**Reference:** https://github.com/aws/containers-roadmap/issues/1864

---

*Original analysis: 2026-04-27. Updated: 2026-04-28 to reflect Phases 1–9 completion. Verify all version numbers before applying — package ecosystems move fast.*
