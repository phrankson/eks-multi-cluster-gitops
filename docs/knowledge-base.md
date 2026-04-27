# Knowledge Base: EKS Multi-Cluster GitOps

**Analysis date:** 2026-04-27  
**Repo origin:** aws-samples/multi-cluster-gitops (re-init 2024, component versions span 2022–2024)  
**Overall staleness:** HIGH — multiple components are at EOL or carry deprecated APIs that will break on upgrade

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

---

## 1. Stack Summary

| Layer | Tool | Pinned Version | Status |
|---|---|---|---|
| GitOps engine | FluxCD | v2.1.2 | Outdated |
| Infrastructure controller | Crossplane | v1.15.0 | Outdated |
| AWS provider (Crossplane) | crossplane-contrib/provider-aws | v0.47.1 | **Archived** |
| K8s provider (Crossplane) | crossplane-contrib/provider-kubernetes | v0.13.0 | Outdated |
| Secrets (Git) | Sealed Secrets | chart 2.7.1 | Outdated |
| Secrets (AWS SM) | External Secrets Operator | chart 0.4.4 | **Critical — v1alpha1 API removed** |
| Node autoscaler | Karpenter | v0.36.1 | **API breaking change in v1.x** |
| Load balancer | AWS Load Balancer Controller | chart 1.4.6 | Outdated |
| Storage | AWS EBS CSI Driver | chart 2.30.0 | Outdated |
| Cost visibility | Kubecost cost-analyzer | chart 2.2.2 | Outdated |
| Management cluster | EKS | 1.29 | Approaching EOL |
| Workload cluster template | EKS | 1.28 | **EOL** |
| API backend | Python / Flask | 3.9 / 3.0.3 | Python 3.9 approaching EOL |
| Web frontend | Node.js | 14 | **EOL April 2023** |
| Bootstrap environment | AWS Cloud9 | Ubuntu 18.04 | **Ubuntu 18.04 EOL** |

---

## 2. CLI Tools Required

These versions are pinned in `initial-setup/README.md` and the CFN template. All require updates.

### kubectl
| | Value |
|---|---|
| Pinned version | 1.24.7 |
| Install command (from setup) | `s3.us-west-2.amazonaws.com/amazon-eks/1.24.7/2022-10-31/bin/linux/amd64/kubectl` |
| Required version | Must be within one minor version of your EKS cluster (1.28–1.30) |
| Current stable | 1.32.x |
| Get current | https://dl.k8s.io/release/stable.txt |
| Download | `https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl` |
| **Action** | Update install script to use EKS-version-matched kubectl |

### Flux CLI
| | Value |
|---|---|
| Pinned version | v2.1.2 (implied — bootstrap generates gotk-components.yaml at this version) |
| Install | `curl -s https://fluxcd.io/install.sh | sudo bash` (fetches latest) |
| Current stable | v2.5.x |
| Releases | https://github.com/fluxcd/flux2/releases |
| **Action** | Flux CLI version must match the deployed FluxCD version. If upgrading FluxCD, run `flux install` to regenerate `gotk-components.yaml`. |

### kubeseal
| | Value |
|---|---|
| Pinned version | v0.19.4 |
| Download (setup script) | `https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.4/kubeseal-0.19.4-linux-amd64.tar.gz` |
| Current stable | v0.27.x |
| Releases | https://github.com/bitnami-labs/sealed-secrets/releases |
| **CRITICAL** | kubeseal CLI version must match the Sealed Secrets controller chart version. Currently chart is 2.7.1 (controller v0.19.5). If upgrading the chart, update the CLI to match. |

### eksctl
| | Value |
|---|---|
| Pinned version | "latest" at install time |
| Install | `https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz` |
| Current stable | v0.208.x |
| Releases | https://github.com/eksctl-io/eksctl/releases |
| **Action** | Re-pin to a specific version for reproducibility. Weaveworks transferred the repo to `eksctl-io/eksctl`. |

### yq
| | Value |
|---|---|
| Pinned version | v4.24.5 |
| Download | `https://github.com/mikefarah/yq/releases/download/v4.24.5/yq_linux_amd64` |
| Current stable | v4.45.x |
| Releases | https://github.com/mikefarah/yq/releases |
| **Action** | Update to v4.44+ (no breaking changes in 4.x series) |

