<!-- Fill all placeholders; delete unused rows/sections. Keep it concise and production-oriented. -->

# <Service> — Complete Guide

## What It Is
- 2–3 lines describing the service, its role, and a simple metaphor (e.g., "like an air traffic tower").

## Core Capabilities
| # | Capability | What It Does | Example |
|---|------------|--------------|---------|
| 1 | <capability> | <behavior> | <concise example> |
| 2 | … | … | … |

## Flavors / SKUs (Compare)
| Variant | Cost/Perf Notes | Key Features | Best For |
|---------|-----------------|--------------|---------|
| <variant> | <cost/latency> | <features> | <when to choose> |

## Decision Tree
```
<yes/no branch text to pick a variant; keep to 3–5 lines>
```

## Request / Control Lifecycle
1) Client entrypoint (DNS, TLS, edge)  
2) AuthN/AuthZ checks  
3) Routing / matching  
4) Throttling / quotas  
5) Transform / enrich (if applicable)  
6) Backend integration / execution  
7) Response handling  
8) Logging / metrics emission  
(Tailor steps to the service; keep 6–10 steps.)

## Common Architecture Patterns
- Pattern: <Service → Backend>; When: <use case>; Why: <benefit>
- Include 3–7 patterns; optional small ASCII diagrams.

## Auth / Access Options
| Method | How It Works | Best For | Notes |
|--------|--------------|---------|-------|
| <IAM/JWT/Key/etc.> | <flow> | <fit> | <combine?/limits> |

## Security Best Practices (Opinionated)
- Enforce least privilege (e.g., IRSA, scoped policies).
- Require resource limits / validated inputs.
- Enable access logging / audit trails.
- Restrict network exposure; prefer private endpoints.
- Add WAF/policies where public-facing.
- Validate payload size/types; avoid `:latest`.

## Cost Mental Model
- Rough unit pricing: <numbers>.
- Cost drivers: <list>.
- Quick scenarios: <small table or bullets>.

## Monitoring & Observability
- Metrics to watch: <list 5–8>, suggest alert thresholds.
- Logs: recommended fields (requestId, status, latency, source IP, UA, backend status).
- Traces: where to sample/propagate (if relevant).

## Key Concepts Cheat Sheet
- <Term>: <short definition>
- 8–12 items; keep to one line each.

## Gotchas & Troubleshooting
| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| <issue> | <root cause> | <remediation> |

## Useful CLI/SDK Commands
```bash
# Replace with service-specific commands; keep copy/paste ready
```

## Further Reading
- Curate 5–7 links (official docs, best practices, limits/quotas, reference arch).
