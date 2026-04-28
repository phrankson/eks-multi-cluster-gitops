# How to Recreate the Management Cluster

This guide covers rebuilding the management cluster after it has been deleted. It is shorter than the initial setup because most one-time work survives cluster deletion:

| Survives deletion | Must be redone |
|---|---|
| GitHub repos (`gitops-system`, `gitops-workloads`) and their content | EKS cluster |
| Sealed Secrets keypair in AWS Secrets Manager | kubeconfig entry |
| Git credentials as SealedSecrets (committed to Git) | `cluster-info` ConfigMap (new OIDC URL) |
| SSH keys in `~/.ssh/` | `crossplane-role` trust policy (new OIDC URL) |
| GitHub SSH deploy keys | `flux-system` namespace |
| `$GITOPS_HOME` directory structure | Flux bootstrap |
| Crossplane-managed IAM roles in AWS* | `karpenter-node-role` manual apply |

> *Crossplane-managed IAM roles (`karpenter-role`, `karpenter-node-role`, `eks-cluster-role`, `eks-nodegroup-role`) may still exist in AWS after cluster deletion. Crossplane on the new cluster will detect and adopt them automatically.

---

## Before you start

Confirm the following are still in place. If any are missing, refer to [GETTING-STARTED.md](GETTING-STARTED.md) for the original creation steps.

```bash
# Sealed Secrets keypair is in Secrets Manager
aws secretsmanager get-secret-value --secret-id sealed-secrets --query 'Name' 2>&1

# Your working directory exists
ls $GITOPS_HOME/gitops-system
ls $GITOPS_HOME/gitops-workloads

# The keypair PEM is available (needed if you re-seal any secrets)
ls $GITOPS_HOME/sealed-secrets-keypair-public.pem
```

---

## Step 1 — Set environment variables

Open a fresh terminal and export everything needed for the steps below. Do not proceed until all values are confirmed.

```bash
unset GITOPS_HOME && export GITOPS_HOME=$(pwd)  # run from your working directory

export ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=<your-region>          # e.g. eu-central-1
export GITHUB_ACCOUNT=<your-github-username>
export GITHUB_TOKEN=<your-personal-access-token>
export EKS_CONSOLE_IAM_ENTITY_ARN=<your-iam-user-or-role-arn>
export REPO_PREFIX="ssh:\/\/git@github.com\/$GITHUB_ACCOUNT"

echo "Account : $ACCOUNT_ID"
echo "Region  : $AWS_REGION"
echo "GitOps  : $GITOPS_HOME"
```

---

## Step 2 — Create the EKS cluster

```bash
cd $GITOPS_HOME
cp eks-multi-cluster-gitops/initial-setup/config/mgmt-cluster-eksctl.yaml .

# macOS
sed -i '' "s/AWS_REGION/$AWS_REGION/g" mgmt-cluster-eksctl.yaml
# Linux
# sed -i "s/AWS_REGION/$AWS_REGION/g" mgmt-cluster-eksctl.yaml

eksctl create cluster -f mgmt-cluster-eksctl.yaml
```

This takes 15–20 minutes. Wait for it to finish before continuing.

---

## Step 3 — Point kubectl at the new cluster and get the OIDC URL

Every EKS cluster gets a unique OIDC provider ID. The new cluster's URL will be different from the deleted cluster's. You must capture it now — it is used in the next two steps.

```bash
aws eks wait cluster-active --name mgmt && echo "Cluster ready"

aws eks update-kubeconfig --name mgmt --region $AWS_REGION

kubectl get nodes   # confirm 3 nodes in Ready state
```

```bash
export CLUSTER_ARN=$(aws eks describe-cluster --name mgmt --region $AWS_REGION \
  --query 'cluster.arn' --output text)
export CLUSTER_NAME=mgmt
export CLUSTER_NAME_PSUEDO=mgmt
export OIDC_PROVIDER=$(aws eks describe-cluster --name mgmt --region $AWS_REGION \
  --query 'cluster.identity.oidc.issuer' --output text | sed 's|https://||')

echo "CLUSTER_ARN   : $CLUSTER_ARN"
echo "OIDC_PROVIDER : $OIDC_PROVIDER"
```

> **Do not skip the OIDC step.** Without it, the `crossplane-role` trust policy and the Karpenter IAM role trust policy will contain an empty condition, causing `AccessDenied` on every AWS API call from inside the cluster.

---

## Step 4 — Update the `crossplane-role` trust policy

The `crossplane-role` was created manually during initial setup. Its trust policy pins the old cluster's OIDC URL. Update it to the new cluster's OIDC URL now, before Flux bootstrap.

```bash
cd $GITOPS_HOME

# Check if the role already exists
aws iam get-role --role-name crossplane-role 2>&1 | grep RoleName
```

**If the role exists** — update its trust policy:

```bash
envsubst \
  < eks-multi-cluster-gitops/initial-setup/config/crossplane-role-trust-policy-template.json \
  > crossplane-role-trust-policy.json

aws iam update-assume-role-policy \
  --role-name crossplane-role \
  --policy-document file://crossplane-role-trust-policy.json

echo "Trust policy updated"
```

**If the role does not exist** — create it from scratch (same as initial setup):