### AWS CLI
| | Value |
|---|---|
| Pinned version | v2 (latest) |
| Install | `https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip` |
| Current | v2.24.x |
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
- **Pinned version:** v2.1.2 (stamped in gotk-components.yaml header)
- **Current stable:** v2.5.x
- **Releases:** https://github.com/fluxcd/flux2/releases
- **Changelog:** https://fluxcd.io/flux/releases/

### Components installed
`source-controller`, `kustomize-controller`, `helm-controller`, `notification-controller`

### Deprecated API versions in use (across ALL manifests)

| API in repo | Replacement | Deprecated since |
|---|---|---|
| `helm.toolkit.fluxcd.io/v2beta1` | `helm.toolkit.fluxcd.io/v2` | Flux 2.3 |
| `source.toolkit.fluxcd.io/v1beta2` | `source.toolkit.fluxcd.io/v1` | Flux 2.0 |
| `kustomize.toolkit.fluxcd.io/v1beta2` | `kustomize.toolkit.fluxcd.io/v1` | Flux 2.0 |

**Affected files (all HelmRelease and GitRepository/Kustomization manifests):**
- `repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml`
- `repos/gitops-system/tools/crossplane/crossplane-aws-provider.yaml`
- `repos/gitops-system/tools/crossplane/crossplane-k8s-provider.yaml`
- `repos/gitops-system/tools/external-secrets/external-secrets-release.yaml`
- `repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml`
- `repos/gitops-system/tools/karpenter/karpenter-release.yaml`
- `repos/gitops-system/tools/aws-load-balancer-controller/aws-lb-controller-release.yaml`
- `repos/gitops-system/tools/aws-ebs-csi/aws-ebs-csi-release.yaml`
- `repos/gitops-system/tools/kubecost/kubecost-release.yaml`
- All `gotk-sync.yaml` and `kustomization.yaml` files under `clusters/`

### Upgrade path
```bash
# 1. Update Flux CLI to target version
curl -s https://fluxcd.io/install.sh | sudo bash   # or pin: FLUX_VERSION=v2.5.1

# 2. Re-bootstrap (regenerates gotk-components.yaml)
flux bootstrap github \
  --owner=<org> \
  --repository=gitops-system \
  --branch=main \
  --path=clusters/mgmt

# 3. Update all apiVersion fields in manifests (sed or yq across repo)
```

---

## 4. Crossplane Core

### Deployment
- **Chart:** `crossplane` from `https://charts.crossplane.io/stable`
- **Pinned chart version:** 1.15.0
- **File:** `repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml`
- **Current chart version:** 1.19.x
- **Releases:** https://github.com/crossplane/crossplane/releases
- **Helm chart:** https://charts.crossplane.io/stable (index at https://charts.crossplane.io/stable/index.yaml)
- **Migration guide (1.15→1.19):** https://docs.crossplane.io/latest/guides/

### Key deprecation: ControllerConfig → DeploymentRuntimeConfig

**ControllerConfig** (`pkg.crossplane.io/v1alpha1`) was deprecated in Crossplane 1.14 and removed in 1.17+.

**Affected files:**
- `repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml` — uses `ControllerConfig` named `aws-config`
- `repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml` — uses `ControllerConfig` named `k8s-config`

**Replacement:** `DeploymentRuntimeConfig` (`pkg.crossplane.io/v1beta1`)

```yaml
# OLD (deprecated)
apiVersion: pkg.crossplane.io/v1alpha1
kind: ControllerConfig
metadata:
  name: aws-config
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/crossplane-role
spec:
  podSecurityContext:
    fsGroup: 2000

# NEW
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: aws-config
spec:
  deploymentTemplate:
    spec:
      selector: {}
      template:
        metadata:
          annotations:
            eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/crossplane-role
        spec:
          securityContext:
            fsGroup: 2000
```

### k8s-provider-config-job: stale kubectl image

- **File:** `repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml`
- **Image in use:** `bitnami/kubectl:1.22.11` (Kubernetes 1.22 is EOL since 2022-10-28)
- **Replacement:** `bitnami/kubectl:1.29` or `public.ecr.aws/aws-cli/aws-cli` + kubectl binary
- **Note:** This Job + CronJob grants `cluster-admin` to the Kubernetes provider SA. This is a known workaround pattern but is a security concern worth reviewing.

