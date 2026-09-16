# AO Ticket Enrichment — Requirements

## Infrastructure

| Component | Required | Notes |
|-----------|----------|-------|
| Ansible Automation Platform | Yes | 2.5+ with Automation Orchestrator |
| ServiceNow | Yes | Developer instance for incident management |
| AWS | Yes | EC2 instance for nginx monitoring demo |
| Terraform | Yes | >= 1.5 for infrastructure provisioning |

## RHEL Instance (AWS EC2)

A single RHEL 9 instance provisioned by Terraform, running:
- nginx (hello-world web server)
- Prometheus + Node Exporter (metrics)
- AlertManager (alerting)
- ServiceNow webhook bridge (incident creation)

## AAP Objects (created by CaC)

All objects are created by `ansible_deployment/scripts/cac-apply.sh`. After running CaC, AAP will contain:

| Object | Name | Notes |
|--------|------|-------|
| Custom Credential Type | `ServiceNow Credential` | Injects `SN_HOST`, `SN_USERNAME`, `SN_PASSWORD` env vars |
| Custom Credential Type | `AO Webhook Credential` | OAuth2 client creds for AO trigger |
| Credential | `ServiceNow ITSM` | ServiceNow Credential |
| Credential | `AAP Controller` | Red Hat AAP — internal API |
| Credential | `AO Webhook` | AO Webhook Credential |
| Credential | `Monitoring SSH` | Machine — ec2-user |
| Project | `AO Ticket Enrichment Demo` | This repo |
| Job Template | `AO Ticket Enrichment Bridge` | EDA-to-AO bridge (OAuth2) |
| Job Template | `Gather Diagnostics` | SSH diagnostics (nginx, systemd, journal) |
| Job Template | `Update SNOW Ticket` | Update incident work notes + state |
| EDA Decision Environment | `snow-de` | `quay.io/crenwick93/snow-de:latest` |
| EDA Project | `AO Ticket Enrichment Demo` | This repo |
| EDA Rulebook Activation | `snow-incidents` | `listen_snow_incidents.yml` |

## AO Configuration

After importing `ao/ticket-enrichment.json`, configure:

| Placeholder | Description |
|-------------|-------------|
| Model credential | AO credential for the LLM used by AI agent nodes |
| AAP credential | AO credential for AAP job template execution |

Configure MCP integrations on AI agent nodes:
- **ServiceNow MCP**: Incident read/update operations
- **AAP MCP**: Job template discovery and inventory lookup

## AO EDA Trigger Setup

After publishing the AO workflow with an EDA trigger:

1. AO generates an **Authorised Service Account** with `client_id` and `client_secret`
2. Copy these into `.env` as `AO_WEBHOOK_CLIENT_ID` and `AO_WEBHOOK_CLIENT_SECRET`
3. Copy the webhook path into `.env` as `AO_WEBHOOK_PATH`
4. Re-run `cac-apply.sh` to update the bridge job template and EDA activation

See: [Red Hat docs — Add an Event-Driven Ansible trigger](https://docs.redhat.com/en/documentation/automation_orchestrator/2026.8/develop-add_an_event_driven_ansible_trigger)
