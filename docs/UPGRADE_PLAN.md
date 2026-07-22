# Upgrade Plan — eks-multi-cluster-gitops

**Generated:** 2026-07-22 (Layer 2 of the modernization effort — research + plan, no code changes made yet)
**Method:** 5 parallel web-research agents, each independently sourcing current versions/compatibility/breaking-changes with citations. Builds directly on `docs/COMPONENT_INVENTORY.md` (Layer 1). Scope: **CloudFormation/Cloud9 path (`initial-setup/auto/cfn.yaml`) excluded per user decision** — not researched, not planned, candidate for deletion at implementation time (pending confirmation).

---

## 1. Target EKS version

**Recommendation: EKS 1.35**

| K8s version | EKS GA | End of standard support | Standard-support runway from today |
|---|---|---|---|
| 1.33 | 2025-05-28 | 2026-07-29 | ~1 week — rejected |
| 1.34 | 2025-10-06 | 2026-12-02 | ~4.5 months — rejected, too short |
| **1.35** | **2026-01-28** | **2027-03-27** | **~20 months — selected** |
| 1.36 | 2026-06-02 | 2027-08-02 | ~13 months, but only ~7 weeks old today — rejected, too fresh for ecosystem/add-on validation, and introduces fresh landmines (`gitRepo` volumes hard-disabled, `StrictIPCIDRValidation` on by default) |

The repo's current pin (1.31) is **already past EKS standard support entirely** — this alone is a forcing function, independent of everything else in this plan.

1.35 removes cgroup v1 support and is the last release supporting containerd 1.x — not expected to affect this repo (standard AL2023 managed node groups), but worth a sanity check against the Karpenter `EC2NodeClass` AMI family at implementation time.

**This choice is load-bearing for everything below**: Flux's own minimum-supported-Kubernetes floor is now 1.33 (see §2) — so 1.35 is required to stay inside Flux's documented support window, not just an EKS-lifecycle preference.

kubectl: pin to **1.35.x** (skew policy is ±1 minor from the control plane; 1.35 keeps the widest safety margin as the cluster is later upgraded forward). eksctl: bump to **v0.229.0** (current stable).

---

## 2. Compatibility Matrix