---

## 5. Crossplane Providers

### AWS Provider

| | Value |
|---|---|
| Package | `xpkg.upbound.io/crossplane-contrib/provider-aws:v0.47.1` |
| File | `repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml` |
| Registry | https://marketplace.upbound.io/providers/crossplane-contrib/provider-aws |
| Status | **ARCHIVED** — the monolithic community provider is no longer maintained |

**Critical architectural issue:** Upbound replaced the monolithic `crossplane-contrib/provider-aws` with a family of granular official providers. The new providers have different package names and different API group paths.

| Old (archived) | New (official Upbound) |
|---|---|
| `crossplane-contrib/provider-aws` | `upbound/provider-family-aws` (root) |
| `ec2.aws.crossplane.io/v1beta1` | `ec2.aws.upbound.io/v1beta1` |
| `eks.aws.crossplane.io/v1beta1` | `eks.aws.upbound.io/v1beta1` |
| `iam.aws.crossplane.io/v1beta1` | `iam.aws.upbound.io/v1beta1` |

**Impact:** Every resource in the Crossplane composition (`tools-config/crossplane-eks-composition/composition.yaml`) uses the old API groups. A migration requires:
1. Installing the new provider family packages
2. Rewriting all Composition resources to use `*.aws.upbound.io` API groups
3. Migrating existing managed resources (or deleting and recreating — with care around EKS clusters)

**New provider packages (from Upbound Marketplace):**
- Root: `xpkg.upbound.io/upbound/provider-family-aws`
- EC2: `xpkg.upbound.io/upbound/provider-aws-ec2`
- EKS: `xpkg.upbound.io/upbound/provider-aws-eks`
- IAM: `xpkg.upbound.io/upbound/provider-aws-iam`
- Marketplace: https://marketplace.upbound.io/providers/upbound/provider-family-aws

### Kubernetes Provider

| | Value |
|---|---|
| Package | `xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.13.0` |
| File | `repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml` |
| Current stable | v0.16.x |
| Releases | https://github.com/crossplane-contrib/provider-kubernetes/releases |
| Marketplace | https://marketplace.upbound.io/providers/crossplane-contrib/provider-kubernetes |
| API version in use | `kubernetes.crossplane.io/v1alpha1` (Object, ProviderConfig) |
| Current API version | `kubernetes.crossplane.io/v1alpha2` |

---

## 6. External Secrets Operator

### Deployment

| | Value |
|---|---|
| Chart | `external-secrets` |
| Repo | `https://charts.external-secrets.io` |
| Pinned chart version | **0.4.4** |
| Current stable | 0.10.x |
| File | `repos/gitops-system/tools/external-secrets/external-secrets-release.yaml` |
| Releases | https://github.com/external-secrets/external-secrets/releases |
| Helm index | https://charts.external-secrets.io/index.yaml |

### Critical: v1alpha1 API removed in ESO 0.9+

The repo uses `external-secrets.io/v1alpha1` for both `SecretStore` and `ExternalSecret`:

- **File:** `repos/gitops-system/tools-config/external-secrets/sealed-secrets-key.yaml`

```yaml
# CURRENTLY IN REPO (broken on ESO >= 0.9)
apiVersion: external-secrets.io/v1alpha1
kind: SecretStore
---
apiVersion: external-secrets.io/v1alpha1
kind: ExternalSecret
```

**Required:**
```yaml
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
```

**Migration guide:** https://external-secrets.io/latest/guides/upgrade-guide-0.9/

---

## 7. Sealed Secrets

### Deployment

| | Value |
|---|---|
| Chart | `sealed-secrets` |
| Repo | `https://bitnami-labs.github.io/sealed-secrets` |
| Pinned chart version | **2.7.1** (controller v0.19.5) |
| Current chart | 2.16.x (controller v0.27.x) |
| File | `repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml` |
| Releases | https://github.com/bitnami-labs/sealed-secrets/releases |
| Helm index | https://bitnami-labs.github.io/sealed-secrets/index.yaml |

### CLI version coupling

