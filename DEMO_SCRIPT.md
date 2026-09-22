# Demo Script — AO Ticket Enrichment

## Pre-Demo Checklist

- [ ] EC2 instance running, nginx healthy: http://108.131.238.127
- [ ] Prometheus targets green: http://108.131.238.127:9090/targets
- [ ] EDA rulebook activation running in AAP
- [ ] AO workflow published
- [ ] ServiceNow PDI clean (resolve/delete old demo incidents)
- [ ] Browser tabs ready:
  - Terminal (SSH)
  - Prometheus Alerts: http://108.131.238.127:9090/alerts
  - AAP Jobs
  - AO Executions
  - ServiceNow Incidents

---

## Scene 1: Show the Healthy State (60 seconds)

**Browser → http://108.131.238.127**

> "We have a RHEL 9 instance running nginx, serving a simple web page.
> It's monitored by Prometheus with a 15-second alert rule — if nginx
> goes down, the full chain fires automatically."

**Browser → http://108.131.238.127:9090/targets**

> "Prometheus is scraping Node Exporter every 10 seconds. All targets healthy."

**Browser → http://108.131.238.127:9090/alerts**

> "Our `ServiceDown_nginx` alert is currently green — inactive."

---

## Scene 2: Break nginx — Simulate a Bad Deployment (30 seconds)

**Terminal — SSH to the instance:**

```bash
ssh -i setup/terraform/demo-key.pem ec2-user@108.131.238.127
```

**Show the current healthy config:**

```bash
sudo nginx -t
# nginx: configuration file /etc/nginx/nginx.conf syntax is ok
```

**Inject the bad directive:**

```bash
sudo sh -c 'echo "unknown_directive broken;" >> /etc/nginx/nginx.conf'
sudo systemctl restart nginx
# Job for nginx.service failed...
```

> "I've added a bad directive to nginx.conf — simulating a developer
> pushing a broken config change. nginx can't start."

**Verify it's broken:**

```bash
sudo systemctl status nginx --no-pager
# Active: failed
sudo nginx -t
# nginx: [emerg] unknown directive "unknown_directive"
```

**Stay on SSH — leave the terminal visible.**

---

## Scene 3: Watch Prometheus Detect (30 seconds)

**Browser → http://108.131.238.127:9090/alerts**

> "Within 15 seconds, Prometheus detects nginx.service is down.
> The `ServiceDown_nginx` alert goes to PENDING, then FIRING."

**Wait for the alert to go red/firing.** Refresh the page if needed.

> "AlertManager receives the alert and fires it to our webhook bridge,
> which creates a ServiceNow incident automatically."

---

## Scene 4: Show the ServiceNow Incident (30 seconds)

**Browser → ServiceNow → Incidents → newest incident**

> "Here's the incident — created automatically by the webhook bridge.
> Short description says 'systemd service nginx.service is down',
> and the description includes the affected host IP."

**Point out:**
- Impact: 1 - High
- Urgency: 1 - High
- Description mentions "Affected host IP: 108.131.238.127"

> "Now Event-Driven Ansible is polling ServiceNow. It picks up this
> new incident and triggers the AO workflow."

---

## Scene 5: Show the AO Workflow Running (90 seconds)

**Browser → AAP → Jobs**

> "The bridge job template has fired — it authenticated with AO using
> OAuth2 and posted the incident event to the workflow trigger."

**Browser → AO → Executions → click the running workflow**

> "Here's the AO workflow — three steps."

**As nodes complete:**

1. **Gather Diagnostics** (green):
   > "This SSHed to the host, ran `nginx -t`, collected journal logs,
   > systemd status, and system health. All the evidence the AI needs."

2. **AI: Root Cause Analysis** (running):
   > "The AI agent receives the diagnostics and the incident details.
   > It analyses the logs, identifies the root cause, and writes up
   > remediation steps — all formatted as HTML for ServiceNow."

3. **Update SNOW Ticket** (green):
   > "The incident is updated with the AI's analysis and moved to
   > In Progress."

---

## Scene 6: Show the Enriched Ticket (60 seconds)

**Browser → ServiceNow → refresh the incident → scroll to Work Notes**

> "Here's the AI root cause analysis — posted automatically."

**Walk through the work note:**

- **Root Cause Analysis**: "configuration error in nginx.conf, unknown directive on line 38"
- **Evidence from Logs**: actual log excerpt showing the `[emerg]` error
- **Remediation Steps**: specific commands — edit the config, run `nginx -t`, restart
- **Prevention Recommendations**: config validation, staging environment, linting

> "The operations team now has everything they need to fix this.
> Root cause identified, evidence cited, exact commands to resolve,
> and advice on preventing it happening again — all within about
> 90 seconds of the failure occurring."

---

## Scene 7: Fix it (optional, 15 seconds)

**Terminal (still SSH'd):**

```bash
sudo sed -i '/unknown_directive/d' /etc/nginx/nginx.conf
sudo nginx -t
# syntax is ok
sudo systemctl restart nginx
# nginx is back
exit
```

**Browser → http://108.131.238.127 → page loads again**

> "Fixed. In production, the team would follow the AI's remediation
> steps. The incident has the full audit trail."

---

## Key Numbers

| Metric | Value |
|--------|-------|
| Time from failure to enriched ticket | ~90 seconds |
| Manual steps | 0 |
| ServiceNow work note updates | 1 (AI root cause analysis) |
| Components in the chain | 7 (nginx → Prometheus → AlertManager → Webhook → SNOW → EDA → AO) |

---

## Quick Reset Between Demos

```bash
# From your laptop (not SSH'd)
./scripts/fix-nginx.sh

# Wait 30 seconds for Prometheus to see recovery, then:
./scripts/break-nginx.sh
```

Or manually via SSH as shown in Scene 2 for a more natural demo feel.
