## Create and prepare the Git repositories

### Verify (or set up) local SSH access to GitHub

First, check whether you already have an SSH key configured for GitHub:
```bash
ssh -T git@github.com
```
If you see `Hi <username>! You've successfully authenticated` — you're done, skip to the next section.

If not, create an SSH key now:
```bash
cd ~/.ssh
ssh-keygen -t ed25519 -C "$EMAIL" -f gitops-local
```
Replace `$EMAIL` with the email associated with your GitHub account. This generates `gitops-local` (private) and `gitops-local.pub` (public).

Add it to `~/.ssh/config`:
```bash
cat << EOF >> ~/.ssh/config
Host github.com
  AddKeysToAgent yes
  IdentityFile ~/.ssh/gitops-local
EOF
```

Then log in with the GitHub CLI:
```bash
gh auth login -p ssh -h github.com
```
- When prompted to upload an SSH public key, select `~/.ssh/gitops-local.pub` and title it `gitops-local`.
- Choose **Login with a web browser** and complete the auth flow.
- Run `gh auth status` to confirm you are logged in.

### Create SSH key for Flux access to GitHub

Flux needs its own SSH key to pull from your repos at runtime. This is separate from your personal key — it is a deploy key that Flux uses inside the cluster. Do **not** set a passphrase; Flux cannot use password-protected keys.

> **Note:** For simplicity this walkthrough uses one SSH key for all repos. The architecture supports per-repo keys if needed.

First check whether you already have a `gitops` key:
```bash
ls ~/.ssh/gitops ~/.ssh/gitops.pub 2>/dev/null && echo "key exists" || echo "key missing"
```

If missing, create it:
```bash
cd ~/.ssh
ssh-keygen -t ed25519 -C "gitops@example.com" -f gitops
```

Upload the public key to your GitHub account:
```bash
gh ssh-key add -t gitops ~/.ssh/gitops.pub
```

Verify the key was added:
```bash
gh ssh-key list
```

### Create GitHub repos

Create empty private repos and clone them into your working directory:
```bash
cd $GITOPS_HOME
git config --global init.defaultBranch main
gh repo create --private --clone gitops-system
gh repo create --private --clone gitops-workloads
```

### Set the `REPO_PREFIX` variable

1. Set your GitHub username:
   ```bash
   GITHUB_ACCOUNT=<your-github-username>
   ```

2. Export `REPO_PREFIX`:
   ```bash
   export REPO_PREFIX="ssh:\/\/git@github.com\/$GITHUB_ACCOUNT"
   ```

### Create a `Secret` resource containing Git credentials for `gitops-system`

1. Copy the credentials template to your working directory:
   ```bash
   cd $GITOPS_HOME
   cp eks-multi-cluster-gitops/initial-setup/secrets-template/git-credentials.yaml git-creds-system.yaml
   ```

2. Inject the private key (base64-encoded):
   ```bash
   # macOS
   KEY=$(base64 -i ~/.ssh/gitops) yq -i '.data.identity = strenv(KEY)' git-creds-system.yaml
   # Linux
   # KEY=$(cat ~/.ssh/gitops | base64 -w 0) yq -i '.data.identity = strenv(KEY)' git-creds-system.yaml
   ```

3. Inject the public key (base64-encoded):
   ```bash
   # macOS
   KEY=$(base64 -i ~/.ssh/gitops.pub) yq -i '.data."identity.pub" = strenv(KEY)' git-creds-system.yaml
   # Linux
   # KEY=$(cat ~/.ssh/gitops.pub | base64 -w 0) yq -i '.data."identity.pub" = strenv(KEY)' git-creds-system.yaml
   ```

4. Inject the GitHub known-hosts entry (base64-encoded):
   ```bash
   # macOS
   HOST=$(echo "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" | base64) yq -i '.data.known_hosts = strenv(HOST)' git-creds-system.yaml
   # Linux
   # HOST=$(echo "github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=" | base64 -w 0) yq -i '.data.known_hosts = strenv(HOST)' git-creds-system.yaml
   ```

When done, continue with the setup process [here](../../README.md#populate-and-update-the-repositories)
