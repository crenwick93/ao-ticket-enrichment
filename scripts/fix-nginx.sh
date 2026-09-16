#!/usr/bin/env bash
set -euo pipefail

# Manually remove the bad directive and restart nginx.
# (The AO workflow should do this automatically — this script is for resets.)
#
# Usage:
#   ./scripts/fix-nginx.sh [SSH_KEY] [EC2_IP]

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
echo "║          Fixing nginx on ${EC2_IP}"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "ec2-user@${EC2_IP}" \
  'sudo sed -i "/unknown_directive/d" /etc/nginx/nginx.conf && sudo nginx -t && sudo systemctl restart nginx'

echo "  ✓ Bad directive removed"
echo "  ✓ nginx config validated"
echo "  ✓ nginx restarted"
echo ""
echo "  Prometheus will detect the recovery within ~15s"
echo ""
