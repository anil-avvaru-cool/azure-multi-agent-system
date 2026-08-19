#!/usr/bin/env bash
# infra/deploy.sh — up | down
#
# `up` runs a subscription-scope Bicep deployment (main.bicep creates the
# resource group itself, then scopes every module into it) rather than the
# resource-group-scope `az deployment group create` originally sketched in
# docs/INFRA_DEPLOYMENT_PLAN.md §5 — that command requires the target
# resource group to already exist, which is circular for Phase 0.1 ("create
# the resource group"). See infra/bicep/main.bicep's header comment.
#
# `down` deletes the entire resource group. Correct specifically because
# every Bicep-managed resource lives in one RG (docs/INFRA_DEPLOYMENT_PLAN.md
# §2) — no per-resource teardown ordering to get wrong. It does NOT touch
# the Foundry hosted-agent runtime's resources, which are `azd`-managed and
# have their own lifecycle (`azd down`) — see hosted_agent/README.md.
#
# Stage 2 (Foundry project creation) makes a single attempt. It does not
# auto-retry the known identity-propagation race (see docs/
# INFRA_DEPLOYMENT_PLAN.md §6) — re-run `infra/deploy.sh up` manually if it
# hits that error, rather than looping automatically and risking Azure
# Resource Manager rate limiting from repeated `az deployment sub create`
# calls.
#
# Both are real, billable, and — for `down` — destructive Azure operations.
# Both run unattended (no interactive confirmation) — invoke with care.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_FILE="${SCRIPT_DIR}/bicep/main.bicep"
PARAMS_FILE="${SCRIPT_DIR}/bicep/params/dev.bicepparam"
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/deploy-$(date +%Y%m%d-%H%M%S).log"

# Read straight from the param file rather than duplicating these values —
# same "no hardcoded values" posture as the repo's .env/config/settings.py
# fail-fast pattern.
LOCATION="$(grep -oP "^param location = '\K[^']+" "${PARAMS_FILE}")"
RESOURCE_GROUP_NAME="$(grep -oP "^param resource_group_name = '\K[^']+" "${PARAMS_FILE}")"

usage() {
  echo "Usage: $0 up|down" >&2
  exit 1
}

[ $# -eq 1 ] || usage

case "$1" in
  up)
    mkdir -p "${LOG_DIR}"
    subscription_id="$(az account show --query id -o tsv)"
    subscription_name="$(az account show --query name -o tsv)"
    echo "Deploying ${TEMPLATE_FILE} to subscription '${subscription_name}' (${subscription_id}), region ${LOCATION}."
    echo "This provisions real, billable Azure resources."
    echo "Debug output for this run: ${LOG_FILE}"

    # Two-stage Phase 1 deploy: the Foundry account's system-assigned
    # identity provisions correctly, but the Cognitive Services RP takes a
    # few seconds to internally propagate it before project-creation
    # validation sees it — an undocumented async lag with no readiness
    # attribute to poll (confirmed live: identity.principalId was already
    # populated when the race still hit). So stage 1 deploys everything
    # except the Foundry project, then stage 2 retries the actual project
    # creation until it succeeds, rather than sleeping a guessed duration.
    # See docs/INFRA_DEPLOYMENT_PLAN.md §6.
    echo "Stage 1/2: deploying Phase 0 + Phase 1 (Foundry project deferred)..."
    if ! az deployment sub create \
      --name "sub-deploy-$(date +%s)" \
      --location "${LOCATION}" \
      --template-file "${TEMPLATE_FILE}" \
      --parameters "${PARAMS_FILE}" \
      --parameters deploy_foundry_project=false \
      --debug >>"${LOG_FILE}" 2>&1; then
      echo "Stage 1 failed — see ${LOG_FILE}" >&2
      exit 1
    fi
    echo "Stage 1 succeeded."

    echo "Stage 2/2: deploying Foundry project..."
    if error_output="$(az deployment sub create \
      --name "sub-deploy-$(date +%s)" \
      --location "${LOCATION}" \
      --template-file "${TEMPLATE_FILE}" \
      --parameters "${PARAMS_FILE}" \
      --debug 2>&1)"; then
      echo "${error_output}" >>"${LOG_FILE}"
      echo "Stage 2 succeeded."
    else
      echo "${error_output}" >>"${LOG_FILE}"
      if [[ "${error_output}" == *"you must enable a managed identity"* ]]; then
        echo "Foundry project creation hit the known identity-propagation race (see docs/INFRA_DEPLOYMENT_PLAN.md §6) — re-run '$0 up' manually." >&2
      fi
      echo "Stage 2 failed — see ${LOG_FILE}" >&2
      exit 1
    fi
    ;;
  down)
    echo "Deleting resource group '${RESOURCE_GROUP_NAME}' and everything in it."
    echo "This does not affect the azd-managed hosted-agent runtime — see hosted_agent/README.md for that teardown."
    az group delete --name "${RESOURCE_GROUP_NAME}" --yes
    ;;
  *)
    usage
    ;;
esac
