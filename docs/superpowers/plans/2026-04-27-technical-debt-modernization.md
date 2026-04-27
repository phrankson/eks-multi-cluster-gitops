# Technical Debt & Modernization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the eks-multi-cluster-gitops repo from its 2022–2024 vintage state to a safe, supported, deployable baseline by fixing EOL runtimes, deprecated Kubernetes/Flux API versions, stale Helm chart versions, and broken version references in setup tooling.

**Architecture:** Changes are organised into 9 sequential phases. Each phase is independently committable and safe to deploy in isolation (with the exception of Phase 5 and Phase 6, which must be applied together with a matching kubeseal CLI version). The crossplane-contrib/provider-aws → Upbound family-provider migration is explicitly **out of scope** — it requires a full Composition rewrite and is tracked as a separate project.

**Tech Stack:** Flux CD, Crossplane, Karpenter, External Secrets Operator, Sealed Secrets, AWS LB Controller, AWS EBS CSI, Kubecost, EKS, Python 3, Node.js, Helm, kubectl, kubeseal, yq, eksctl

**Reference document:** `docs/knowledge-base.md` — consult this for full rationale behind every version decision.

---

## Scope Boundaries

### In scope (this plan)
- P0: EOL container runtimes (Node 14, Python 3.9)
- P0: EKS cluster versions at/past EOL
- P1: Deprecated and soon-removed Kubernetes/Flux/Karpenter/Crossplane API versions
- P1: Helm chart version bumps for all managed tools
- P2: Broken pip version string, stale CLI tool references

### Out of scope (future project)
- **crossplane-contrib/provider-aws → Upbound family providers** — the monolithic provider is archived but still functional on the pinned version. Migration requires rewriting the entire Crossplane Composition (50+ managed resources, all API groups change). Track separately.

---

## File Map

Every file this plan touches, grouped by phase:

**Phase 1 — Container base images**
- `repos/apps/product-catalog-fe/Dockerfile` — `node:14` → `node:22-slim`
- `repos/apps/product-catalog-api/v1/Dockerfile` — `python:3.9-slim` → `python:3.12-slim`
- `repos/apps/product-catalog-api/v2/Dockerfile` — `python:3.9-slim` → `python:3.12-slim`
- `repos/apps/product-catalog-api/v1/requirements.txt` — fix `v2.32.3` pip typo
- `repos/apps/product-catalog-api/v2/requirements.txt` — fix `v2.32.3` pip typo
- `repos/apps/product-catalog-fe/package.json` — remove redundant `body-parser`

**Phase 2 — EKS cluster version defaults**
- `initial-setup/config/mgmt-cluster-eksctl.yaml` — K8s `1.29` → `1.31`
- `repos/gitops-system/clusters-config/template/def/eks-cluster.yaml` — `1.28` → `1.31`
- `initial-setup/auto/cfn.yaml` — `AllowedValues` update, CloudFormation default K8s version

**Phase 3 — CLI tool version references in setup docs**
- `initial-setup/README.md` — kubectl `1.24.7`, kubeseal `v0.19.4`, yq `v4.24.5`

**Phase 4 — Flux API version mass replacement (52 files)**
All files under `repos/` containing `v2beta1` or `v1beta2`:
- `repos/gitops-system/tools/**/*.yaml` (all HelmRelease, HelmRepository, GitRepository)
- `repos/gitops-system/clusters/**/*.yaml` (all Kustomization resources)
- `repos/gitops-system/clusters-config/template/*.yaml`
- `repos/gitops-system/workloads/template/**/*.yaml`
- `repos/gitops-workloads/template/**/*.yaml`

**Phase 5 — External Secrets Operator**
- `repos/gitops-system/tools/external-secrets/external-secrets-release.yaml` — chart `0.4.4` → `0.10.7`
- `repos/gitops-system/tools-config/external-secrets/sealed-secrets-key.yaml` — `v1alpha1` → `v1beta1`

**Phase 6 — Sealed Secrets**
- `repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml` — chart `2.7.1` → `2.16.2`
- `initial-setup/README.md` — kubeseal CLI version (also done in Phase 3, verify consistency)

**Phase 7 — AWS toolchain Helm charts**
- `repos/gitops-system/tools/aws-load-balancer-controller/aws-lb-controller-release.yaml` — `1.4.6` → `1.11.0`
- `repos/gitops-system/tools/aws-ebs-csi/aws-ebs-csi-release.yaml` — `2.30.0` → `2.38.1`
- `repos/gitops-system/tools/kubecost/kubecost-release.yaml` — `2.2.2` → `2.6.0`

**Phase 8 — Karpenter v0.36 → v1.x migration**
- `repos/gitops-system/tools/karpenter/karpenter-release.yaml` — `0.36.1` → `1.3.1`
- `repos/gitops-system/tools-config/karpenter-config/node-pool.yaml` — API + amiFamily
- `repos/gitops-system/clusters/mgmt/karpenter-config.yaml` — inline patch API versions
- `repos/gitops-system/clusters/template/karpenter-config.yaml` — inline patch API versions

