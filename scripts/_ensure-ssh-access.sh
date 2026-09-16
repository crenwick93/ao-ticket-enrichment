#!/usr/bin/env bash
# Shared helper: ensures the demo security group allows SSH from the current IP.
# Source this from other scripts: source "${SCRIPT_DIR}/_ensure-ssh-access.sh"

ensure_ssh_access() {
  local region="$1" sg_id="$2"

  if [[ -z "$sg_id" || -z "$region" ]]; then
    echo "  [SKIP] No security group ID — cannot update SSH access"
    return 0
  fi

  local my_ip
  my_ip=$(curl -s --connect-timeout 5 https://checkip.amazonaws.com)
  if [[ -z "$my_ip" ]]; then
    echo "  [SKIP] Could not determine current IP"
    return 0
  fi

  local my_cidr="${my_ip}/32"

  # Check if current IP already has SSH access
  local existing
  existing=$(aws ec2 describe-security-groups \
    --region "$region" \
    --group-ids "$sg_id" \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`22\` && ToPort==\`22\`].IpRanges[].CidrIp" \
    --output text 2>/dev/null)

  if echo "$existing" | grep -qw "$my_cidr"; then
    echo "  SSH access: ${my_ip} already allowed"
    return 0
  fi

  echo "  IP changed — updating security group ${sg_id}..."

  # Remove old SSH rules
  for old_cidr in $existing; do
    aws ec2 revoke-security-group-ingress \
      --region "$region" \
      --group-id "$sg_id" \
      --protocol tcp \
      --port 22 \
      --cidr "$old_cidr" > /dev/null 2>&1 || true
  done

  # Add current IP
  aws ec2 authorize-security-group-ingress \
    --region "$region" \
    --group-id "$sg_id" \
    --protocol tcp \
    --port 22 \
    --cidr "$my_cidr" > /dev/null

  echo "  SSH access: updated to ${my_ip}"
}