**The `kubeseal` CLI must match the controller version.** The setup script installs kubeseal v0.19.4, which matches chart 2.7.1 (controller v0.19.5). If the chart is upgraded without upgrading kubeseal, encryption will fail.

```
chart 2.7.1  ↔  controller v0.19.5  ↔  kubeseal CLI v0.19.4  ✓ (compatible)
chart 2.16.x ↔  controller v0.27.x  ↔  kubeseal CLI v0.27.x  (required after upgrade)
```

### Re-sealing required on upgrade

When the controller is upgraded to a new major version, existing SealedSecrets may need to be re-sealed if the keypair format changes. The keypair stored in AWS Secrets Manager (`sealed-secrets` secret) remains valid — only the controller binary changes.

---

## 8. Karpenter

### Deployment

| | Value |
|---|---|
| Chart | `karpenter` |
| Repo | `oci://public.ecr.aws/karpenter` (OCI registry) |
| Pinned chart version | **0.36.1** |
| Current stable | 1.3.x |
| File | `repos/gitops-system/tools/karpenter/karpenter-release.yaml` |
| Releases | https://github.com/aws/karpenter-provider-aws/releases |
| Docs | https://karpenter.sh |

### Breaking API change: v0.x → v1.x

Karpenter v1.0 was released in 2024. It introduces **breaking API changes**:

| API in repo | v1.x API | Breaking |
|---|---|---|
| `karpenter.sh/v1beta1` → `NodePool` | `karpenter.sh/v1` | Yes |
| `karpenter.k8s.aws/v1beta1` → `EC2NodeClass` | `karpenter.k8s.aws/v1` | Yes |

**Affected files:**
- `repos/gitops-system/tools-config/karpenter-config/node-pool.yaml`
- `repos/gitops-system/clusters/mgmt/karpenter-config.yaml` (inline patch)
- `repos/gitops-system/clusters/template/karpenter-config.yaml` (inline patch)

**Migration guide:** https://karpenter.sh/docs/upgrading/upgrade-guide/

### Amazon Linux 2 (AL2) EOL

The `EC2NodeClass` in `node-pool.yaml` uses `amiFamily: AL2`. Amazon Linux 2 reaches end of support **June 30, 2025**. Must migrate to `amiFamily: AL2023`.

```yaml
# CHANGE THIS
spec:
  amiFamily: AL2

# TO THIS
spec:
  amiFamily: AL2023
```

### Hardcoded OIDC thumbprint in Crossplane composition

In `tools-config/crossplane-eks-composition/composition.yaml`, the OIDC IdP resource hardcodes a thumbprint:
```yaml
thumbprintList:
  - '9e99a48a9960b14926bb7f3b02e22da2b0ab7280'
```
AWS now validates OIDC IdPs using the full certificate chain and no longer requires this thumbprint. However, the field is still required by the API — use the value `0000000000000000000000000000000000000000` as a placeholder, or fetch the actual current thumbprint dynamically. See: https://github.com/aws/containers-roadmap/issues/1864

---

## 9. AWS Load Balancer Controller

### Deployment

| | Value |
|---|---|
| Chart | `aws-load-balancer-controller` |
| Repo | `https://aws.github.io/eks-charts` |
| Pinned chart version | **1.4.6** |
| Current stable | 1.11.x |
| File | `repos/gitops-system/tools/aws-load-balancer-controller/aws-lb-controller-release.yaml` |
| Releases | https://github.com/kubernetes-sigs/aws-load-balancer-controller/releases |
| Helm index | https://aws.github.io/eks-charts/index.yaml |
| Docs | https://kubernetes-sigs.github.io/aws-load-balancer-controller/ |

Chart version 1.4.6 corresponds to controller v2.4.x. Current is v2.12.x. Notable changes across that range:
- IPv6 support added (v2.5)
- Shield Advanced integration (v2.6)
- NLB security group support (v2.7)
- Various webhook and TLS hardening improvements

---

## 10. AWS EBS CSI Driver

### Deployment

| | Value |
|---|---|
| Chart | `aws-ebs-csi-driver` |
| Repo | `https://kubernetes-sigs.github.io/aws-ebs-csi-driver` |
| Pinned chart version | **2.30.0** |
| Current stable | 2.38.x |
| File | `repos/gitops-system/tools/aws-ebs-csi/aws-ebs-csi-release.yaml` |
| Releases | https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases |
| Helm index | https://kubernetes-sigs.github.io/aws-ebs-csi-driver/index.yaml |

