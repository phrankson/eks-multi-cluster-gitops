# Modernization Changelog

Maps each commit on `modernize/eks-1.35-stack-upgrade` to the risk-register item(s) it
resolves in `docs/COMPONENT_INVENTORY.md` and/or the compatibility-matrix row(s) in
`docs/UPGRADE_PLAN.md`. Generated as part of the same modernization pass; see those two
docs for full research/reasoning behind each change.

| Commit | Summary | Inventory risk # / Upgrade-plan row(s) resolved |
|---|---|---|
| `d9aad05` | docs: add CLAUDE.md, component inventory, and upgrade plan | Baseline — establishes `docs/COMPONENT_INVENTORY.md` and `docs/UPGRADE_PLAN.md` |
| `54f07d1` | chore: remove legacy CloudFormation/Cloud9 bootstrap path | Inventory risks #2, #3, #4, #7, #8 (conflicting K8s version, unpinned tool installs in `cfn.yaml`, EOL Ubuntu 18.04/Python 3.8, dead Sealed Secrets chart URL) |
| `d098a0d` | feat: bump target Kubernetes to EKS 1.35, eksctl to v0.229.0 | Upgrade-plan rows #1–3 (EKS/eksctl/kubectl); addresses 1.31 already being past standard support |
| `629acdb` | feat: upgrade FluxCD to v2.9.2, fix mgmt/template version drift | Inventory risk #1 (Flux version drift mgmt v2.1.2 vs template v2.8.6); inventory risk #8 (`image.toolkit.fluxcd.io` documented but not installed); upgrade-plan row #4 |
| `37a5c02` | feat: bump Crossplane core to 1.20.10, provider-aws to v0.58.1 | Upgrade-plan rows #5–7; deliberately does not touch inventory risks #1–2 (alpha APIs, provider-family-aws) or #12 (cluster-admin CronJob) — all explicitly deferred per plan §4/§5 |
| `966007d` | feat: upgrade secrets stack (Sealed Secrets 2.19.1, ESO 2.8.0 + v1 API) | Inventory risk #5 (no automated re-seal — confirmed still-necessary design, not "fixed"), risk #11 (controller versions now pinned via `values.image.tag`, closing the prose-only gap); upgrade-plan rows #8–10 |
| `431ea2f` | feat: upgrade Karpenter, AWS Load Balancer Controller, EBS CSI Driver | Upgrade-plan rows #11–13. Does **not** address inventory risk #10 (Karpenter AMI floating on `al2023@latest`) — that risk was noted but no decision was made to fix it this pass |
| `62db20f` | feat: upgrade demo app dependencies, fix `:latest` tag, drop dead v2-staging | Inventory risk #2 (fe `:latest` tag in prod+staging — **fixed**), risk #9 (orphaned/broken DynamoDB claim — **deleted**, decision #7); upgrade-plan rows #15–24 (flask-cors/axios CVEs prioritized, Flask/Werkzeug/MarkupSafe, base images) |
| `1012fcf` | chore: fix sed portability, retire duplicate scripts, add make validate | Inventory risk #6 (`sed -i ''` BSD-only — **fixed** in the two surviving scripts), risk #7 (duplicate script generations — **retired**, decision #8); plan's "add a small `make validate` / CI script" requirement |
| `9df7a4f` | docs: sweep remaining stale version/org references | Final consistency pass — no new risk items, closes drift introduced by earlier commits in this same series |

## Explicitly deferred / not addressed (see `docs/UPGRADE_PLAN.md` §4–5 for reasoning)

These were identified in Layer 1/2 but intentionally **not** touched in this pass:

- **Kubecost** (inventory: chart 2.6.0, several risks) — held as-is; full v1→v2→v3 rewrite skipped per decision #1 (not used often enough to justify it right now).
- **Crossplane core v2.x / Composition Functions / provider-family-aws migration** (inventory risks #1, #3) — deferred per decision #3; core stays on the 1.20.x line with classic patch-and-transform.
- **IRSA → EKS Pod Identity** — deferred per decision #2; all service accounts stay on IRSA.
- **Express 5 migration** (product-catalog-fe) — deferred per decision #4; stayed on the 4.x line (bumped to 4.22.2).
- **Karpenter `EC2NodeClass` AMI floating on `al2023@latest`** (inventory risk #10) — noted, no decision was requested or made to pin it; still floating.
- **Hardcoded OIDC thumbprint, EKS NodeGroup instance type/min size, per-cluster CIDR blocks in the Crossplane Composition** (inventory risk #16 / knowledge-base.md FP-3) — config-value cleanups, not version-compatibility items; not in scope for this pass.
- **`crossplane-k8s-provider-config` CronJob granting `cluster-admin` every 3 minutes** (inventory risk #12) — flagged as a security/blast-radius concern, not touched.
- **NOTICE.md** — intentionally left with pre-rename `bitnami-labs/sealed-secrets` reference; it's a point-in-time legal attribution snapshot, not a live pointer.

## Verification performed

Every commit that touched a `kustomization.yaml`-backed directory was validated with
`kustomize build` before committing (see individual commit messages for exact scope).
`bin/validate.sh` / `make validate` (added in `1012fcf`) now runs this check across the
entire repo in one pass, plus `kubeconform` schema validation when available (wired into
`.github/workflows/validate.yml` for CI). `npm audit` was run and is clean for
`product-catalog-fe` after the dependency bumps in `62db20f`.

No live AWS/EKS cluster was provisioned or exercised as part of this pass — all
verification is static (manifest rendering, schema validation, local `flux install
--export` regeneration). The next real-world test is a live `initial-setup` run against
the updated `mgmt-cluster-eksctl.yaml` and `flux bootstrap`.
