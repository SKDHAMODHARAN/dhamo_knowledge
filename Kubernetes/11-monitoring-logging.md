# 11 — Monitoring & Logging

## Why Monitoring Matters

```text
Think of it as: DASHBOARDS IN A CAR

  Without monitoring:
    You're driving blindfolded. 🙈
    "Is the engine overheating? Am I running out of fuel? How fast am I going?"
    You find out ONLY when the car breaks down.

  With monitoring:
    Speedometer (request rate), temperature gauge (CPU), fuel gauge (memory),
    engine warning light (error alerts).
    You see problems BEFORE they become outages.

  ┌─────────────────────────────────────────────────────────────────┐
  │                    OBSERVABILITY STACK                          │
  │                                                                 │
  │   METRICS (Numbers over time)          LOGS (Text events)       │
  │   "CPU is at 85%"                      "Error: DB timeout"      │
  │   "Request latency: 200ms"             "User login failed"      │
  │   Tool: Prometheus + Grafana           Tool: EFK / Loki         │
  │                                                                 │
  │                    TRACES (Request flow)                        │
  │                    "Request went: API → Auth → DB → Response"  │
  │                    Tool: Jaeger / Tempo                         │
  └─────────────────────────────────────────────────────────────────┘
```

---

## The Three Pillars

| Pillar | What | When | Tool |
|--------|------|------|------|
| **Metrics** | Numbers: CPU, memory, request count, latency | "Is the system healthy right now?" | Prometheus + Grafana |
| **Logs** | Text: error messages, events, debug output | "What happened and why?" | EFK stack or Loki |
| **Traces** | Request paths across services | "Where is this request slow?" | Jaeger or Tempo |

---

## Prometheus — Metrics Collection

```text
Think of it as: A HEALTH INSPECTOR that visits every restaurant every 30 seconds

  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  Prometheus pulls metrics from every component:              │
  │                                                              │
  │  ┌────────────┐   ┌────────────┐   ┌────────────────┐       │
  │  │ Your App   │   │ Node       │   │ K8s API Server │       │
  │  │ :8080      │   │ Exporter   │   │                │       │
  │  │ /metrics   │   │ :9100      │   │ /metrics       │       │
  │  └─────┬──────┘   └─────┬──────┘   └──────┬─────────┘       │
  │        │                │                  │                  │
  │        └────────────────┼──────────────────┘                  │
  │                         │                                     │
  │                  ┌──────▼──────┐                               │
  │                  │ PROMETHEUS  │ ← Scrapes /metrics endpoints  │
  │                  │             │   every 15-30 seconds          │
  │                  │ Stores time │                               │
  │                  │ series data │                               │
  │                  └──────┬──────┘                               │
  │                         │                                     │
  │                  ┌──────▼──────┐                               │
  │                  │  GRAFANA    │ ← Beautiful dashboards        │
  │                  │  📊📈       │   and alerts                   │
  │                  └─────────────┘                               │
  └──────────────────────────────────────────────────────────────┘

  Pull model: Prometheus PULLS data from your apps.
  Your app exposes a /metrics endpoint with data like:
    http_requests_total{method="GET", path="/api/users"} 1542
    http_request_duration_seconds{quantile="0.95"} 0.230
```

### Install with Helm (Recommended)

```bash
# Install Prometheus + Grafana + Alertmanager in one command
helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo update

helm install monitoring prometheus/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=30d
```

### What You Get Out of the Box

```text
After installing kube-prometheus-stack:

  ✅ Prometheus (scrapes metrics from all K8s components)
  ✅ Grafana (pre-built dashboards for K8s)
  ✅ Alertmanager (sends alerts to Slack, PagerDuty, email)
  ✅ Node Exporter (hardware/OS metrics from every node)
  ✅ kube-state-metrics (K8s object metrics)
  ✅ Pre-configured alert rules (node down, pod crash loops, etc.)
```

---

## Key Metrics to Watch

### Cluster-Level

| Metric | What It Tells You | Alert When |
|--------|------------------|-----------|
| Node CPU usage | Are nodes overloaded? | > 80% sustained |
| Node memory usage | Are nodes running out of RAM? | > 85% |
| Node disk usage | Storage filling up? | > 80% |
| Pod restart count | Crash loops? | > 3 in 5 min |
| Pending Pods | Not enough resources? | Any Pod pending > 5 min |

### Application-Level (The Four Golden Signals)