**Phase 9 — Crossplane core modernization**
- `repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml` — `1.15.0` → `1.19.2`
- `repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml` — ControllerConfig → DeploymentRuntimeConfig
- `repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml` — ControllerConfig → DeploymentRuntimeConfig, provider `v0.13.0` → `v0.16.0`
- `repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml` — `bitnami/kubectl:1.22.11` → `bitnami/kubectl:1.31`

---

## Phase 1 — Container Base Images

**Why first:** Node.js 14 is EOL since April 2023. Python 3.9 EOLs October 2025. These are active security risks with no upstream CVE patches. No other phase depends on this.

### Task 1.1 — Upgrade product-catalog-fe to Node.js 22

**Files:**
- Modify: `repos/apps/product-catalog-fe/Dockerfile`
- Modify: `repos/apps/product-catalog-fe/package.json`

- [ ] **Step 1: Update the Dockerfile base image**

```dockerfile
# repos/apps/product-catalog-fe/Dockerfile
FROM node:22-slim

WORKDIR /usr/src/app

COPY package.json package-lock.json ./

RUN npm ci --only=production

COPY . .

EXPOSE 9000
CMD [ "node", "server.js" ]
```

- [ ] **Step 2: Remove the redundant `body-parser` dependency from package.json**

The `body-parser` package has been bundled into Express since v4.16. Using `express.json()` and `express.urlencoded()` directly is the correct approach.

```json
{
  "name": "frontend-node",
  "version": "1.0.0",
  "description": "front end application for microservices in app mesh",
  "main": "index.js",
  "scripts": {
    "dev": "nodemon server.js",
    "test": "echo \"Error: no test specified\" && exit 1"
  },
  "author": "Praseeda Sathaye",
  "license": "MIT-0",
  "dependencies": {
    "axios": "^1.7.4",
    "ejs": "^3.1.10",
    "express": "^4.21.1",
    "prom-client": "^14.0.1"
  },
  "devDependencies": {
    "nodemon": "^2.0.18"
  }
}
```

- [ ] **Step 3: Check server.js for body-parser imports and replace**

```bash
grep -n "body-parser\|bodyParser" repos/apps/product-catalog-fe/server.js
```

If `require('body-parser')` is found, replace:
```js
// OLD
const bodyParser = require('body-parser');
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: false }));

// NEW
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
```

- [ ] **Step 4: Build the Docker image to validate**

```bash
cd repos/apps/product-catalog-fe
docker build -t product-catalog-fe:node22-test .
```

Expected: build completes without error. Node.js version in output should show v22.x.

- [ ] **Step 5: Delete the generated test image**

```bash
docker rmi product-catalog-fe:node22-test
```

- [ ] **Step 6: Commit**

```bash
git add repos/apps/product-catalog-fe/Dockerfile repos/apps/product-catalog-fe/package.json repos/apps/product-catalog-fe/server.js
git commit -m "fix: upgrade product-catalog-fe base image Node 14 -> 22-slim, drop body-parser"
```

---

### Task 1.2 — Upgrade product-catalog-api to Python 3.12

**Files:**
- Modify: `repos/apps/product-catalog-api/v1/Dockerfile`
- Modify: `repos/apps/product-catalog-api/v2/Dockerfile`
- Modify: `repos/apps/product-catalog-api/v1/requirements.txt`
- Modify: `repos/apps/product-catalog-api/v2/requirements.txt`

- [ ] **Step 1: Fix the invalid pip version string in v1/requirements.txt**

The `v` prefix in `requests==v2.32.3` is not valid pip syntax.

```
flask-restx==1.3.0
Flask==3.0.3
werkzeug==3.0.4
gunicorn==23.0.0
requests==2.32.3
flask-cors==4.0.2
boto3==1.35.39
markupsafe==2.1.5
```

- [ ] **Step 2: Apply the same fix to v2/requirements.txt**

```
flask-restx==1.3.0
Flask==3.0.3
werkzeug==3.0.4
gunicorn==23.0.0
requests==2.32.3
flask-cors==4.0.2
boto3==1.35.39
markupsafe==2.1.5
```

- [ ] **Step 3: Update v1/Dockerfile base image**

```dockerfile
# repos/apps/product-catalog-api/v1/Dockerfile
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install curl -y \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /app
WORKDIR /app

COPY requirements.txt /app
RUN pip install -r requirements.txt

COPY . /app

EXPOSE 8080
ENTRYPOINT ["/app/bootstrap.sh"]
```

- [ ] **Step 4: Update v2/Dockerfile base image (same change)**

```dockerfile
# repos/apps/product-catalog-api/v2/Dockerfile
FROM python:3.12-slim

RUN apt-get update \
    && apt-get install curl -y \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir /app
WORKDIR /app

COPY requirements.txt /app
RUN pip install -r requirements.txt

COPY . /app

EXPOSE 8080
ENTRYPOINT ["/app/bootstrap.sh"]
```

- [ ] **Step 5: Build v1 to validate dependencies install cleanly under Python 3.12**

```bash
cd repos/apps/product-catalog-api/v1
docker build -t product-catalog-api:v1-py312-test .
```

Expected: build succeeds, no pip errors. If `markupsafe` or `flask-restx` raise compatibility issues, pin to the next working version.