---

## 11. Kubecost

### Deployment

| | Value |
|---|---|
| Chart | `cost-analyzer` |
| Repo | `oci://public.ecr.aws/kubecost` (OCI) |
| Pinned chart version | **2.2.2** |
| Current stable | 2.6.x |
| File | `repos/gitops-system/tools/kubecost/kubecost-release.yaml` |
| Releases | https://github.com/kubecost/cost-analyzer-helm-chart/releases |
| Docs | https://docs.kubecost.com |

All images are pulled from `public.ecr.aws/kubecost/*`. No image tag pinning — Helm chart controls image versions. The Kubecost `forecasting.fullImageName` explicitly pins `kubecost-modeling:v0.1.6` which may be stale.

---

## 12. EKS Cluster Versions

### Management Cluster

| | Value |
|---|---|
| File | `initial-setup/config/mgmt-cluster-eksctl.yaml` |
| K8s version | **1.29** |
| Instance type | m5.large |
| Node count | 3 |
| Networking | Single NAT gateway |
| EKS 1.29 support end | ~July 2025 |
| EKS release calendar | https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html |

### Workload Cluster Template

| | Value |
|---|---|
| File | `repos/gitops-system/clusters-config/template/def/eks-cluster.yaml` |
| Default `eks-k8s-version` | **1.28** |
| Default `mng-k8s-version` | **1.28** |
| EKS 1.28 support end | **November 2024 — already EOL** |
| Instance type | m5.large (hardcoded in Composition) |

**EKS 1.28 is EOL.** Workload clusters created from the default template will be on an unsupported Kubernetes version. Upgrade the template default to at minimum 1.31 (supported through late 2026).

### CFN-based setup: allowed K8s versions

The `initial-setup/auto/cfn.yaml` template only permits versions `1.27`, `1.28`, `1.29` — all now EOL or near-EOL. The `AllowedValues` must be updated before the CFN stack can be used to create new environments.

---

## 13. Application: product-catalog-api

### Source

- v1: `repos/apps/product-catalog-api/v1/`
- v2: `repos/apps/product-catalog-api/v2/`

### Container Base Image

| | Value |
|---|---|
| Base image | `python:3.9-slim` |
| Python 3.9 EOL | **October 2025** |
| Recommended | `python:3.12-slim` or `python:3.13-slim` |
| Python release schedule | https://devguide.python.org/versions/ |

### Python Dependencies (identical in v1 and v2)

| Package | Pinned | Latest | Notes |
|---|---|---|---|
| `flask-restx` | 1.3.0 | 1.3.0 | OK |
| `Flask` | 3.0.3 | 3.1.x | Minor update available |
| `werkzeug` | 3.0.4 | 3.1.x | Minor update available |
| `gunicorn` | 23.0.0 | 23.0.0 | OK |
| `requests` | `v2.32.3` | 2.32.3 | **Invalid version format** — the `v` prefix causes pip to fail silently or error. Change to `requests==2.32.3` |
| `flask-cors` | 4.0.2 | 5.0.x | Major version available |
| `boto3` | 1.35.39 | 1.38.x | Update recommended |
| `markupsafe` | 2.1.5 | 3.0.x | Major version available |

### Kubernetes Manifests

- Base: `repos/apps-manifests/product-catalog-api-manifests/v1/kubernetes/base/`
- Overlays: `staging/`, `prod/`
- v2 staging adds a Crossplane `infra.yaml` for DynamoDB provisioning

---

## 14. Application: product-catalog-fe

### Source

`repos/apps/product-catalog-fe/`

### Container Base Image

| | Value |
|---|---|
| Base image | `node:14` |
| Node.js 14 EOL | **April 30, 2023 — CRITICAL** |
| Recommended | `node:22-slim` (LTS) or `node:20-slim` |
| Node.js release schedule | https://nodejs.org/en/about/previous-releases |

This is a hard security risk — Node.js 14 has received no security patches since April 2023.

### Node.js Dependencies (`package.json`)

