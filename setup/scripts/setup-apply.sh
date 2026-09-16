#!/usr/bin/env bash
set -eo pipefail

# Run the setup playbook (monitoring stack + webhook bridge).
# Sources the repo-root .env so ServiceNow credentials are available automatically.
#
# Usage:
#   ./setup/scripts/setup-apply.sh
#
# Required env (from top-level .env):
#   SN_INSTANCE, SN_USERNAME, SN_PASSWORD

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PLAYBOOK="${REPO_ROOT}/setup/playbooks/setup_monitoring_stack.yml"
INVENTORY="${REPO_ROOT}/setup/playbooks/inventory/hosts.yml"

if [[ -f "${REPO_ROOT}/.env" ]]; then
  echo "Loading environment from ${REPO_ROOT}/.env"
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"
  set +a
fi

if [[ ! -f "${INVENTORY}" ]]; then
  echo "Error: Inventory not found at ${INVENTORY}"
  echo "Run 'terraform apply' in setup/terraform/ first."
  exit 1
fi

ansible-playbook "${PLAYBOOK}" -i "${INVENTORY}" "$@"
