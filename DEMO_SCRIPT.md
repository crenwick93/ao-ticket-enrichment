# Demo Script — AO Ticket Enrichment

## Pre-Demo Checklist

- [ ] EC2 instance running, nginx serving at `http://<EC2_IP>`
- [ ] Prometheus targets all green at `http://<EC2_IP>:9090/targets`
- [ ] AAP objects created, EDA rulebook activation enabled
- [ ] AO workflow imported and published
- [ ] ServiceNow PDI is clean (no old incidents)
- [ ] Terminal ready with `.env` sourced: `set -a && source .env && set +a`
- [ ] Browser tabs: nginx page, Prometheus, AAP Jobs, AO Executions, ServiceNow Incidents

---

## Scene 1: The Setup (30 seconds)

**Show:** nginx hello-world page + Prometheus targets

> "RHEL 9 instance running nginx, monitored by Prometheus and AlertManager.
> When nginx goes down, an alert fires, creates a ServiceNow incident,
> and Automation Orchestrator enriches it with AI-driven root cause analysis."

---

## Scene 2: Break nginx (15 seconds)

```bash
./scripts/break-nginx.sh
```

> "Bad config directive injected — simulating a failed deployment."

---

## Scene 3: Alert Chain Fires (30 seconds)

**Show:** Prometheus → Alerts (firing), then ServiceNow → new incident

> "Prometheus detected nginx is down. AlertManager fired the alert,
> webhook bridge created the ServiceNow incident with the host IP
> and alert details."

---

## Scene 4: AO Workflow (90 seconds)

**Show:** AAP Jobs → bridge job, then AO Executions → workflow

1. **Gather Diagnostics** (green):
   > "SSHs to the host, collects nginx status, config test, journal logs,
   > failed units, system health. Everything the AI needs."

2. **AI: Root Cause Analysis** (running):
   > "The AI agent reads the incident and diagnostics. It identifies the
   > bad directive, explains why nginx failed, and suggests the fix."

3. **Update SNOW Ticket** (green):
   > "The incident is updated with the full RCA — root cause, evidence,
   > remediation steps, and prevention advice."

**Switch to:** ServiceNow → incident work notes → show AI analysis

---

## Scene 5: Manual Fix (15 seconds)

```bash
./scripts/fix-nginx.sh
```

> "Fix applied. In a production scenario, the operations team follows
> the AI's remediation steps. The incident has everything they need."

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Time from failure to enriched ticket | ~2 minutes |
| Manual steps | 0 |
| ServiceNow updates | 1 (AI root cause analysis) |
