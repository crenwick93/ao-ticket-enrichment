# AO Ticket Enrichment Demo

AI-driven incident enrichment and remediation using **Automation Orchestrator (AO)**, **Event-Driven Ansible (EDA)**, and **ServiceNow**.

## Overview

Two AO workflows demonstrate progressive automation:

1. **Ticket Enrichment** (`ao/ticket-enrichment.json`) — Gathers diagnostics → AI root cause analysis → Updates ServiceNow with findings
2. **Ticket Enrichment + Remediation** (`ao/ticket-enrichment-remediation.json`) — Same as above, plus AI searches the AAP automation catalog for a fix, runs it, and resolves the incident

Switch between workflows by changing the `webhook_path` in the EDA rulebook activation's extra vars.

## Demo Scenario

1. An **nginx** EC2 instance serves a hello-world page, monitored by Prometheus + Node Exporter + AlertManager
2. A bad config change is introduced (`unknown_directive broken;` in `nginx.conf`) — simulating a bad deployment
3. nginx fails to start → Prometheus detects → AlertManager fires → Webhook bridge creates **ServiceNow incident**
4. **EDA rulebook** polls ServiceNow, detects the new incident, triggers the **AO workflow** via bridge job template
5. **AO workflow** runs: gathers diagnostics, AI analyses root cause, updates/resolves the ServiceNow incident

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
```

### Workflow 1: Enrichment Only

```
Gather Diagnostics → AI: Root Cause Analysis → Update SNOW (RCA)
```

### Workflow 2: Enrichment + Remediation

```
Gather Diagnostics → AI: RCA → Update SNOW (RCA) → AI: Search Automation Catalog → Remediation Available?
                                                                                      ╱              ╲
                                                                               Remediation      No Remediation
                                                                                  Found           Available
                                                                                    ↓                  ↓
                                                                             Run Remediation      Update SNOW
                                                                        (dynamic template name)  (No Remediation)
                                                                                    ↓
                                                                              Update SNOW
                                                                             (Remediated)
```

## Key Differences from ALIA Version

| | ALIA Version | AO Version (this project) |
|---|---|---|
| **Orchestration** | AAP Workflow (linear 3-step) | AO Workflow with AI agentic nodes |
| **AI** | ALIA API (single chat endpoint) | AO agentic nodes (LLM + MCP tools) |
| **Flow** | CMDB Lookup → Diagnostics → ALIA Enrichment | Diagnostics → AI RCA → Update SNOW |
| **Remediation** | Manual (AI suggests, human acts) | AI searches automation catalog and runs fix |

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

1. Import `ao/ticket-enrichment.json` (or `ticket-enrichment-remediation.json`) into Automation Orchestrator
2. Configure model credential and AAP MCP tools on agentic nodes
3. Publish the workflow — AO generates service account credentials
4. Copy `AO_WEBHOOK_PATH`, `AO_WEBHOOK_CLIENT_ID`, `AO_WEBHOOK_CLIENT_SECRET` into `.env`

### 6. Update AAP (CaC — second pass)

```bash
./ansible_deployment/scripts/cac-apply.sh
```

### 7. Run the Demo

```bash
# Break nginx
./scripts/break-nginx.sh

# Manual reset
./scripts/fix-nginx.sh
```

See `DEMO_SCRIPT.md` for a full step-by-step walkthrough.

## Project Structure

```
ao-ticket-enrichment/
├── .env.example                          # Environment template
├── ansible.cfg
├── ao/
│   ├── ticket-enrichment.json            # AO workflow: enrichment only
│   └── ticket-enrichment-remediation.json # AO workflow: enrichment + remediation
├── playbooks/
│   ├── trigger_ao_workflow.yml           # EDA-to-AO bridge (OAuth2)
│   ├── gather_diagnostics.yml            # SSH diagnostics (nginx)
│   ├── update_snow_ticket.yml            # Update SNOW incident
│   └── rollback_nginx_config.yml         # Remediation: fix bad nginx config
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
├── scripts/
│   ├── break-nginx.sh                    # Demo: inject bad directive
│   └── fix-nginx.sh                      # Demo: remove bad directive
├── DEMO_SCRIPT.md                        # Step-by-step demo walkthrough
├── REQUIREMENTS.md                       # Infrastructure & AAP objects reference
└── workflow.mermaid                      # Architecture diagram
```

## Important Notes

### Environment Variables
- The project supports both `SERVICENOW_*` and `SN_*` env var naming (for compatibility with other projects)
- `MONITORING_HOST_IP` is auto-populated by Terraform but must exist in `.env` beforehand

### ServiceNow PDI
- The `close_code` for resolving incidents is `"Solution provided"` (PDI-specific, not `"Solved (Permanently)"`)
- The `update_snow_ticket.yml` playbook handles resolve as a two-step operation: add work notes first, then resolve

### EDA Activation
- The EDA activation cannot be updated by CaC while running — disable/re-enable manually in the AAP UI
- Remove any event streams (e.g. Lightspeed CVE Events) from the activation — it uses the `servicenow.itsm.records` source plugin
- The EDA controller credential needs the `/api/controller/` path suffix for AAP 2.5+

### Switching Workflows
- To switch between enrichment and remediation workflows, change `webhook_path` in the EDA activation extra vars to match the target workflow's trigger UUID
- Restart the activation after changing

### AI Agent Configuration in AO
- **AI: Root Cause Analysis** — model credential only, no MCP tools. Response schema: `{ "analysis": "string" }`. Output referenced as `${rca_agent.result.content.analysis}`
- **AI: Search Automation Catalog** (remediation only) — model credential + AAP MCP tools. Response schema: `{ "fix_available": "yes|no", "fix_template_name": "string", "fix_reason": "string" }`. Output referenced as `${select_fix_agent.result.content.fix_template_name}`

## Troubleshooting

### Prometheus not detecting the failure
- Check Prometheus targets: `http://<EC2_IP>:9090/targets`
- Verify node_exporter is collecting systemd metrics

### AlertManager not firing
- Check AlertManager alerts: `http://<EC2_IP>:9093/#/alerts`

### ServiceNow incident not created
- Check webhook bridge logs: `sudo journalctl -u snow-webhook -f`
- Verify the SERVICENOW_INSTANCE_URL is correct in `.env` and was set when setup-apply.sh ran

### EDA not picking up incidents
- Check the EDA rulebook activation is enabled and running in the AAP UI
- Ensure ServiceNow EDA credential is attached (not just AAP Controller Token)
- Ensure no event streams are attached to the activation
- Check EDA logs for `404` errors — the controller credential needs `/api/controller/` path

### AO workflow not triggering
- Verify the bridge job template ran successfully in AAP
- Check the AO webhook credentials (client_id/secret)
- Verify `webhook_path` in EDA activation matches the AO workflow trigger

### Update SNOW Ticket failing on resolve
- The PDI uses `close_code: "Solution provided"` — not `"Solved (Permanently)"`
- Resolve is a two-step operation in the playbook: work notes first, then state change
