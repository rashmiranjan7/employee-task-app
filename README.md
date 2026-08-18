# Employee Task Tracker — GitOps Repository

This repo tells ArgoCD what should be running in the Kubernetes cluster. ArgoCD watches this repo and keeps the cluster matching whatever is committed here — that's what "GitOps" means: Git is the single source of truth for what's deployed.

## Part of a 3-repo project

| Repo | What it does |
|---|---|
| [employee-task-app](https://github.com/rashmiranjanDevOps/employee-task-app) | The app code, the Helm chart, and CI/CD — start here for full setup steps |
| [employee-task-infra](https://github.com/rashmiranjanDevOps/employee-task-infra) | Terraform — everything CI/CD and the app run on top of |
| **employee-task-gitops** (this one) | The ArgoCD Application file that deploys the app |

## Why this repo only has one file

This might look too small at first — it's on purpose. Everything that changes when the *app* changes (a new environment variable, a new port, a new probe) lives in `employee-task-app`'s Helm chart, right next to the code change that needs it. This repo only holds the ArgoCD `Application` definition that tells ArgoCD *where* to look. It almost never changes once it's set up.

I kept it as a separate repo (instead of just putting this file inside `employee-task-app`) because that's the standard GitOps pattern: it keeps "what is my app" separate from "what is currently deployed," which matters more once a project has multiple environments. For this project it's mostly a demonstration of the pattern — with only one environment, the practical benefit is small today, but it's how this would scale to a dev/staging/prod setup later.

## Folder structure

```
apps/
  dev-application.yaml   The one ArgoCD Application (auto-sync enabled)
```

There's no Helm chart and no values file in this repo — both live in `employee-task-app`.

## Tech stack

ArgoCD, Kubernetes (as the deploy target)

## How it works

The `Application` in `apps/dev-application.yaml` points at one place: the Helm chart inside `employee-task-app` (`helm/employee-task/`), which already has its own `values.yaml`. When CI in `employee-task-app` finishes building a new image, it updates the image tag directly in that `values.yaml` and commits it. ArgoCD notices the change and rolls it out — usually within about 3 minutes. This repo's own file barely ever needs to change for a normal deploy.

## Setting it up

This repo doesn't need its own setup — it needs `employee-task-infra`'s Terraform applied and ArgoCD installed in the cluster first. Full order across all 3 repos: `employee-task-app`'s [SETUP.md](https://github.com/rashmiranjanDevOps/employee-task-app/blob/main/SETUP.md).

Once ArgoCD is installed:

```bash
kubectl apply -f apps/dev-application.yaml
```

## Deploying

You don't deploy anything from this repo directly. CI in `employee-task-app` does the deploy by updating the image tag in that repo's `helm/employee-task/values.yaml`. ArgoCD auto-syncs that change on its own.

## Rolling back

```bash
# run this from employee-task-app
./scripts/rollback.sh
```

This reverts `helm/employee-task/values.yaml` (in the app repo) to its previous Git commit and lets ArgoCD sync to that. It's a Git revert, not `argocd app rollback` — an `argocd app rollback` would change the cluster without changing Git, and the very next auto-sync would silently undo it.

## Troubleshooting

| Problem | Likely cause |
|---|---|
| `Application` stuck `OutOfSync` | `syncPolicy.automated` is missing from `dev-application.yaml`, or the file was never applied |
| `Application` shows `Unknown` health | A Helm rendering error — check it locally from `employee-task-app`: `helm template helm/employee-task` |
| Image pull fails right after a deploy | The image tag CI wrote to `values.yaml` doesn't exist in ECR yet — check the CI run actually finished pushing the image |

Full troubleshooting guide across all 3 repos: `employee-task-app`'s [TROUBLESHOOTING.md](https://github.com/rashmiranjanDevOps/employee-task-app/blob/main/TROUBLESHOOTING.md).

## Deploying without CI or ArgoCD (manual, for testing)

```bash
# from employee-task-app
helm template helm/employee-task | kubectl apply -f -
```