- [ ] **Step 6: Build v2 to validate**

```bash
cd repos/apps/product-catalog-api/v2
docker build -t product-catalog-api:v2-py312-test .
```

Expected: same as above.

- [ ] **Step 7: Clean up test images**

```bash
docker rmi product-catalog-api:v1-py312-test product-catalog-api:v2-py312-test
```

- [ ] **Step 8: Commit**

```bash
git add repos/apps/product-catalog-api/v1/Dockerfile \
        repos/apps/product-catalog-api/v1/requirements.txt \
        repos/apps/product-catalog-api/v2/Dockerfile \
        repos/apps/product-catalog-api/v2/requirements.txt
git commit -m "fix: upgrade product-catalog-api Python 3.9->3.12-slim, fix requests pip version string"
```

---

## Phase 2 — EKS Cluster Version Defaults

**Why:** EKS 1.28 is EOL (November 2024). The template default will create unsupported clusters. The CFN template's AllowedValues block further prevents deploying modern K8s versions.

### Task 2.1 — Update management cluster eksctl config

**Files:**
- Modify: `initial-setup/config/mgmt-cluster-eksctl.yaml`

- [ ] **Step 1: Update the version field**

```yaml
---
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: mgmt
  region: AWS_REGION
  version: "1.31"

iam:
  withOIDC: true

vpc:
  nat:
    gateway: Single

managedNodeGroups:
- name: nodegroup
  privateNetworking: true
  iam:
    attachPolicyARNs:
      - arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
      - arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
      - arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
      - arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore
  desiredCapacity: 3
  instanceType: m5.large
```

- [ ] **Step 2: Verify the YAML is valid**

```bash
yamllint initial-setup/config/mgmt-cluster-eksctl.yaml
# If yamllint is not installed: python3 -c "import yaml; yaml.safe_load(open('initial-setup/config/mgmt-cluster-eksctl.yaml'))" && echo "Valid"
```

Expected: no errors.

---

### Task 2.2 — Update workload cluster template default versions

**Files:**
- Modify: `repos/gitops-system/clusters-config/template/def/eks-cluster.yaml`

- [ ] **Step 1: Update both K8s version fields**

```yaml
---
apiVersion: gitops.k8s.aws/v1beta1
kind: EKSCluster
metadata:
  name: cluster-name
spec:
  parameters:
    region: AWS_REGION
    vpc-name: 'cluster-name-eks-vpc'
    vpc-cidrBlock: '10.20.0.0/16'

    subnet1-public-name: 'public-worker-1'
    subnet1-public-cidrBlock: '10.20.1.0/24'
    subnet1-public-availabilityZone: 'AWS_REGIONa'

    subnet2-public-name: 'public-worker-2'
    subnet2-public-cidrBlock: '10.20.2.0/24'
    subnet2-public-availabilityZone: 'AWS_REGIONb'

    subnet1-private-name: 'private-worker-1'
    subnet1-private-cidrBlock: '10.20.11.0/24'
    subnet1-private-availabilityZone: 'AWS_REGIONa'

    subnet2-private-name: 'private-worker-2'
    subnet2-private-cidrBlock: '10.20.12.0/24'
    subnet2-private-availabilityZone: 'AWS_REGIONb'

    eks-k8s-version: '1.31'
    mng-k8s-version: '1.31'
    workload-type: 'non-gpu'
    workers-size: 2

  compositionRef:
    name: amazon-eks-cluster

  writeConnectionSecretToRef:
    namespace: flux-system
    name: cluster-name-eks-connection
```

---

### Task 2.3 — Update CloudFormation template AllowedValues

**Files:**
- Modify: `initial-setup/auto/cfn.yaml`

- [ ] **Step 1: Find the KubernetesVersion parameter block**

```bash
grep -n "KubernetesVersion\|AllowedValues\|1\.27\|1\.28\|1\.29" initial-setup/auto/cfn.yaml | head -20
```

- [ ] **Step 2: Update AllowedValues and Default**

Find the `KubernetesVersion` parameter and replace the `AllowedValues` and `Default` fields:

```yaml
  KubernetesVersion:
    Description: Kubernetes version
    Type: String
    Default: "1.31"
    AllowedValues:
      - "1.31"
      - "1.30"
      - "1.29"
```

Note: `1.29` is kept in the list temporarily so existing environments can still be referenced. Remove it in a follow-up once all clusters are upgraded.

Also update the Cloud9ImageId default from `ubuntu-18.04-x86_64` to `amazonlinux-2-x86_64` since Ubuntu 18.04 is EOL:

```yaml
  Cloud9ImageId:
    Description: The AMI used to create the Cloud9 environment
    Type: String
    Default: amazonlinux-2-x86_64
    AllowedValues:
      - amazonlinux-2-x86_64
```

- [ ] **Step 3: Commit**

```bash
git add initial-setup/config/mgmt-cluster-eksctl.yaml \
        repos/gitops-system/clusters-config/template/def/eks-cluster.yaml \
        initial-setup/auto/cfn.yaml
git commit -m "fix: update EKS cluster version defaults from 1.28/1.29 to 1.31"
```

---

