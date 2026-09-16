#!/usr/bin/env bash
set -euo pipefail

# Inject a bad directive into nginx.conf to trigger the alert chain.
#
# Usage:
#   ./scripts/break-nginx.sh [SSH_KEY] [EC2_IP]
#
# If no arguments, reads from .env (MONITORING_HOST_IP) and looks for the Terraform key.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if [[ -f "${REPO_ROOT}/.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"
  set +a
fi

SSH_KEY="${1:-${REPO_ROOT}/setup/terraform/demo-key.pem}"
EC2_IP="${2:-${MONITORING_HOST_IP:-}}"

if [[ -z "$EC2_IP" ]]; then
  echo "ERROR: No EC2 IP. Pass as arg or set MONITORING_HOST_IP in .env"
  exit 1
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          Breaking nginx on ${EC2_IP}"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ec2-user@${EC2_IP}" \
  'sudo sh -c "echo \"unknown_directive broken;\" >> /etc/nginx/nginx.conf && systemctl restart nginx || true"'

echo "  ✓ Bad directive injected into /etc/nginx/nginx.conf"
echo "  ✓ nginx should now be failing"
echo ""
echo "  What happens next:"
echo "    1. Prometheus detects within ~15s"
echo "    2. AlertManager fires → webhook bridge → SNOW incident"
echo "    3. EDA polls SNOW → triggers AO bridge"
echo "    4. AO: AI Triage → Route → Diagnostics → RCA → Fix → Resolve"
echo ""