| # | Component | Current pinned | Target | K8s/EKS compat | Breaking changes | Effort |
|---|---|---|---|---|---|---|
| 1 | EKS / Kubernetes | 1.31 | **1.35** | — | See §1; already past standard support | S |
| 2 | eksctl CLI | v0.208.0 | **v0.229.0** | — | Default addon behavior already shifted to EKS-managed addons since v0.184 (predates current pin) — should now be made explicit in ClusterConfig `addons:` block rather than relying on defaults | S |
| 3 | kubectl | 1.31.0 | **1.35.x** | ±1 minor skew | none | S |
| 4 | FluxCD | v2.1.2 (mgmt) / v2.8.6 (template) — **drifted** | **v2.9.2** | min K8s 1.33+ | apiVersions already GA, mechanically safe; run `flux migrate` defensively, must regenerate `gotk-components.yaml` via re-bootstrap (no in-place version bump); re-test HelmRelease health-check behavior (Helm v4 / kstatus changes landed in v2.8) | M |
| 5 | Crossplane core | 1.19.2 | **stay on 1.20.x line** (do NOT jump to core v2.x yet) | "actively supported" K8s, no fixed floor | v2.x **hard-removes** patch-and-transform Composition mode — this repo's 20-resource Composition uses classic P&T | See §4 — recommend deferring | — |
| 6 | Provider AWS (Crossplane) | crossplane-contrib/provider-aws v0.47.1 | **stay on crossplane-contrib/provider-aws, bump to v0.58.1** (do NOT migrate to provider-family-aws yet) | — | Family-provider migration is a multi-day rewrite (different codegen lineage, all field/patch paths change) — see §4 | S (version bump only) / **L** (family migration, deferred) |
| 7 | Provider Kubernetes (Crossplane) | v1.2.1 | **v1.2.1 (already latest)** | — | none; `kubernetes.crossplane.io/v1alpha1` not promoted, no action needed | — |
| 8 | Sealed Secrets (chart) | 2.18.5 | **2.19.1** | — | **Chart repo URL is dead**: `bitnami-labs.github.io/sealed-secrets` → 404. Must move to `https://bitnami.github.io/sealed-secrets`. Controller image tag can now be explicitly pinned via `image.tag` Helm value (closes prose-only gap) | S (repo fix is mandatory/urgent regardless of version bump) |
| 9 | kubeseal CLI | v0.36.6 | **v0.38.4** (paired with chart 2.19.1's controller) | — | same-release pairing convention, no hard compat gate documented | S |
| 10 | External Secrets Operator (chart) | 0.10.7 | **2.8.0** | — | Major version-scheme jump (0.x→1.0→2.x); `v1beta1` CRDs now `served: false` in current bundle — flag-removal deadline (2026-05-01) already passed; must migrate `SecretStore`/`ExternalSecret` apiVersion from `v1beta1`→`v1`; check `engineVersion` default differs between the two (v2 default under v1beta1, v1 default under v1) | M |
| 11 | Karpenter (chart) | 1.3.1 | **1.14.0** | K8s ≥1.2, well within 1.35 | `karpenter.sh/v1`/`karpenter.k8s.aws/v1` confirmed still current/served — no schema break; additive-only changes (Balanced consolidation policy, budget scheduling, `replicas` field) | S |
| 12 | AWS Load Balancer Controller (chart) | 1.11.0 | **3.4.2** | K8s ≥1.22 | Major v2→v3 rewrite: Gateway API v1.3→v1.5 bump, `--aws-vpc-tag-key` deprecated (uses all `--aws-vpc-tags` now — can silently fail to locate VPC post-upgrade if tags aren't updated), webhook cert handling changed (`keepTLSSecret` reintroduced) | M |
| 13 | AWS EBS CSI Driver (chart) | 2.38.1 | **2.63.0** | — | **Repo location was wrong in the original inventory assumption**: actual home is `https://kubernetes-sigs.github.io/aws-ebs-csi-driver`, not `aws.github.io/eks-charts` (confirmed: chart isn't in eks-charts' index at all — repo must already be pointing at the right place per the inventory, verify at implementation time). No single breaking-change flag day found; incremental changes only | S |
| 14 | Kubecost cost-analyzer (chart) | 2.6.0 | **3.2.1, renamed to `kubecost`** | — | **Full architecture rewrite**: chart+OCI path renamed (`oci://public.ecr.aws/kubecost/kubecost`, not `.../cost-analyzer`); bundled Prometheus+Grafana eliminated in favor of ClickHouse + FinOps Agent/Aggregator; multi-cluster now uses S3-compatible object storage; direct v1→v3 upgrade unsupported (must go v1→v2→v3); ≥8GB RAM + premium-IO StorageClass now recommended minimum | **L** |
| 15 | product-catalog-api: flask-cors | 4.0.2 | **6.0.5** | — | **5 CVEs from 2024** affect 4.0.2 (regex path-matching bypass, case-insensitive bypass, `+`-normalization bypass, ACAPN default-true, CRLF log injection) — highest-priority app-layer fix | S |
| 16 | product-catalog-api: requests | 2.32.3 | **2.34.2** | — | CVE-2024-47081 (netrc credential leak) postdates pinned version | S |
| 17 | product-catalog-api: Flask/Werkzeug/MarkupSafe | 3.0.3 / 3.0.4 / 2.1.5 | **3.1.3 / 3.1.8 / 3.0.3** | — | Flask 3.1.x requires Werkzeug ≥3.1 — bump together, not independently. No urgent CVE, routine bump | S |
| 18 | product-catalog-api: gunicorn, boto3, flask-restx | 23.0.0 / 1.35.39 / 1.3.0 | **26.0.0 / 1.43.53 / 1.3.2** | — | No active CVE exposure at current pins; low urgency, routine bump | S |
| 19 | product-catalog-api: base image | `python:3.12-slim` (floating) | **`python:3.13-slim`, digest-pinned** | — | 3.12 in security-only maintenance (EOL Oct 2028), 3.13 active (EOL Oct 2029); no known dependency incompatibility | S |
| 20 | product-catalog-fe: axios | ^1.7.4 | **1.18.1** | — | **Critical CVE-2026-40175** (prototype pollution + SSRF + request smuggling → IMDSv2 credential theft) affects all versions <1.13.2 — pinned range is squarely vulnerable. **Highest-priority fix in the entire app stack.** One breaking change: merged config objects now null-prototype | S |
| 21 | product-catalog-fe: express | ^4.21.1 | Stay on **4.22.2** for this pass; flag Express 5 as a separate deliberate migration | — | Express 5 is now npm's `latest` tag but is a real breaking migration (`app.del()` removed, query-parser default changed, async error auto-forwarding, MIME type change) — not a caret-range bump | S (4.x bump) / M (5.x migration, deferred) |
| 22 | product-catalog-fe: ejs | ^3.1.10 | **6.0.1** | — | 3 majors behind; no active CVE (3.1.7+ already has the SSTI fix) but review 4/5/6 changelogs before bumping — bigger jump than the caret range implies | M |
| 23 | product-catalog-fe: prom-client | ^14.0.1 | **15.1.3** | — | Breaking: pushgateway methods now Promise-based not callback-based; eventloop-lag metric behavior changed. No CVE, low-risk bump | S |
| 24 | product-catalog-fe: base image | `node:22-slim` (floating) | **`node:24-slim`, digest-pinned** | — | Node 22 rolled into Maintenance LTS (EOL Apr 2027); Node 24 is now Active LTS (EOL Apr 2028) | S |
| 25 | IRSA vs. EKS Pod Identity | IRSA (all ~6 roles) | **Stay on IRSA** (recommendation only — see §5) | — | Crossplane's own docs don't yet document first-class Pod Identity auth for provider pods; Pod Identity doesn't support Fargate (not used here anyway). Proposal: keep Crossplane on IRSA, optionally Pod-Identity the simpler non-Crossplane-authenticated add-ons (ALB Controller, EBS CSI, Karpenter, ESO) later | — (deferred, needs your call) |

---

## 3. Dependency-Ordered Upgrade Sequence

Sequencing follows the actual bootstrap dependency chain established in `docs/COMPONENT_INVENTORY.md` §2.2 — each stage assumes the previous stage is validated (`kustomize build` + `kubeconform` clean) before proceeding.

```
Stage 0 — Scope cleanup
  └─ Delete initial-setup/auto/cfn.yaml and its Cloud9-only support files (decision #6)
  └─ Fix Sealed Secrets chart repo URL (bitnami-labs.github.io → bitnami.github.io) — this is a
     standalone hard break, fix it first regardless of version-bump sequencing below

Stage 1 — Target EKS version + cluster bring-up
  └─ mgmt-cluster-eksctl.yaml: K8s 1.31 → 1.35, eksctl v0.208.0 → v0.229.0, kubectl → 1.35.x
  └─ Explicitly declare addons: block (vpc-cni, coredns, kube-proxy, [pod-identity-agent if adopted])
     instead of relying on eksctl implicit defaults
  └─ Crossplane EKS-composition claim template (clusters-config/template/def/eks-cluster.yaml):
     eks-k8s-version / mng-k8s-version → '1.35'

Stage 2 — FluxCD (mgmt, then workload template)
  └─ flux migrate (defensive, repo already GA-clean) → flux bootstrap regenerate
     gotk-components.yaml/gotk-sync.yaml at v2.9.2 for BOTH clusters/mgmt AND
     clusters/template (this is what fixes the version-drift bug)
  └─ Re-test HelmRelease health-check behavior given Helm v4/kstatus changes in v2.8
  └─ Remove the --components-extra=image-reflector-controller,image-automation-controller
     claim from GETTING-STARTED.md / RECREATE-MGMT-CLUSTER.md (decision #5) — these
     controllers were never actually installed and this demo won't showcase them

Stage 3 — Crossplane core + providers (mgmt only; workload clusters inherit via composition)
  └─ Crossplane core: 1.19.2 → 1.20.x line (NOT v2.x — see §4)
  └─ Provider AWS: v0.47.1 → v0.58.1 (same crossplane-contrib package, version bump only)
  └─ Provider Kubernetes: already latest (v1.2.1), no action
  └─ Composition/XRD: bump hardcoded eks-k8s-version/mng-k8s-version references to 1.35;
     leave patch-and-transform mode as-is; leave `eks.aws.crossplane.io/v1alpha1 NodeGroup`
     as-is (no non-alpha option exists without the family-provider migration)

Stage 4 — Secrets stack (mgmt, then per-workload-cluster template)
  └─ Sealed Secrets: chart 2.18.5 → 2.19.1, repo URL fixed (Stage 0), pin image.tag
     explicitly to close the prose-only version-coupling gap; kubeseal CLI → v0.38.4
  └─ External Secrets Operator: chart 0.10.7 → 2.8.0, migrate SecretStore/ExternalSecret
     apiVersion v1beta1 → v1, audit templating engineVersion if any ExternalSecret uses
     templates
  └─ Re-verify the pre-seeded-keypair bootstrap chain end-to-end (this pattern is confirmed
     still necessary — see §4 — but the chart/API bumps above touch every link in it)

Stage 5 — Add-ons (workload-cluster template)
  └─ Karpenter: chart 1.3.1 → 1.14.0 (apiVersions unchanged, low risk)
  └─ AWS Load Balancer Controller: chart 1.11.0 → 3.4.2 (verify VPC tag filters cover
     everything --aws-vpc-tag-key used to narrow; re-pull Gateway API CRDs if in use)
  └─ AWS EBS CSI Driver: chart 2.38.1 → 2.63.0; correct HelmRepository URL if it currently
     points at eks-charts (verify against actual repo state at implementation time)
  └─ Kubecost: SKIPPED this pass (decision #1) — hold at chart 2.6.0/cost-analyzer, no changes

Stage 6 — Applications
  └─ product-catalog-api: bump flask-cors (priority — CVEs) and requests (priority — CVE)
     first; then Flask+Werkzeug+MarkupSafe together; then gunicorn/boto3/flask-restx;
     base image → python:3.13-slim, digest-pinned
  └─ product-catalog-fe: bump axios first (priority — critical CVE-2026-40175); express
     4.21.1 → 4.22.2 (defer v5 migration as separate work); ejs → 6.0.1 (review changelog);
     prom-client → 15.1.3; base image → node:24-slim, digest-pinned
  └─ Fix the two concrete breakages already found in Layer 1: product-catalog-fe's
     `:latest` image tag (prod+staging) → pin to a real tag; delete the orphaned
     product-catalog-api v2-staging overlay + DynamoDB claim entirely (decision #7)

Stage 7 — Scripts & docs
  └─ Fix bin/*.sh BSD-only `sed -i ''` → portable form (works on both GNU and BSD sed)
  └─ Retire add-cluster.sh and remove-cluster.sh (decision #8); add-workload-cluster.sh /
     remove-workload-cluster.sh become the sole documented entrypoints; update
     bin/README.md and scenarios.md accordingly
  └─ Update every version reference across initial-setup/README.md, GETTING-STARTED.md,
     RECREATE-MGMT-CLUSTER.md, scenarios.md, clean-up/README.md, CLAUDE.md to match this
     plan's target versions — docs drift is treated as a bug per the ground rules
  └─ Add make validate / CI script: kustomize build on every overlay + kubeconform
     (with Flux/Crossplane/ESO/Sealed-Secrets CRD schemas) against K8s 1.35
```

---

## 4. Design assumptions — still valid or not?

| Assumption / pattern | Still holds? | Detail |
|---|---|---|
| **Pre-seeded Sealed Secrets keypair via AWS Secrets Manager + ESO** (openssl-generated, not kubeseal-generated; avoids the chicken-and-egg problem of Flux needing decrypted git creds before it can run) | **Yes — confirmed still necessary.** No current Sealed Secrets release (through v0.38.4/chart 2.19.1) adds a Helm-values-based "bring your own key at install time" flow. The only supported mechanism remains: label a pre-existing Secret `sealedsecrets.bitnami.com/sealed-secrets-key=active` in the controller's namespace before/at controller startup. Keep this pattern as-is. | 
| **`cluster-info` ConfigMap substitution via Flux `postBuild.substituteFrom`** | **Yes — unaffected by any researched change.** Flux's `postBuild.substituteFrom` mechanism itself has no researched behavior change since v2.1.2 relevant to this pattern (only the per-entry `optional:` flag semantics were reconfirmed as unchanged, not flipped globally). Keep as-is. |
| **IRSA for all ~6 service accounts** (Crossplane, ALB Controller, EBS CSI, Karpenter, ESO, per-app roles) | **Still valid, no forced migration.** IRSA has no deprecation timeline. EKS Pod Identity is AWS's newer default recommendation for *new* setups and now supports cross-account role chaining, but Crossplane's own docs don't yet show first-class Pod Identity support for provider-pod auth. **Proposal (not applied): keep Crossplane on IRSA, consider Pod Identity for the simpler add-ons only** (ALB Controller/EBS CSI/Karpenter/ESO natively support it via eksctl's `addonsConfig.autoApplyPodIdentityAssociations`). This is explicitly flagged for your decision, not something to do silently. |
| **Crossplane classic patch-and-transform Composition** (not Composition Functions) | **Valid to keep for now, but time-limited.** P&T is deprecated since Crossplane 1.17, still functional (security-patches-only) through the 1.20.x line, and **hard-removed in Crossplane core v2.x**. Recommendation: **stay on core 1.20.x and P&T for this modernization pass** — do not bundle a P&T→Composition-Functions rewrite with everything else in this plan. When you do eventually want core v2.x, budget it as its own isolated project using `crossplane-contrib/function-patch-and-transform` + the `crossplane beta convert pipeline-composition` CLI auto-converter. |
| **Monolithic `crossplane-contrib/provider-aws`** (not split provider-family-aws) | **Valid to keep for now, same reasoning as above.** Not archived, still actively released (v0.58.1 cut today). Official new-project guidance has shifted toward provider-family-aws, but migrating this repo's 20-resource composition is a multi-day rewrite (different codegen lineage — upjet/Terraform-based vs. Go-SDK-native; field names, patch paths, and reference/selector conventions all differ). Recommendation: **version-bump the monolith now, defer the family-provider migration** as a separate future project — same reasoning as the Composition Functions deferral, and for the same reason these two are coupled (family-provider adoption would be the natural moment to also move to Composition Functions, not before). |
| **Hardcoded OIDC thumbprint in the Composition** | Not researched in Layer 2 (out of scope for this pass — this is a config-value fix already fully specified in Layer 1's FP-3 finding, not a version-compatibility question). Carry forward as a Stage 3 cleanup item if you want it addressed in the same pass. |

---

## 5. Decisions (resolved 2026-07-22)

| # | Item | Decision |
|---|---|---|
| 1 | Kubecost | **Skip entirely this pass.** Hold at chart 2.6.0/`cost-analyzer`. Not used often enough to justify the v1→v2→v3 rewrite + ClickHouse/capacity change right now. Removed from Stage 5 below. |
| 2 | IRSA vs. Pod Identity | **Stay on IRSA everywhere.** No Pod Identity migration this pass. |
| 3 | Crossplane core v2.x / Composition Functions / provider-family-aws | **Deferred**, confirmed. Stage 3 stays version-bump-only (core 1.20.x line, provider-aws v0.58.1, patch-and-transform retained). |
| 4 | Express 5 (product-catalog-fe) | **Deferred.** Bump to 4.22.2 now; v5 migration is separate future work. |
| 5 | Flux image-reflector/image-automation controllers | **Remove the doc claim.** Strip the `--components-extra=image-reflector-controller,image-automation-controller` reference from GETTING-STARTED.md/RECREATE-MGMT-CLUSTER.md rather than actually enabling them — this demo doesn't showcase image automation. |
| 6 | `initial-setup/auto/cfn.yaml` | **Delete outright** in Stage 0, along with its now-orphaned support files under `initial-setup/config/cloud9-role-permission-policy-template.json` and any `initial-setup/doc`/`img` content that exists solely to document the Cloud9 path (verify at implementation time before removing docs/images shared with the primary path). |
| 7 | Orphaned `v2-staging` DynamoDB overlay | **Delete as dead code** (my discretion, per your instruction). It's unwired from any Flux Kustomization/GitRepository, uses an alpha Crossplane API, and its own kustomization.yaml already references a nonexistent `base/` dir — reviving it would mean designing a base directory from scratch for a resource nothing currently deploys. Simpler and more honest to remove `repos/apps-manifests/product-catalog-api-manifests/v2-staging/` entirely and note in the changelog that a v2-staging demo scenario was removed as broken/dead, in case anyone wants to reintroduce it deliberately later. |
| 8 | Duplicate `bin/` scripts | **Retire `add-cluster.sh` and `remove-cluster.sh`.** `add-workload-cluster.sh`/`remove-workload-cluster.sh` become the sole documented entrypoints; update `bin/README.md` and `scenarios.md` accordingly. |

All decisions above are now reflected in the Stage sequence in §3 (superseding the earlier "requiring decision" framing) — see Stage 0, 3, 5, 6, 7 for the concrete edits.
