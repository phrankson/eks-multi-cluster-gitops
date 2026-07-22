# Multi-cluster GitOps Scripts

Note: most of these scripts operate on local repos only and do not commit changes or
push to remotes — commits and pushes must be done separately. The exception is
`remove-workload-cluster.sh`, which does commit and push both repos as part of its
teardown flow (see below).

## Workload cluster management

### add-workload-cluster.sh

Usage:
```
add-workload-cluster.sh <gitops-system-path> <cluster-name> [gitops-workloads-path]
```

Adds a new workload cluster to the `gitops-system` repository by:
1. Copying `clusters-config/template` → `clusters-config/<cluster-name>`
2. Copying `clusters/template` → `clusters/<cluster-name>`
3. Copying `workloads/template` → `workloads/<cluster-name>`
4. Replacing the `cluster-name` placeholder in all copied files
5. Registering the cluster in `clusters-config/kustomization.yaml`
6. Creating a `<cluster-name>/` directory in `gitops-workloads` (if a path is provided)

After running, commit and push both repos for Flux to provision the cluster.

### remove-workload-cluster.sh

Usage:
```
remove-workload-cluster.sh <gitops-system-path> <gitops-workloads-path> <cluster-name>
```

Full deprovisioning workflow — this one **does** commit and push, and talks to a live
cluster:
1. Validates inputs and checks the cluster exists
2. Removes the cluster from `clusters-config/kustomization.yaml`
3. Deletes cluster directories from `gitops-system` and `gitops-workloads`
4. Commits and pushes both repos
5. Forces Flux reconciliation to trigger pruning
6. Monitors Crossplane resource deletion
7. Removes stuck finalizers (Kubernetes Provider Objects targeting the deleted cluster)
8. Cleans up the local kubeconfig context

Requires `kubectl`, `flux`, `yq`, `git`, and the `aws` CLI.

## Application management

### add-cluster-app.sh

Usage:
```
add-cluster-app.sh
  <gitops_workloads_path>
  <cluster_name> <app-name>
  <public_key_pem>
  <git_creds_template_path>
  <git_private_key_file> <git_public_key_file> <git_known_hosts>
  <sealed_secrets_public_pem_file>
```

Adds the application `app-name` to the cluster `cluster-name`, using the following steps:
- creates a new folder for the app under the correct workloads cluster folder and copies the app template
- updates the folder content with the correct cluster name and app name
- creates a sealed secret `gitops-secret.yaml` using the supplied template, keys, and known_hosts string
- updates `kustomization.yaml` in the workloads cluster folder.

It is assumed that a repo called `app-name-manifests` exists.

### remove-cluster-app.sh

```
remove-cluster-app.sh <gitops_workloads_path> <cluster_name> <app-name>
```

Removes the application from `kustomization.yaml` and deletes the application folder from the workloads cluster folder.

### add-app-cluster-overlay

Usage:
```
add-app-cluster-overlay <app_manifests_path> cluster_name 
```


## Example sequence

Create a `commercial-staging` cluster:
```
add-workload-cluster.sh ./gitops-system commercial-staging ./gitops-workloads
```

Commit and push:
```
cd gitops-system
git add .
git commit -m "Added cluster"
git push
```

Create an application manifests repo:
```
cd ~/environment
gh repo create --private --clone product-catalog-fe-manifests
cp -r multi-cluster-gitops/repos/apps-manifests/product-catalog-fe-manifests/* product-catalog-fe-manifests/
cd product-catalog-fe-manifests
git add .
git commit -m "baseline version"
git branch -M main
git push --set-upstream origin main
```

Add the app `product-catalog-fe` to the `commercial-staging` cluster:
```
add-cluster-app.sh \
  ./gitops-workloads \
  commercial-staging product-catalog-fe \
  multi-cluster-gitops/initial-setup/secrets-template/git-credentials.yaml \
  ~/.ssh/gitops ~/.ssh/gitops.pub \
  "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" \
  ./sealed-secrets-keypair-public.pem
```

Commit and push:
```
cd gitops-workloads
git add .
git commit -m "Added pc-fe to staging"
git push
```
