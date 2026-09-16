# AO Ticket Enrichment Demo

AI-driven incident enrichment using **Automation Orchestrator (AO)**, **Event-Driven Ansible (EDA)**, and **ServiceNow**.

## Demo Scenario

1. An **nginx** EC2 instance serves a hello-world page, monitored by Prometheus + Node Exporter + AlertManager
2. A bad config change is introduced (`unknown_directive broken;` in `nginx.conf`) — simulating a bad deployment
3. nginx fails to start → Prometheus detects the service is down → AlertManager fires an alert
4. The webhook bridge creates a **ServiceNow incident**
5. **EDA rulebook** polls ServiceNow, detects the new incident, triggers the **AO workflow** via bridge job template
6. **AO workflow**: Gathers diagnostics from the host → AI agent performs root cause analysis → Updates ServiceNow with findings

## Architecture

```
nginx fails → Prometheus → AlertManager → Webhook Bridge → ServiceNow Incident
                                                                    │
                                                          EDA polls │
                                                                    ▼
                                                            EDA Rulebook
                                                                    │
                                                          triggers  │
                                                                    ▼
                                                            AO Workflow
                                                                    │
                                                    ┌───────────────┼───────────────┐
                                                    ▼               ▼               ▼
                                              Gather Diag     AI: Root Cause    Update SNOW
                                              (AAP Job)        Analysis         (AAP Job)
```

## Key Difference from ALIA Version

| | ALIA Version | AO Version (this project) |
|---|---|---|
| **Orchestration** | AAP Workflow (linear 3-step) | AO Workflow with AI agentic node |
| **AI** | ALIA API (single chat endpoint) | AO agentic node with MCP tools |
| **Flow** | CMDB Lookup → Diagnostics → ALIA Enrichment | Diagnostics → AI RCA → Update SNOW |

## Prerequisites

- AWS account with CLI configured
- Terraform >= 1.5
- Ansible (with `servicenow.itsm`, `infra.aap_configuration` collections)
- AAP 2.5+ with EDA and Automation Orchestrator
- ServiceNow developer instance

## Quick Start

### 1. Configure Environment

```bash
cp .env.example .env
# Edit .env with your AAP, ServiceNow, and AO credentials
```

### 2. Provision Infrastructure

```bash
cd setup/terraform
terraform init
terraform apply
cd ../..
```

### 3. Deploy Monitoring Stack

```bash
./setup/scripts/setup-apply.sh
```

### 4. Configure AAP (CaC — first pass)

```bash
./ansible_deployment/scripts/cac-apply.sh
```

### 5. Import AO Workflow

1. Import `ao/ticket-enrichment.json` into Automation Orchestrator
2. Publish the workflow — AO generates service account credentials
3. Copy `AO_WEBHOOK_PATH`, `AO_WEBHOOK_CLIENT_ID`, `AO_WEBHOOK_CLIENT_SECRET` into `.env`

### 6. Update AAP (CaC — second pass)

```bash
./ansible_deployment/scripts/cac-apply.sh
```

### 7. Run the Demo

```bash
# Break nginx
./scripts/break-nginx.sh

# Watch the chain:
# 1. Prometheus detects (within ~15s)
# 2. AlertManager fires → webhook bridge creates SNOW incident
# 3. EDA polls SNOW → triggers AO bridge job template
# 4. AO workflow: Diagnostics → AI RCA → Update SNOW

# Manual reset
./scripts/fix-nginx.sh
```

## Project Structure

```
ao-ticket-enrichment/
├── .env.example                          # Environment template
├── ansible.cfg
├── ao/
│   └── ticket-enrichment.json            # AO workflow (importable)
├── playbooks/
│   ├── trigger_ao_workflow.yml           # EDA-to-AO bridge (OAuth2)
│   ├── gather_diagnostics.yml            # SSH diagnostics (nginx)
│   └── update_snow_ticket.yml            # Update SNOW incident
├── rulebooks/
│   └── listen_snow_incidents.yml         # EDA: poll SNOW → trigger AO bridge
├── ansible_deployment/
│   ├── cac/
│   │   ├── apply.yml                     # CaC dispatch
│   │   ├── requirements.yml              # Collections
│   │   └── vars.yml                      # AAP + EDA objects
│   ├── ee/
│   │   └── decision-environment.yml      # DE for EDA
│   └── scripts/
│       └── cac-apply.sh
├── setup/
│   ├── terraform/                        # EC2 + VPC + Elastic IP
│   ├── playbooks/                        # Monitoring stack setup
│   └── scripts/
│       └── setup-apply.sh
└── scripts/
    ├── break-nginx.sh                    # Demo: inject bad directive
    └── fix-nginx.sh                      # Demo: remove bad directive
```

## Troubleshooting

### Prometheus not detecting the failure
- Check Prometheus targets: `http://<EC2_IP>:9090/targets`
- Verify node_exporter is collecting systemd metrics

### AlertManager not firing
- Check AlertManager alerts: `http://<EC2_IP>:9093/#/alerts`

### ServiceNow incident not created
- Check webhook bridge logs: `sudo journalctl -u snow-webhook -f`

### EDA not picking up incidents
- Check the EDA rulebook activation is enabled in the AAP UI

### AO workflow not triggering
- Verify the bridge job template ran successfully in AAP
- Check the AO webhook credentials (client_id/secret)