```text
  Google's SRE book defines 4 signals you MUST monitor:

  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  1. LATENCY — How long requests take                         │
  │     "p95 response time is 200ms"                             │
  │     Alert: p95 > 500ms                                       │
  │                                                              │
  │  2. TRAFFIC — How much demand (requests per second)          │
  │     "Serving 1000 req/s"                                     │
  │     Alert: Unusual spike or drop                             │
  │                                                              │
  │  3. ERRORS — Rate of failed requests                         │
  │     "0.5% of requests return 5xx"                            │
  │     Alert: Error rate > 1%                                   │
  │                                                              │
  │  4. SATURATION — How "full" the system is                    │
  │     "CPU at 70%, memory at 65%"                              │
  │     Alert: > 80% sustained                                   │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘
```

### Expose Metrics From Your App

```yaml
# ServiceMonitor tells Prometheus where to scrape
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app-monitor
  namespace: monitoring
  labels:
    release: monitoring         # Must match Prometheus selector
spec:
  namespaceSelector:
    matchNames:
      - default
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

---

## Grafana — Dashboards & Visualization

```text
  Grafana turns Prometheus data into visual dashboards:

  ┌──────────────────────────────────────────────────────────────┐
  │  My App Dashboard                                    🔄 5m   │
  │                                                              │
  │  Requests/sec        Error Rate          p95 Latency         │
  │  ┌──────────┐        ┌──────────┐        ┌──────────┐       │
  │  │ 📈 1,250  │        │ 📊 0.3%  │        │ 📉 180ms │       │
  │  │          │        │          │        │          │       │
  │  └──────────┘        └──────────┘        └──────────┘       │
  │                                                              │
  │  CPU Usage (by Pod)              Memory Usage (by Pod)       │
  │  ┌────────────────────┐          ┌────────────────────┐     │
  │  │ ████████░░ 78%     │          │ ██████░░░░ 55%     │     │
  │  │ ████░░░░░░ 42%     │          │ ████████░░ 72%     │     │
  │  │ ██████░░░░ 61%     │          │ ██████░░░░ 58%     │     │
  │  └────────────────────┘          └────────────────────┘     │
  └──────────────────────────────────────────────────────────────┘
```

```bash
# Access Grafana dashboard
kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring

# Open http://localhost:3000
# Login: admin / admin (or your configured password)
```

### Recommended Pre-Built Dashboards

| Dashboard ID | Name | Shows |
|-------------|------|-------|
| 315 | Kubernetes Cluster | Overall cluster health |
| 6417 | Kubernetes Pods | Per-Pod CPU, memory, network |
| 1860 | Node Exporter Full | Detailed node metrics |
| 7249 | K8s Cluster Summary | Namespace-level overview |

---

## Alerting — Prometheus AlertManager

```yaml
# PrometheusRule — define alert conditions
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: app-alerts
  namespace: monitoring
  labels:
    release: monitoring
spec:
  groups:
    - name: application
      rules:
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            / sum(rate(http_requests_total[5m])) > 0.01
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "High error rate detected"
            description: "Error rate is {{ $value | humanizePercentage }} (threshold: 1%)"

        - alert: PodCrashLooping
          expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} is crash looping"

        - alert: HighMemoryUsage
          expr: |
            container_memory_working_set_bytes
            / container_spec_memory_limit_bytes > 0.85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "Pod {{ $labels.pod }} memory usage > 85%"
```

### Alert Routing (Slack Example)

```yaml
# AlertManager config — where to send alerts
apiVersion: v1
kind: Secret
metadata:
  name: alertmanager-config
  namespace: monitoring
stringData:
  alertmanager.yaml: |
    route:
      receiver: 'slack'
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - match:
            severity: critical
          receiver: 'pagerduty'

    receivers:
      - name: 'slack'
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
            channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
            text: '{{ .CommonAnnotations.description }}'

      - name: 'pagerduty'
        pagerduty_configs:
          - service_key: 'YOUR_PAGERDUTY_KEY'
```

---

## Logging — Collecting Application Logs

### Option 1: EFK Stack (Elasticsearch + Fluentd + Kibana)

```text
  ┌──────────────────────────────────────────────────────────────┐
  │                      EFK STACK                               │
  │                                                              │
  │  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐    │
  │  │ Pod     │   │ Pod     │   │ Pod     │   │ Pod     │    │
  │  │ (logs)  │   │ (logs)  │   │ (logs)  │   │ (logs)  │    │
  │  └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘    │
  │       │              │              │              │         │
  │       └──────────────┼──────────────┼──────────────┘         │
  │                      │              │                        │
  │              ┌───────▼──────────────▼──────┐                 │
  │              │       FLUENTD               │                 │
  │              │   (DaemonSet on every node) │                 │
  │              │   Collects, parses, ships   │                 │
  │              └────────────┬────────────────┘                 │
  │                           │                                  │
  │              ┌────────────▼────────────────┐                 │
  │              │     ELASTICSEARCH           │                 │
  │              │   (Stores & indexes logs)   │                 │
  │              └────────────┬────────────────┘                 │
  │                           │                                  │
  │              ┌────────────▼────────────────┐                 │
  │              │        KIBANA               │                 │
  │              │   (Search & visualize logs) │                 │
  │              └─────────────────────────────┘                 │
  └──────────────────────────────────────────────────────────────┘