```bash
envsubst \
  < eks-multi-cluster-gitops/initial-setup/config/crossplane-role-trust-policy-template.json \
  > crossplane-role-trust-policy.json

CROSSPLANE_IAM_ROLE_ARN=$(aws iam create-role \
  --role-name crossplane-role \
  --assume-role-policy-document file://crossplane-role-trust-policy.json \
  --output text \
  --query "Role.Arn")
echo "Created: $CROSSPLANE_IAM_ROLE_ARN"

envsubst \
  < eks-multi-cluster-gitops/initial-setup/config/crossplane-role-permission-policy-template.json \
  > crossplane-role-permission-policy.json

CROSSPLANE_IAM_POLICY_ARN=$(aws iam create-policy \
  --policy-name crossplane-policy \
  --policy-document file://crossplane-role-permission-policy.json \
  --output text \
  --query "Policy.Arn")

aws iam attach-role-policy \
  --role-name crossplane-role \
  --policy-arn ${CROSSPLANE_IAM_POLICY_ARN}
```

---

## Step 5 — Create the `flux-system` namespace and `cluster-info` ConfigMap

```bash
kubectl create ns flux-system

kubectl create configmap cluster-info -n flux-system \
  --from-literal=AWS_REGION=${AWS_REGION} \
  --from-literal=ACCOUNT_ID=${ACCOUNT_ID} \
  --from-literal=CLUSTER_ARN=${CLUSTER_ARN} \
  --from-literal=CLUSTER_NAME=${CLUSTER_NAME} \
  --from-literal=CLUSTER_NAME_PSUEDO=${CLUSTER_NAME} \
  --from-literal=OIDC_PROVIDER=${OIDC_PROVIDER}
```

Verify it:
```bash
kubectl get configmap cluster-info -n flux-system -o yaml
```

---

## Step 6 — Register Karpenter node role in aws-auth

```bash
eksctl create iamidentitymapping \
  --cluster mgmt \
  --region=${AWS_REGION} \
  --arn arn:aws:iam::${ACCOUNT_ID}:role/karpenter-node-role \
  --username system:node:{{EC2PrivateDNSName}} \
  --group system:bootstrappers,system:nodes \
  --no-duplicate-arns
```

> The IAM role itself may not exist in AWS yet — that is fine. Registering the name now prevents a race condition when Karpenter starts launching nodes.

---

## Step 7 — Bootstrap Flux

```bash
export CLUSTER_NAME=mgmt

flux bootstrap github \
  --components-extra=image-reflector-controller,image-automation-controller \
  --owner=$GITHUB_ACCOUNT \
  --namespace=flux-system \
  --repository=gitops-system \
  --branch=main \
  --path=clusters/$CLUSTER_NAME \
  --personal
```

Flux will push commits to `gitops-system` and begin reconciling. Watch progress:

```bash
watch -n 30 flux get kustomizations
```

---

## Step 8 — Apply `karpenter-node-role` to break the bootstrap race condition

This step is **always required** — it is not optional troubleshooting.

Wait until the Crossplane AWS provider is healthy (takes 3–5 minutes after bootstrap):

```bash
until kubectl get provider.pkg.crossplane.io provider-aws \
  -o jsonpath='{.status.conditions[?(@.type=="Healthy")].status}' 2>/dev/null | grep -q True; do
  echo "Waiting for provider-aws..."; sleep 15
done
echo "provider-aws is healthy"
```

Then apply the role:

```bash
kubectl apply -f $GITOPS_HOME/gitops-system/tools-config/karpenter-config/role.yaml
```

Wait for Crossplane to sync it to AWS:

```bash
until kubectl get role.iam.aws.crossplane.io karpenter-node-role \
  -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -q True; do
  echo "Waiting for karpenter-node-role..."; sleep 10
done
echo "karpenter-node-role is ready"
```

Force Flux to retry immediately:

```bash
flux reconcile kustomization karpenter-config
```

---

## Step 9 — Grant EKS console access (optional)

```bash
cd $GITOPS_HOME
kubectl apply -f gitops-system/tools-config/eks-console/role.yaml
kubectl apply -f gitops-system/tools-config/eks-console/role-binding.yaml

eksctl create iamidentitymapping \
  --cluster mgmt \
  --region=${AWS_REGION} \
  --arn ${EKS_CONSOLE_IAM_ENTITY_ARN} \
  --username ${EKS_CONSOLE_IAM_ENTITY_ARN} \
  --no-duplicate-arns
```

---

## Step 10 — Verify all kustomizations are ready

```bash
flux get kustomizations
```

Expected — all rows `READY=True`:

```
NAME                             READY
clusters-config                  True
crossplane                       True
crossplane-aws-provider          True
crossplane-aws-provider-config   True
crossplane-core                  True
crossplane-eks-composition       True
crossplane-k8s-provider          True
crossplane-k8s-provider-config   True
flux-system                      True
karpenter                        True
karpenter-config                 True
karpenter-iam                    True
```

If any kustomization shows a stale dependency error after its dependency is already green, force-reconcile it:

```bash
flux reconcile kustomization <name>
```

---

## Step 11 — Final health check

```bash
# Crossplane providers healthy
kubectl get provider.pkg.crossplane.io

# Karpenter running
kubectl get pods -n kube-system -l app.kubernetes.io/name=karpenter

# Karpenter NodePool and EC2NodeClass ready
kubectl get nodepool
kubectl get ec2nodeclass

# Crossplane IAM roles provisioned in AWS
kubectl get role.iam.aws.crossplane.io -A

# Sealed Secrets controller running
kubectl get pods -n sealed-secrets
```

The management cluster is ready. Workload clusters will be provisioned automatically by Crossplane as they are added to `gitops-system/clusters-config/`.
