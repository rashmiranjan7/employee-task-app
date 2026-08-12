# Employee Task Tracker — Application Repository

A full-stack task management app, built to show a complete DevOps setup for one real application: containerized app → Terraform-provisioned AWS infrastructure → GitOps-managed Kubernetes deployment → CI/CD → monitoring.

**Live:** `https://app.yourdomain.com`

## Project overview

Employees can sign up, log in, and manage tasks (create, assign, track status, filter by priority) through a JWT-authenticated REST API and a React SPA.

This is one of **3 repos**, each with one clear job:

| Repo | Owns |
|---|---|
| **employee-task-app** (this repo) | Application source, the Helm chart (code + default values in one place), CI/CD pipelines, local dev stack, docs |
| [employee-task-gitops](https://github.com/rashmiranjan7/employee-task-gitops) | The one ArgoCD Application that deploys this repo's chart |
| [employee-task-infra](https://github.com/rashmiranjan7/employee-task-infra) | Terraform — everything CI/CD and the app run on top of |

## Architecture diagram

```
employee-task-infra                    employee-task-app
  Terraform: VPC, EKS, RDS,               backend/, frontend/
  ECR, ACM, Route53 lookup,               helm/employee-task/ (chart + values, one file)
  GitHub OIDC role, Jenkins EC2           .github/workflows/ci-cd.yml
  (Jenkins installs itself on boot)       Jenkinsfile
        |                                        |
        |                                 push to main
        |                                        v
        |                                 GitHub Actions OR Jenkins
        |                                 test -> secret scan -> build
        |                                 -> scan image -> push to ECR
        |                                        |
        |                                 update-image-tag.sh commits
        |                                 the new tag right back into
        |                                 this repo's values.yaml
        v                                        |
  EKS cluster (dev)                              v
  backend + frontend pods  <---------------  ArgoCD (single source: this
  |            |                              repo's helm/employee-task/)
  v            v                              — see employee-task-gitops
RDS MySQL   ALB + one hostname
                    |
                    v
     Prometheus -> Grafana -> Alertmanager -> Slack
```

## Folder structure

```
backend/            Express API — JWT auth, tasks, users, audit log, tests
frontend/            React SPA (Vite)
helm/employee-task/  The Helm chart — templates AND default values.yaml, one place
docker/              docker-compose.yml for local development
monitoring/          Prometheus / Grafana / Alertmanager config
scripts/
  ci/                Shared build/test/deploy logic — called by BOTH pipelines
  rollback.sh, verify-deployment.sh, notify-slack.sh
.github/workflows/   CI/CD pipeline (GitHub Actions)
Jenkinsfile          CI/CD pipeline (Jenkins) — does the same thing
```

## Technology stack

React · Node.js/Express · MySQL · Docker · Docker Compose · Terraform · AWS (VPC, EKS, RDS, ECR, IAM, Route53, ACM, EC2) · GitHub Actions · Jenkins · Kubernetes · Helm · ArgoCD · Prometheus · Grafana · Alertmanager · Slack

## Setup instructions (quick start — local only)

```bash
git clone https://github.com/rashmiranjan7/employee-task-app.git
cd employee-task-app

cp docker/.env.example docker/.env                                # fill in DB/Grafana passwords
cp backend/.env.development.example backend/.env.development       # fill in a JWT secret

cd docker
docker compose up --build
```

- Frontend: http://localhost:3000
- Backend API: http://localhost:5000
- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090

For the full AWS deployment (all 3 repos, in order): [SETUP.md](./SETUP.md).

## Deployment instructions

Push to `main` and CI builds, scans, and pushes the images, then commits the new image tag back into this repo's `helm/employee-task/values.yaml`. ArgoCD picks that change up and rolls it out automatically. Full flow: [SETUP.md](./SETUP.md#day-to-day-deploys).

## Rollback procedure

```bash
./scripts/rollback.sh
```
Reverts `helm/employee-task/values.yaml` to its previous Git commit and syncs ArgoCD to that — a Git revert, not `argocd app rollback`, so Git stays the one source of truth (an `argocd app rollback` would just get undone by the next auto-sync).

## Troubleshooting guide

Common failures across Terraform, Kubernetes, Ingress/DNS, ArgoCD, both CI/CD pipelines, and monitoring, each with the command to run: [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## Full teardown

Step by step, in [SETUP.md](./SETUP.md#tearing-it-all-down).

## Screenshots

_Add screenshots here once deployed: the Grafana dashboard, the ArgoCD UI showing the Application synced, the running app, and a GitHub Actions run._

## Scope

This project deliberately runs one environment (dev) and keeps one hostname for the whole app. It's a portfolio project meant to be fully understood end-to-end, not a template for a multi-team production setup.
