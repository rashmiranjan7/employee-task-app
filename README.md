# Employee Task Tracker — App Repository

This is a task management web app. Employees can sign up, log in, and create/assign/track tasks. I built this as a personal project to practice real DevOps skills — not just the app code, but everything around it: containers, CI/CD, Kubernetes, and monitoring.

**Live app:** https://rashmidevops.xyz

## Part of a 3-repo project

I split this project into 3 repos on purpose, so each repo has one clear job — the same way a real team would split app code, infrastructure, and deployment config.

| Repo | What it does |
|---|---|
| **employee-task-app** (this one) | The app itself, the Helm chart, and both CI/CD pipelines |
| [employee-task-infra](https://github.com/rashmiranjanDevOps/employee-task-infra) | Terraform — builds all the AWS infrastructure |
| [employee-task-gitops](https://github.com/rashmiranjanDevOps/employee-task-gitops) | The ArgoCD file that tells Kubernetes what to run |

## How it all connects

1. I push code to `main` on GitHub.
2. CI runs (see "Two pipelines" below): it lints, tests, scans for secrets, builds Docker images, scans the images for vulnerabilities with Trivy, then pushes them to AWS ECR.
3. CI then updates the image tag in this repo's Helm chart and commits that change.
4. ArgoCD (running in the cluster) notices the change and automatically deploys the new version to EKS.
5. Prometheus scrapes metrics from the backend, Grafana shows them on a dashboard, and Alertmanager sends alerts to Slack if something's wrong.

## Folder structure

```
backend/              Node.js + Express API (auth, tasks, users, audit log)
frontend/             React app (built with Vite)
helm/employee-task/   The Helm chart — templates + default values, one place
docker/               docker-compose.yml, for running everything locally
monitoring/           Prometheus, Grafana, and Alertmanager config
scripts/
  ci/                 Shared scripts both pipelines call (test, build, scan, push)
  rollback.sh         Undo a bad deploy
  verify-deployment.sh  Check a deploy actually worked
  notify-slack.sh     Sends CI/deploy messages to Slack
.github/workflows/    CI/CD pipeline #1 (GitHub Actions)
Jenkinsfile            CI/CD pipeline #2 (Jenkins)
```

## Why two CI/CD pipelines?

I kept both GitHub Actions and Jenkins on purpose — as practice, so I understand both tools, not because the project needs two. In real day-to-day use I only run one at a time (see the note in the Jenkinsfile and workflow file). Both pipelines call the exact same scripts in `scripts/ci/`, so they do the same job the same way — nothing is duplicated in logic, only in "which tool triggers it."

## Tech stack

- **Backend:** Node.js, Express, Sequelize (MySQL), JWT auth
- **Frontend:** React, Vite, Tailwind CSS
- **Containers:** Docker, Docker Compose (for local dev)
- **CI/CD:** GitHub Actions and Jenkins (same scripts, either one works)
- **Security scanning:** Trivy (container images), Gitleaks (secrets in code), npm audit
- **Deployment:** Helm chart, ArgoCD (GitOps)
- **Monitoring:** Prometheus, Grafana, Alertmanager, Slack notifications

## Running it locally

```bash
git clone https://github.com/rashmiranjanDevOps/employee-task-app.git
cd employee-task-app

cp docker/.env.example docker/.env
cp backend/.env.development.example backend/.env.development
# open both files and fill in a DB password and a JWT secret

cd docker
docker compose up --build
```

Once it's running:
- App frontend: http://localhost:3000
- Backend API: http://localhost:5000
- Grafana: http://localhost:3001
- Prometheus: http://localhost:9090

For the full AWS setup across all 3 repos, see [SETUP.md](./SETUP.md).

## How a deploy works

I don't deploy by hand. I push to `main`, and CI does the rest — build, test, scan, push the image, and update the image tag in the Helm chart. ArgoCD then rolls it out to the cluster automatically, usually within a few minutes.

## Rolling back a bad deploy

```bash
./scripts/rollback.sh
```

This reverts the Helm chart's `values.yaml` to the previous Git commit and lets ArgoCD sync to that. I do it this way (not `argocd app rollback`) because Git stays the single source of truth — if I rolled back only inside ArgoCD, the next auto-sync would just undo it.

## What this costs to run

This is a small, single-environment setup, not a production cluster, so I kept AWS costs low on purpose:
- One EKS cluster with one small worker node (t3.medium)
- One NAT Gateway shared by both subnets, instead of one per AZ (cheaper, but if that NAT's AZ has an outage, both private subnets lose internet access — an acceptable trade-off for a learning project)
- One small RDS database (db.t3.micro), 1-day backup retention, no Multi-AZ
- No extra AWS KMS key for encryption — RDS and EKS already encrypt data with AWS's own default key, so I didn't add a second key to manage

Total cost is roughly $60–90/month while it's running (mostly EKS's control plane fee, the NAT Gateway, and the EC2 nodes). I tear it down with Terraform when I'm not actively working on it, to avoid paying for idle infrastructure.

## Troubleshooting

Common problems across all 3 repos, and the command to check each one: see [TROUBLESHOOTING.md](./TROUBLESHOOTING.md).

## Tearing everything down

Full steps (has to be done in a specific order): see [SETUP.md](./SETUP.md#tearing-it-all-down).

## Scope of this project

This is a portfolio project. It runs one environment (dev), one hostname, and one small cluster — built so I could understand every part of it end to end, not to copy a large company's production setup.