```

### Option 2: Loki + Grafana (Lighter Alternative)

```text
  Loki is like "Prometheus but for logs."
  Much lighter than Elasticsearch. Uses the same Grafana for viewing.

  ┌────────────────────────────────────────────┐
  │  Pods → Promtail (DaemonSet) → Loki → Grafana  │
  └────────────────────────────────────────────┘
```

```bash
# Install Loki with Helm
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set grafana.enabled=false \
  --set promtail.enabled=true
```

### Logging Best Practices

| Practice | Why |
|----------|-----|
| **Log as JSON** | Machine-parseable, easy to query in Kibana/Grafana |
| **Include request ID** | Trace requests across services |
| **Use log levels** | ERROR, WARN, INFO, DEBUG — filter by severity |
| **Don't log secrets** | Passwords, tokens, PII must never appear in logs |
| **Set log rotation** | Prevent disk from filling up |
| **Centralize logs** | Don't SSH into Pods to read logs — use a central system |

### Structured Logging Example

```json
{
  "timestamp": "2025-02-25T10:30:00Z",
  "level": "ERROR",
  "service": "user-api",
  "request_id": "req-abc-123",
  "message": "Failed to connect to database",
  "error": "connection timeout after 5s",
  "pod": "user-api-6d4f7b-x2k9r",
  "namespace": "production"
}
```

---

## Quick Access to Logs via kubectl

```bash
# View logs from a Pod
kubectl logs <pod-name>

# Stream logs in real-time
kubectl logs -f <pod-name>

# Logs from previous crash (crashed container)
kubectl logs <pod-name> --previous

# Logs from specific container (multi-container pod)
kubectl logs <pod-name> -c <container-name>

# Last 100 lines
kubectl logs <pod-name> --tail=100

# Logs from last 30 minutes
kubectl logs <pod-name> --since=30m

# Logs from all Pods in a Deployment
kubectl logs deployment/web-app

# Logs with label selector
kubectl logs -l app=web-app --all-containers
```

---

## Monitoring Checklist for Production

```text
  ┌──────────────────────────────────────────────────────────────┐
  │  MONITORING CHECKLIST                                        │
  │                                                              │
  │  □ Prometheus installed and scraping all services            │
  │  □ Grafana dashboards for cluster, nodes, and apps           │
  │  □ AlertManager configured with Slack/PagerDuty              │
  │  □ Four golden signals monitored (latency, traffic,          │
  │    errors, saturation)                                       │
  │  □ Pod restart alerts configured                             │
  │  □ Centralized logging (EFK or Loki)                        │
  │  □ Structured JSON logging in all apps                       │
  │  □ Log retention policy set (30-90 days)                    │
  │  □ Resource usage dashboards per namespace/team              │
  │  □ Runbooks linked to each alert                            │
  └──────────────────────────────────────────────────────────────┘
```

---

## Test Your Understanding 🧪

1. **What are the three pillars of observability?**
2. **How does Prometheus collect metrics — push or pull?**
3. **What are Google's Four Golden Signals?**
4. **What's the difference between EFK and Loki?**
5. **Why should you log in JSON format?**

<details>
<summary>Click to see answers</summary>

1. **Metrics** (numbers over time — Prometheus), **Logs** (text events — EFK/Loki), and **Traces** (request flows across services — Jaeger/Tempo).

2. **Pull model.** Prometheus scrapes (pulls) metrics from /metrics endpoints on your applications at a regular interval (e.g., every 30 seconds).

3. **Latency** (how long requests take), **Traffic** (how many requests), **Errors** (how many requests fail), **Saturation** (how full the system is — CPU, memory, disk).

4. **EFK** (Elasticsearch + Fluentd + Kibana) is full-featured but resource-heavy — Elasticsearch needs significant CPU/memory. **Loki** is lighter, doesn't index log content (only labels), uses Grafana for UI. Loki is cheaper to run, EFK is more powerful for search.

5. JSON is machine-parseable. Log aggregation tools can automatically parse fields (timestamp, level, request_id) for filtering and querying. Plain text requires custom parsing rules.

</details>

---

## What's Next?

➡️ **[12 — Production Best Practices](./12-production-best-practices.md)** — Everything you need to go live