| Package | Pinned range | Latest | Notes |
|---|---|---|---|
| `express` | ^4.21.1 | 5.x | Express 5 is stable since late 2024 — breaking changes |
| `axios` | ^1.7.4 | 1.8.x | Minor update available |
| `ejs` | ^3.1.10 | 3.1.10 | OK |
| `body-parser` | ^1.20.3 | — | **Redundant** — `body-parser` is bundled in Express 4.16+; use `express.json()` and `express.urlencoded()` instead |
| `prom-client` | ^14.0.1 | 15.x | Major version available |
| `nodemon` (dev) | ^2.0.18 | 3.x | Major version available; dev-only, low priority |

---

## 15. Deprecated Kubernetes API Versions

Complete list of deprecated/removed API versions found across all manifests:

| apiVersion in repo | Correct apiVersion | Deprecated | Removed |
|---|---|---|---|
| `helm.toolkit.fluxcd.io/v2beta1` | `helm.toolkit.fluxcd.io/v2` | Flux 2.3 | Not yet announced — fix proactively |
| `source.toolkit.fluxcd.io/v1beta2` | `source.toolkit.fluxcd.io/v1` | Flux 2.0 | Not yet announced — fix proactively |
| `kustomize.toolkit.fluxcd.io/v1beta2` | `kustomize.toolkit.fluxcd.io/v1` | Flux 2.0 | Not yet announced — fix proactively |
| `external-secrets.io/v1alpha1` | `external-secrets.io/v1beta1` | ESO 0.8 | **ESO 0.9** |
| `karpenter.sh/v1beta1` | `karpenter.sh/v1` | Karpenter 0.37 | **Karpenter 1.0** |
| `karpenter.k8s.aws/v1beta1` | `karpenter.k8s.aws/v1` | Karpenter 0.37 | **Karpenter 1.0** |
| `pkg.crossplane.io/v1alpha1` (ControllerConfig) | `pkg.crossplane.io/v1beta1` (DeploymentRuntimeConfig) | Crossplane 1.14 | **Crossplane 1.17** |
| `kubernetes.crossplane.io/v1alpha1` | `kubernetes.crossplane.io/v1alpha2` | provider-k8s 0.10 | — |
| `ec2.aws.crossplane.io/v1beta1` | `ec2.aws.upbound.io/v1beta1` | provider-aws archived | — |
| `eks.aws.crossplane.io/v1beta1` | `eks.aws.upbound.io/v1beta1` | provider-aws archived | — |
| `iam.aws.crossplane.io/v1beta1` | `iam.aws.upbound.io/v1beta1` | provider-aws archived | — |

---

## 16. Deprecated Crossplane Constructs

### ControllerConfig (deprecated, will be removed)

`ControllerConfig` (`pkg.crossplane.io/v1alpha1`) is deprecated since Crossplane 1.14 and removed in 1.17+. Replaced by `DeploymentRuntimeConfig` (`pkg.crossplane.io/v1beta1`).

Files to update:
- `repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml`
- `repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml`

### Composition patchSets with `type: ToCompositeFieldPath`

