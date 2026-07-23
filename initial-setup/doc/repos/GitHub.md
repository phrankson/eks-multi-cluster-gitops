## Create and prepare the Git repositories

### Authenticate the GitHub CLI

```bash
gh auth login
```
Choose **HTTPS** as the preferred protocol and **Login with a web browser**. Run `gh auth status`
to confirm you are logged in.

> This repo uses a GitHub Personal Access Token (PAT) — not SSH keys — for Flux's own Git
> access, created later in the main guide's "Create Git credentials as Sealed Secrets" step.
> The sealed credentials only work over HTTPS.

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
   export REPO_PREFIX="https://github.com/$GITHUB_ACCOUNT"
   ```

> Git credentials for Flux (a GitHub PAT, sealed via `kubeseal`) are created later in the
> main guide's "Create Git credentials as Sealed Secrets" step — nothing further to do here.

When done, continue with the setup process [here](../../README.md#populate-and-update-the-repositories)