## Phase 3 — CLI Tool Version References

**Why:** The setup README pins kubectl to 1.24.7 (can't talk to EKS 1.31 clusters), kubeseal to v0.19.4 (must match Sealed Secrets controller chart — tracked separately in Phase 6).

### Task 3.1 — Update tool versions in initial-setup/README.md

**Files:**
- Modify: `initial-setup/README.md`

- [ ] **Step 1: Update kubectl install command**

Find the kubectl install block and replace:

```bash
# OLD
sudo curl --silent --location -o /usr/local/bin/kubectl \
   https://s3.us-west-2.amazonaws.com/amazon-eks/1.24.7/2022-10-31/bin/linux/amd64/kubectl

# NEW — fetches the version matching EKS 1.31
sudo curl --silent --location -o /usr/local/bin/kubectl \
   https://s3.us-west-2.amazonaws.com/amazon-eks/1.31.0/2024-09-12/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
```

- [ ] **Step 2: Update yq install command**

```bash
# OLD
sudo curl --silent --location -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.24.5/yq_linux_amd64

# NEW
sudo curl --silent --location -o /usr/local/bin/yq https://github.com/mikefarah/yq/releases/download/v4.44.3/yq_linux_amd64
sudo chmod +x /usr/local/bin/yq
```

- [ ] **Step 3: Update kubeseal install command** (must match chart version in Phase 6 — Sealed Secrets 2.16.2 ships controller v0.27.0)

```bash
# OLD
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.19.4/kubeseal-0.19.4-linux-amd64.tar.gz
tar xfz kubeseal-0.19.4-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# NEW
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.0/kubeseal-0.27.0-linux-amd64.tar.gz
tar xfz kubeseal-0.27.0-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

- [ ] **Step 4: Update eksctl install (pin to known good version)**

```bash
# OLD
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

# NEW (repo moved from weaveworks to eksctl-io)
curl --silent --location "https://github.com/eksctl-io/eksctl/releases/download/v0.208.0/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

- [ ] **Step 5: Commit**

```bash
git add initial-setup/README.md
git commit -m "fix: update CLI tool versions in setup guide (kubectl 1.31, yq v4.44.3, kubeseal v0.27.0, eksctl v0.208.0)"
```

---

## Phase 4 — Flux API Version Mass Replacement

**Why:** `helm.toolkit.fluxcd.io/v2beta1`, `source.toolkit.fluxcd.io/v1beta2`, and `kustomize.toolkit.fluxcd.io/v1beta2` are deprecated in Flux 2.x. While not yet removed, they must be updated before upgrading FluxCD past the current pinned version. 52 files, 95 occurrences.

**Important:** Do NOT manually edit `repos/gitops-system/clusters/mgmt/flux-system/gotk-components.yaml`. That file is auto-generated by `flux bootstrap`. It will be regenerated correctly when FluxCD is re-bootstrapped.

### Task 4.1 — Mass replace deprecated Flux API versions

**Files:** All 52 files under `repos/` identified by the grep scan in the knowledge base.

- [ ] **Step 1: Run the sed replacement across all YAML files**

On macOS:
```bash
cd /path/to/eks-multi-cluster-gitops

find repos/ -name "*.yaml" \
  -not -path "*/flux-system/gotk-components.yaml" \
  -exec sed -i '' \
    -e 's|helm\.toolkit\.fluxcd\.io/v2beta1|helm.toolkit.fluxcd.io/v2|g' \
    -e 's|source\.toolkit\.fluxcd\.io/v1beta2|source.toolkit.fluxcd.io/v1|g' \
    -e 's|kustomize\.toolkit\.fluxcd\.io/v1beta2|kustomize.toolkit.fluxcd.io/v1|g' \
    {} \;
```

On Linux:
```bash
find repos/ -name "*.yaml" \
  -not -path "*/flux-system/gotk-components.yaml" \
  -exec sed -i \
    -e 's|helm\.toolkit\.fluxcd\.io/v2beta1|helm.toolkit.fluxcd.io/v2|g' \
    -e 's|source\.toolkit\.fluxcd\.io/v1beta2|source.toolkit.fluxcd.io/v1|g' \
    -e 's|kustomize\.toolkit\.fluxcd\.io/v1beta2|kustomize.toolkit.fluxcd.io/v1|g' \
    {} \;
```

- [ ] **Step 2: Verify no deprecated versions remain**

```bash
grep -r "v2beta1\|/v1beta2" repos/ --include="*.yaml" \
  --exclude-path="*/gotk-components.yaml"
```

Expected: **no output**. If any lines appear, re-run the sed command or fix manually.

- [ ] **Step 3: Verify the changed files look correct**

```bash
git diff --stat repos/
```

Expected: ~52 files changed. Spot-check three different file types:
```bash
# A HelmRelease
git diff repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml

# A Kustomization
git diff repos/gitops-system/clusters/mgmt/karpenter.yaml

# A GitRepository/HelmRepository
git diff repos/gitops-system/tools/external-secrets/external-secrets-repository.yaml
```

Confirm only `apiVersion` lines changed — no other content altered.

- [ ] **Step 4: Validate YAML syntax on a sample of changed files**

```bash
for f in \
  repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml \
  repos/gitops-system/clusters/mgmt/karpenter.yaml \
  repos/gitops-system/clusters-config/template/external-secrets.yaml \
  repos/gitops-system/workloads/template/flux-kustomization.yaml \
  repos/gitops-workloads/template/app-template/flux-kustomization.yaml; do
  python3 -c "import yaml; list(yaml.safe_load_all(open('$f'))); print('OK: $f')"
done
```

Expected: each line prints `OK: <path>`.

- [ ] **Step 5: Commit**

```bash
git add repos/
git commit -m "fix: replace deprecated Flux API versions v2beta1/v1beta2 with v2/v1 across 52 manifests"
```

---

## Phase 5 — External Secrets Operator

**Why:** Chart 0.4.4 is 6 major versions behind. The `external-secrets.io/v1alpha1` API was removed in ESO 0.9 — if the chart is upgraded without fixing the API version in the manifests, the ESO controller will ignore the `SecretStore` and `ExternalSecret` resources, breaking the Sealed Secrets key injection pipeline.

**Do both steps below in the same commit.**

### Task 5.1 — Upgrade ESO chart version

**Files:**
- Modify: `repos/gitops-system/tools/external-secrets/external-secrets-release.yaml`

- [ ] **Step 1: Update the chart version**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: external-secrets
  namespace: flux-system
spec:
  releaseName: external-secrets
  targetNamespace: external-secrets
  interval: 5m
  install:
    createNamespace: true
  chart:
    spec:
      chart: external-secrets
      version: '0.10.7'
      sourceRef:
        kind: HelmRepository
        name: external-secrets-repository
        namespace: flux-system
      interval: 1m
```

---

### Task 5.2 — Fix ExternalSecret and SecretStore API version

**Files:**
- Modify: `repos/gitops-system/tools-config/external-secrets/sealed-secrets-key.yaml`

- [ ] **Step 1: Update both resource apiVersions from v1alpha1 to v1beta1**

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: sealed-secrets
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: aws-secrets-manager
  namespace: sealed-secrets
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::${ACCOUNT_ID}:role/external-secrets-role
---
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets-manager
  namespace: sealed-secrets
spec:
  provider:
    aws:
      service: SecretsManager
      region: AWS_REGION
      auth:
        jwt:
          serviceAccountRef:
            name: aws-secrets-manager
---
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: sealed-secrets
  namespace: sealed-secrets
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: SecretStore
  target:
    name: sealed-secrets
    creationPolicy: Owner
    template:
      type: kubernetes.io/tls
      metadata:
        labels:
          sealedsecrets.bitnami.com/sealed-secrets-key: active
  data:
  - secretKey: tls.crt
    remoteRef:
      key: sealed-secrets
      property: crt
  - secretKey: tls.key
    remoteRef:
      key: sealed-secrets
      property: key
```

- [ ] **Step 2: Verify no remaining v1alpha1 ESO resources**

```bash
grep -r "external-secrets.io/v1alpha1" repos/ --include="*.yaml"
```

Expected: no output.

- [ ] **Step 3: Validate YAML**

```bash
python3 -c "import yaml; list(yaml.safe_load_all(open('repos/gitops-system/tools-config/external-secrets/sealed-secrets-key.yaml'))); print('OK')"
python3 -c "import yaml; list(yaml.safe_load_all(open('repos/gitops-system/tools/external-secrets/external-secrets-release.yaml'))); print('OK')"
```

- [ ] **Step 4: Commit (chart upgrade + API fix together)**

```bash
git add repos/gitops-system/tools/external-secrets/external-secrets-release.yaml \
        repos/gitops-system/tools-config/external-secrets/sealed-secrets-key.yaml
git commit -m "fix: upgrade External Secrets Operator 0.4.4->0.10.7, fix v1alpha1->v1beta1 API"
```

---

## Phase 6 — Sealed Secrets

**Why:** Chart 2.7.1 (controller v0.19.5) is 8 versions behind 2.16.x (controller v0.27.x). The kubeseal CLI in the setup guide was already updated in Phase 3 to match v0.27.0. This phase upgrades the controller chart to match.

**Warning:** The kubeseal CLI version and the Sealed Secrets controller chart version MUST match. Phase 3 and Phase 6 must both be applied before any new secrets are sealed.

### Task 6.1 — Upgrade Sealed Secrets chart

**Files:**
- Modify: `repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml`

- [ ] **Step 1: Update the chart version**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: sealed-secrets
  namespace: flux-system
spec:
  releaseName: sealed-secrets
  targetNamespace: sealed-secrets
  interval: 5m
  install:
    createNamespace: true
  chart:
    spec:
      chart: sealed-secrets
      version: '2.16.2'
      sourceRef:
        kind: HelmRepository
        name: sealed-secrets-repository
        namespace: flux-system
      interval: 1m
```

- [ ] **Step 2: Verify no version mismatch between README and chart**

```bash
grep -n "kubeseal\|0.27\|0.19\|2.7\|2.16" initial-setup/README.md repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml
```

Expected: README shows `v0.27.0`, chart shows `2.16.2`. No `0.19` or `2.7` should appear.

- [ ] **Step 3: Commit**

```bash
git add repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml
git commit -m "fix: upgrade Sealed Secrets chart 2.7.1->2.16.2 (controller v0.27.0, matches kubeseal CLI)"
```

---

## Phase 7 — AWS Toolchain Helm Charts

**Why:** AWS LB Controller 1.4.6 (controller v2.4.x) is 7 minor versions behind v2.12.x. EBS CSI 2.30.0 is minor lag. Kubecost 2.2.2 is minor lag. These are low-risk version bumps with no breaking changes in the patch/minor range.

### Task 7.1 — Upgrade AWS Load Balancer Controller

**Files:**
- Modify: `repos/gitops-system/tools/aws-load-balancer-controller/aws-lb-controller-release.yaml`

- [ ] **Step 1: Update chart version**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: aws-load-balancer-controller
  namespace: flux-system
spec:
  releaseName: aws-load-balancer-controller
  targetNamespace: kube-system
  interval: 5m
  chart:
    spec:
      chart: aws-load-balancer-controller
      version: '1.11.0'
      sourceRef:
        kind: HelmRepository
        name: aws-load-balancer-controller-repository
        namespace: flux-system
      interval: 1m
  values:
    serviceAccount:
      create: false
      name: aws-load-balancer-controller
```

---

### Task 7.2 — Upgrade AWS EBS CSI Driver

**Files:**
- Modify: `repos/gitops-system/tools/aws-ebs-csi/aws-ebs-csi-release.yaml`

- [ ] **Step 1: Update chart version**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: aws-ebs-csi
  namespace: flux-system
spec:
  releaseName: aws-ebs-csi-driver
  targetNamespace: kube-system
  interval: 5m
  chart:
    spec:
      chart: aws-ebs-csi-driver
      version: '2.38.1'
      sourceRef:
        kind: HelmRepository
        name: aws-ebs-csi-repository
        namespace: flux-system
      interval: 1m
  values:
    controller:
      serviceAccount:
        create: false
        name: ebs-csi-controller-sa
```

---

### Task 7.3 — Upgrade Kubecost

**Files:**
- Modify: `repos/gitops-system/tools/kubecost/kubecost-release.yaml`

- [ ] **Step 1: Update chart version**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: kubecost
  namespace: flux-system
spec:
  releaseName: kubecost
  targetNamespace: kubecost
  interval: 5m
  install:
    createNamespace: true
  chart:
    spec:
      chart: cost-analyzer
      version: '2.6.0'
      sourceRef:
        kind: HelmRepository
        name: kubecost-repository
        namespace: flux-system
      interval: 1m
  values:
    kubecostFrontend:
      image: public.ecr.aws/kubecost/frontend
    kubecostModel:
      image: public.ecr.aws/kubecost/cost-model
    forecasting:
      fullImageName: public.ecr.aws/kubecost/kubecost-modeling:v0.1.6
    networkCosts:
      image:
        repository: public.ecr.aws/kubecost/kubecost-network-costs
    clusterController:
      image:
        repository: public.ecr.aws/kubecost/cluster-controller
    prometheus:
      server:
        image:
          repository: public.ecr.aws/kubecost/prometheus
      configmapReload:
        prometheus:
          image:
            repository: public.ecr.aws/kubecost/prometheus-config-reloader
    reporting:
      productAnalytics: false
```

- [ ] **Step 2: Commit all three chart upgrades**

```bash
git add repos/gitops-system/tools/aws-load-balancer-controller/aws-lb-controller-release.yaml \
        repos/gitops-system/tools/aws-ebs-csi/aws-ebs-csi-release.yaml \
        repos/gitops-system/tools/kubecost/kubecost-release.yaml
git commit -m "fix: upgrade AWS LB Controller 1.4.6->1.11.0, EBS CSI 2.30.0->2.38.1, Kubecost 2.2.2->2.6.0"
```

---

## Phase 8 — Karpenter v0.36 → v1.x Migration

**Why:** Karpenter v1.0 (released 2024) breaks all `v1beta1` API resources. Chart 0.36.1 cannot run alongside current EKS 1.31 without compatibility issues. Amazon Linux 2 (amiFamily: AL2) also reaches EOL June 2025. This phase handles the chart, the API versions, and the amiFamily in one coordinated change.

**Note on inline patches in karpenter-config.yaml:** These files use `karpenter.k8s.aws/v1beta1` in the target group/version selectors and in the inline YAML patches. All occurrences must be updated.

### Task 8.1 — Upgrade Karpenter chart

**Files:**
- Modify: `repos/gitops-system/tools/karpenter/karpenter-release.yaml`

- [ ] **Step 1: Update chart version**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: karpenter
  namespace: flux-system
spec:
  releaseName: karpenter
  targetNamespace: kube-system
  interval: 5m
  chart:
    spec:
      chart: karpenter
      version: '1.3.1'
      sourceRef:
        kind: HelmRepository
        name: karpenter-repository
        namespace: flux-system
      interval: 1m
  values:
    logLevel: debug
    settings:
      clusterName: ${CLUSTER_NAME}
    controller:
      resources:
        requests:
          cpu: 1
          memory: 1Gi
        limits:
          cpu: 1
          memory: 1Gi
    serviceAccount:
      create: false
      name: karpenter-sa
```

---

### Task 8.2 — Migrate NodePool and EC2NodeClass to v1 APIs, and AL2 → AL2023

**Files:**
- Modify: `repos/gitops-system/tools-config/karpenter-config/node-pool.yaml`

- [ ] **Step 1: Update both resource API versions and amiFamily**

```yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
        - key: kubernetes.io/os
          operator: In
          values: ["linux"]
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["on-demand"]
        - key: karpenter.k8s.aws/instance-category
          operator: In
          values: ["c", "m", "r"]
        - key: karpenter.k8s.aws/instance-generation
          operator: Gt
          values: ["2"]
      nodeClassRef:
        apiVersion: karpenter.k8s.aws/v1
        kind: EC2NodeClass
        name: default
  limits:
    cpu: 1000
  disruption:
    consolidationPolicy: WhenUnderutilized
    expireAfter: 720h
---
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
metadata:
  name: default
spec:
  amiFamily: AL2023
  role: karpenter-node-role
  subnetSelectorTerms:
    - tags:
        Name: "eks-vpc-private*"
  securityGroupSelectorTerms:
    - tags:
        kubernetes.io/cluster/${CLUSTER_NAME}: owned
```

---

### Task 8.3 — Update management cluster karpenter-config inline patches

**Files:**
- Modify: `repos/gitops-system/clusters/mgmt/karpenter-config.yaml`

- [ ] **Step 1: Update the EC2NodeClass group/version in the patch target and inline YAML**

```yaml
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: karpenter-config
  namespace: flux-system
spec:
  prune: true
  interval: 2m0s
  path: ./tools-config/karpenter-config
  sourceRef:
    kind: GitRepository
    name: flux-system
  postBuild:
    substituteFrom:
      - kind: ConfigMap
        name: cluster-info
        optional: false
  dependsOn:
  - name: karpenter
  patches:
  - target:
      group: karpenter.k8s.aws
      version: v1
      kind: EC2NodeClass
      name: default
    patch: |-
      apiVersion: karpenter.k8s.aws/v1
      kind: EC2NodeClass
      metadata:
        name: not-used
      spec:
        subnetSelectorTerms:
          - tags:
              Name: "mgmtPrivate*"
---
```

---

### Task 8.4 — Update workload cluster template karpenter-config inline patches

**Files:**
- Modify: `repos/gitops-system/clusters/template/karpenter-config.yaml`

- [ ] **Step 1: Replace all v1beta1 references with v1**

Open `repos/gitops-system/clusters/template/karpenter-config.yaml` and make these replacements:

```bash
sed -i '' \
  -e 's|karpenter\.k8s\.aws/v1beta1|karpenter.k8s.aws/v1|g' \
  -e 's|karpenter\.sh/v1beta1|karpenter.sh/v1|g' \
  repos/gitops-system/clusters/template/karpenter-config.yaml
```

- [ ] **Step 2: Verify result**

```bash
grep "v1beta1" repos/gitops-system/clusters/template/karpenter-config.yaml
```

Expected: no output.

- [ ] **Step 3: Validate all four changed files**

```bash
for f in \
  repos/gitops-system/tools/karpenter/karpenter-release.yaml \
  repos/gitops-system/tools-config/karpenter-config/node-pool.yaml \
  repos/gitops-system/clusters/mgmt/karpenter-config.yaml \
  repos/gitops-system/clusters/template/karpenter-config.yaml; do
  python3 -c "import yaml; list(yaml.safe_load_all(open('$f'))); print('OK: $f')"
done
```

- [ ] **Step 4: Commit**

```bash
git add repos/gitops-system/tools/karpenter/karpenter-release.yaml \
        repos/gitops-system/tools-config/karpenter-config/node-pool.yaml \
        repos/gitops-system/clusters/mgmt/karpenter-config.yaml \
        repos/gitops-system/clusters/template/karpenter-config.yaml
git commit -m "fix: Karpenter 0.36.1->1.3.1, migrate v1beta1->v1 APIs, AL2->AL2023 amiFamily"
```

---

## Phase 9 — Crossplane Core Modernization

**Why:** Crossplane Core 1.15.0 is 4 minor versions behind 1.19.x. `ControllerConfig` is removed in 1.17+ — upgrading the core chart without removing it first will cause the provider install to fail. The kubectl image in the k8s-provider-config Job is Kubernetes 1.22 (EOL 2022-10-28).

**Order matters:** Update ControllerConfig first (Tasks 9.1, 9.2), then bump the core chart (Task 9.3).

### Task 9.1 — Migrate Crossplane AWS Provider off ControllerConfig

**Files:**
- Modify: `repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml`

- [ ] **Step 1: Replace ControllerConfig with DeploymentRuntimeConfig**

```yaml
---
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
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-aws
spec:
  package: "xpkg.upbound.io/crossplane-contrib/provider-aws:v0.47.1"
  runtimeConfigRef:
    name: aws-config
```

Note: `controllerConfigRef` is replaced by `runtimeConfigRef`. The `runAsUser: 0` and `--debug` args are intentionally dropped — running as root in a container is a security concern, and debug logging in production adds noise.

---

### Task 9.2 — Migrate Crossplane Kubernetes Provider off ControllerConfig, upgrade version

**Files:**
- Modify: `repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml`

- [ ] **Step 1: Replace ControllerConfig with DeploymentRuntimeConfig and bump provider version**

```yaml
---
apiVersion: pkg.crossplane.io/v1beta1
kind: DeploymentRuntimeConfig
metadata:
  name: k8s-config
spec:
  deploymentTemplate:
    spec:
      selector: {}
      template:
        spec:
          securityContext:
            fsGroup: 2000
---
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-kubernetes
spec:
  package: "xpkg.upbound.io/crossplane-contrib/provider-kubernetes:v0.16.0"
  runtimeConfigRef:
    name: k8s-config
```

---

### Task 9.3 — Update stale kubectl image in k8s-provider-config Job

**Files:**
- Modify: `repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml`

- [ ] **Step 1: Replace bitnami/kubectl:1.22.11 with 1.31 in both the Job and CronJob**

```bash
sed -i '' \
  's|bitnami/kubectl:1\.22\.11|bitnami/kubectl:1.31|g' \
  repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml
```

- [ ] **Step 2: Verify the replacement**

```bash
grep "bitnami/kubectl" repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml
```

Expected: `bitnami/kubectl:1.31` appears twice (once in Job, once in CronJob).

---

### Task 9.4 — Upgrade Crossplane Core chart

**Files:**
- Modify: `repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml`

- [ ] **Step 1: Update the chart version**

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: crossplane-core
  namespace: flux-system
spec:
  releaseName: crossplane-core
  interval: 5m
  chart:
    spec:
      chart: crossplane
      version: '1.19.2'
      sourceRef:
        kind: HelmRepository
        name: crossplane-repository
        namespace: crossplane-system
      interval: 1m
```

- [ ] **Step 2: Verify no remaining ControllerConfig references**

```bash
grep -r "ControllerConfig\|controllerConfigRef\|pkg.crossplane.io/v1alpha1" repos/ --include="*.yaml"
```

Expected: no output.

- [ ] **Step 3: Validate all four changed files**

```bash
for f in \
  repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml \
  repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml \
  repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml \
  repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml; do
  python3 -c "import yaml; list(yaml.safe_load_all(open('$f'))); print('OK: $f')"
done
```

- [ ] **Step 4: Commit**

```bash
git add repos/gitops-system/tools/crossplane/crossplane-aws-provider/aws-provider.yaml \
        repos/gitops-system/tools/crossplane/crossplane-k8s-provider/k8s-provider.yaml \
        repos/gitops-system/tools/crossplane/crossplane-k8s-provider-config/k8s-providerconfig.yaml \
        repos/gitops-system/tools/crossplane/crossplane-core/crossplane-release.yaml
git commit -m "fix: Crossplane core 1.15.0->1.19.2, ControllerConfig->DeploymentRuntimeConfig, provider-k8s v0.13->v0.16, kubectl image 1.22->1.31"
```

---

## Post-Plan: Update knowledge base and docs

- [ ] **Step 1: Update docs/knowledge-base.md to reflect applied changes**

Update all "Pinned version" cells in the Stack Summary table to reflect the new versions. Mark resolved items in the Upgrade Priority Matrix.

```bash
git add docs/knowledge-base.md
git commit -m "docs: update knowledge base to reflect completed modernization phases 1-9"
```

---

## What Remains (Future Projects)

### FP-1: crossplane-contrib/provider-aws → Upbound family providers
**Scope:** The monolithic archived provider must be replaced with the Upbound official family providers (`provider-aws-ec2`, `provider-aws-eks`, `provider-aws-iam`). Every resource in `tools-config/crossplane-eks-composition/composition.yaml` changes API group from `*.aws.crossplane.io` to `*.aws.upbound.io`. The app-level DynamoDB resource in `repos/apps-manifests/product-catalog-api-manifests/v2-staging/kubernetes/overlays/staging/infra.yaml` (`dynamodb.aws.crossplane.io/v1alpha1`) is also affected. This involves rewriting 50+ managed resource definitions and migrating any existing cluster state without destroying live infrastructure. Treat as a separate project.

### FP-2: FluxCD version upgrade (gotk-components.yaml regeneration)
**Scope:** `gotk-components.yaml` is pinned at FluxCD v2.1.2 and must NOT be manually edited. To upgrade it, re-run `flux bootstrap` against the gitops-system repo with a newer Flux CLI. This requires live cluster access and should be performed as a live operation after Phases 1–9 are deployed and stable.

### FP-3: Crossplane Composition — OIDC thumbprint
**Scope:** The hardcoded thumbprint `9e99a48a9960b14926bb7f3b02e22da2b0ab7280` in `composition.yaml` is no longer required by AWS but the field is still mandatory in the API. Replace with a neutral value or automate thumbprint fetching during cluster provisioning.

---

*Plan generated: 2026-04-27. Verify all "current" versions before executing — package ecosystems move fast.*