The existing Composition in `tools-config/crossplane-eks-composition/composition.yaml` uses the v1 `patchSets` syntax. This is still valid in Crossplane 1.15+, but review against [Composition Functions](https://docs.crossplane.io/latest/guides/function-based-composition/) if planning a significant refactor — Functions replace pipelines-style patches in modern Crossplane.

### k8s-provider-config Job grants cluster-admin

The CronJob/Job in `crossplane-k8s-provider-config/k8s-providerconfig.yaml` grants `cluster-admin` to the Kubernetes provider's service account dynamically. This is a known workaround for provider-kubernetes RBAC bootstrapping. Review whether `provider-kubernetes` v0.14+ resolves this without a CronJob workaround.

---

## 17. Upgrade Priority Matrix

| Priority | Component | Issue | Risk if not addressed |
|---|---|---|---|
| **P0 — Immediate** | product-catalog-fe Node.js 14 | EOL April 2023, no security patches | Active security vulnerabilities |
| **P0 — Immediate** | EKS workload clusters K8s 1.28 | EOL November 2024 | Unsupported, no patches |
| **P0 — Immediate** | External Secrets Operator 0.4.4 | `v1alpha1` API removed in ESO 0.9 | Sealed Secrets key injection fails on upgrade |
| **P1 — Short term** | Crossplane `crossplane-contrib/provider-aws` | Monolithic provider archived | No bug fixes, no new AWS service support |
| **P1 — Short term** | Karpenter 0.36.1 → 1.x | v1beta1 API removed, AL2 EOL June 2025 | Node provisioning breaks post-upgrade |
| **P1 — Short term** | `ControllerConfig` → `DeploymentRuntimeConfig` | Removed in Crossplane 1.17 | Crossplane upgrade blocked |
| **P1 — Short term** | EKS management cluster K8s 1.29 | EOL ~July 2025 | Unsupported cluster |
| **P2 — Medium term** | FluxCD v2.1.2 → v2.5.x | API deprecations accumulate | Kustomization/HelmRelease drift |
| **P2 — Medium term** | Flux API versions (v1beta2→v1, etc.) | Will be removed in future Flux version | Bootstrap breaks on Flux upgrade |
| **P2 — Medium term** | Python 3.9 base image | EOL October 2025 | Security vulnerabilities |
| **P2 — Medium term** | `requests==v2.32.3` (invalid format) | Pip may error or install wrong version | Silent dependency failure |
| **P2 — Medium term** | kubectl in setup script (1.24.7) | Cannot communicate with 1.28+ clusters | CLI errors, skewed API calls |
| **P3 — Low** | Crossplane provider-kubernetes 0.13.0 | Minor version lag | Missing features, possible minor bugs |
| **P3 — Low** | AWS LB Controller chart 1.4.6 | 7 minor versions behind | Missing features (IPv6, Shield) |
| **P3 — Low** | AWS EBS CSI chart 2.30.0 | Minor lag | Minor bug fixes missed |
| **P3 — Low** | Kubecost 2.2.2 | Minor lag | Missing cost model improvements |
| **P3 — Low** | Node.js `body-parser` package | Redundant with Express 4.16+ | Code bloat |
| **P3 — Low** | kubeseal v0.19.4 | Must stay in sync with chart 2.7.1 | Only a risk if Sealed Secrets chart is upgraded without upgrading CLI |
| **P3 — Low** | AL2 amiFamily in Karpenter NodePool | EOL June 2025 | Karpenter stops finding valid AMIs |
| **P3 — Low** | OIDC thumbprint hardcoded in Composition | AWS changed validation method | May cause OIDC provider creation errors |
| **P3 — Low** | `bitnami/kubectl:1.22.11` in k8s-config Job | K8s 1.22 EOL | kubectl API skew errors |

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
# helm install karpenter oci://public.ecr.aws/karpenter/karpenter --version <version>

# Kubecost (OCI — no repo add required)
# helm install kubecost oci://public.ecr.aws/kubecost/cost-analyzer --version <version>

helm repo update
```

### Crossplane Provider Packages (OCI)

```bash
# Current monolithic provider (ARCHIVED — do not use for new deployments)
# xpkg.upbound.io/crossplane-contrib/provider-aws:v0.47.1

# Recommended: Upbound official family providers
# xpkg.upbound.io/upbound/provider-family-aws:<version>
# xpkg.upbound.io/upbound/provider-aws-ec2:<version>
# xpkg.upbound.io/upbound/provider-aws-eks:<version>
# xpkg.upbound.io/upbound/provider-aws-iam:<version>

# Kubernetes provider
# xpkg.upbound.io/crossplane-contrib/provider-kubernetes:<version>
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

| Image | Recommended tag | Registry |
|---|---|---|
| Python API | `python:3.12-slim` | https://hub.docker.com/_/python |
| Node.js frontend | `node:22-slim` | https://hub.docker.com/_/node |
| kubectl utility | `bitnami/kubectl:1.29` | https://hub.docker.com/r/bitnami/kubectl |

### EKS AMI / K8s Versions

- EKS release calendar: https://docs.aws.amazon.com/eks/latest/userguide/kubernetes-versions.html
- EKS optimized AMI: https://docs.aws.amazon.com/eks/latest/userguide/eks-optimized-ami.html
- AL2023 migration: https://docs.aws.amazon.com/eks/latest/userguide/al2023.html

---

*Generated by analysis of all manifests, Dockerfiles, and requirements files in the repository. Verify all "current stable" version numbers before applying — this document reflects state as of 2026-04-27.*
