# Initial Setup

One-time setup of the management cluster: create it by hand with `eksctl`, bootstrap Flux
onto it, and everything downstream is GitOps from there.

**Follow [GETTING-STARTED.md](GETTING-STARTED.md)** for the full walkthrough — it covers every
step below with explanations of *why* each one exists, not just the commands.

## Quick reference

### AWS account quotas

Each workload cluster needs: 1 VPC (with an Internet Gateway), 2 public subnets, 2 private
subnets, 2 NAT Gateways, 2 Elastic IPs. Check your account's Service Quotas before provisioning
multiple clusters — the default NAT Gateway limit is often 5 per region.

### AWS credentials

Your local AWS credentials need broad permissions for this one-time setup: EKS, IAM, EC2,
Secrets Manager, S3 (`AdministratorAccess` is the practical minimum for a first run).

```bash
aws sts get-caller-identity
```

### Required tools

`kubectl` (pinned to EKS 1.35.x), `flux`, `kubeseal` (v0.38.4, matching the Sealed Secrets
chart pinned in `repos/gitops-system/tools/sealed-secrets/sealed-secrets-release.yaml`), `gh`,
`eksctl`, `yq`, `envsubst`. Install instructions and version-pinning notes for each are in
[GETTING-STARTED.md](GETTING-STARTED.md#install-tools).

### What you end up with

A running EKS management cluster that manages itself and can provision new workload clusters
entirely through Git commits — no manual `eksctl create cluster` beyond this one, no SSH into
anything. [GETTING-STARTED.md](GETTING-STARTED.md) explains the hub/spoke model and each
component's role before walking through creating it.

### After bootstrap

Once the management cluster is bootstrapped and healthy, see
[`scenarios.md`](../scenarios.md) for day-2 operations: provisioning a workload cluster,
onboarding an application, upgrading, deleting.

### Need to rebuild the management cluster later?

Most of this guide does not need to be repeated — the Git repos, Secrets Manager keypair, and
IAM roles all survive a cluster deletion. See the rebuild note at the end of
[GETTING-STARTED.md](GETTING-STARTED.md#final-health-check).
