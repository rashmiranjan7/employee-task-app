#!/usr/bin/env bash
# update-image-tag.sh — bumps backend + frontend image tags in this repo's
# own Helm chart, then commits and pushes straight to the branch CI is
# already running on. ArgoCD (employee-task-gitops) watches this repo, so
# this one commit IS the deploy — no second repo, no separate PAT.
#
# Requires yq (https://github.com/mikefarah/yq) — pre-installed on
# GitHub-hosted Ubuntu runners; installed directly on the Jenkins host by
# employee-task-infra's user-data.sh.
#
# Usage:
#   ./update-image-tag.sh <image-tag>

set -euo pipefail

IMAGE_TAG="${1:?Usage: $0 <image-tag>}"
VALUES_FILE="helm/employee-task/values.yaml"

if [[ ! -f "${VALUES_FILE}" ]]; then
  echo "ERROR: ${VALUES_FILE} does not exist — run this from the repo root" >&2
  exit 1
fi

echo "==> Setting image tag to '${IMAGE_TAG}' in ${VALUES_FILE}"

yq -i ".backend.image.tag = \"${IMAGE_TAG}\"" "${VALUES_FILE}"
yq -i ".frontend.image.tag = \"${IMAGE_TAG}\"" "${VALUES_FILE}"

git config user.name "employee-task-ci"
git config user.email "ci@employee-task.local"
git add "${VALUES_FILE}"

if git diff --cached --quiet; then
  echo "==> No change (already at this tag) — nothing to commit."
  exit 0
fi

# [skip ci] plus the workflow's own paths-ignore on values.yaml both guard
# against this commit re-triggering another CI run.
git commit -m "chore: deploy ${IMAGE_TAG} [skip ci]"
git push origin HEAD

echo "==> Done — ArgoCD will pick this up on its next sync."
