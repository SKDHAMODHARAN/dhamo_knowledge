# AWS API Gateway — Complete Guide

## What is API Gateway?

API Gateway is a **managed service** that acts as a smart front door for your backend services.

Think of it like a **hotel reception desk**:

- Guests (clients) don't walk directly into hotel rooms (backends)
- They go through the reception (API Gateway), which checks who they are, directs them to the right room, and enforces rules

```text
Without API Gateway:
  Client ──────────────────────────→ Backend Service (exposed directly)
                                      ❌ No rate limiting
                                      ❌ No access control
                                      ❌ No logging
                                      ❌ No payload validation

With API Gateway:
  Client ───→ API Gateway ───→ Backend Service
                  ✅ Rate limiting
                  ✅ IP restrictions
                  ✅ Payload size checks
                  ✅ Access logging
                  ✅ TLS termination
                  ✅ Request transformation
```

---

## 6 Core Capabilities

| # | Capability         | What It Does                                              | Example                                                    |
|---|-------------------|----------------------------------------------------------|-----------------------------------------------------------|
| 1 | **Routing**        | Direct requests to the right backend based on URL path    | `POST /v1/users` → Lambda, `POST /v1/events` → SQS       |
| 2 | **Security**       | Control WHO can access your API                           | IAM auth, API keys, Lambda authorizers, IP restrictions    |
| 3 | **Throttling**     | Prevent abuse by limiting request rate                    | Burst: 5000 req/s, Sustained: 10000 req/s                 |
| 4 | **Transformation** | Change request/response format before forwarding          | Base64 encode binary, add headers, reshape JSON            |
| 5 | **Monitoring**     | Log and alert on every request                            | CloudWatch access/execution logs, 4xx/5xx alarms           |
| 6 | **Integration**    | Connect directly to AWS services without a server         | API Gateway → SQS, DynamoDB, S3, Kinesis, Step Functions   |

---

## AWS API Gateway: Three Types

### REST API (v1)

| Attribute             | Details                                                   |
|-----------------------|----------------------------------------------------------|
| **Cost**              | ~$3.50 per million requests                               |
| **Latency**           | ~10-30ms overhead                                         |
| **VTL Templates**     | ✅ Yes — full request/response transformation              |
| **Resource Policies** | ✅ Yes — IP-based access control                           |
| **Binary Support**    | ✅ Full control (base64 encode/decode)                     |
| **Auth Options**      | IAM, Cognito, Lambda Authorizer, API Keys                 |
| **Best For**          | Complex transformations, binary data, fine-grained security|

### HTTP API (v2)

| Attribute             | Details                                                   |
|-----------------------|----------------------------------------------------------|
| **Cost**              | ~$1.00 per million requests                               |
| **Latency**           | ~5-10ms overhead                                          |
| **VTL Templates**     | ❌ No                                                      |
| **Resource Policies** | ❌ No                                                      |
| **Binary Support**    | ⚠️ Limited                                                |
| **Auth Options**      | JWT (Cognito/OIDC), IAM                                   |
| **Best For**          | Simple proxy/passthrough, cost-sensitive, low-latency      |

### WebSocket API

| Attribute  | Details                                                            |
|------------|--------------------------------------------------------------------|
| **Cost**   | ~$1.00 per million messages + connection minutes                   |
| **Best For** | Real-time bidirectional communication (chat, live dashboards)    |

### When to Choose Which?

```text
Do I need VTL templates, resource policies, or binary transformation?
├── YES → REST API (v1)
└── NO
    ├── Do I need WebSocket (bidirectional real-time)?
    │   └── YES → WebSocket API
    └── NO → HTTP API (v2) — cheaper and faster
```

---

## Request Lifecycle

What happens when a client calls your API Gateway:

```text
 1. CLIENT sends request
    POST https://api.example.com/v1/resource
         │
         ▼
 2. DNS RESOLUTION
    Route53 (or other DNS) resolves domain to API Gateway endpoint
         │
         ▼
 3. TLS TERMINATION
    ACM certificate handles HTTPS → decrypts the request
         │
         ▼
 4. RESOURCE POLICY (REST API v1 only)
    Checks source IP against allowed/denied CIDRs
    ├── Denied  → 403 Forbidden
    └── Allowed → continue
         │
         ▼
 5. AUTHENTICATION
    Validates credentials (IAM, JWT, API Key, Lambda Authorizer)
    ├── Invalid → 401 Unauthorized / 403 Forbidden
    └── Valid   → continue
         │
         ▼
 6. ROUTING
    Matches HTTP method + path to configured resource/method
    ├── No match → 404 / "Missing Authentication Token" (REST v1 quirk)
    └── Match    → continue
         │
         ▼
 7. THROTTLING
    Checks against rate limits (burst + sustained)
    ├── Exceeded → 429 Too Many Requests
    └── OK       → continue
         │
         ▼
 8. REQUEST TRANSFORMATION (REST API v1 only)
    VTL template transforms request before forwarding to backend
    (reshape JSON, encode binary, add attributes, validate size)
         │
         ▼
 9. BACKEND INTEGRATION
    Forwards to: Lambda / SQS / DynamoDB / HTTP endpoint / etc.
    Backend processes and returns response
         │
         ▼
10. RESPONSE TRANSFORMATION (REST API v1 only)
    VTL template transforms backend response before returning to client
         │
         ▼
11. CLIENT receives HTTP response

12. ACCESS LOG written to CloudWatch
    (requestId, status, path, sourceIp, latency, errors)
```

---

## Common Architecture Patterns

### Pattern 1: API Gateway → Lambda (Most Common)

```text
Client → API Gateway → Lambda → DynamoDB / RDS / etc.
```

- **Use case:** REST/CRUD APIs, webhooks, server-side rendering
- **Example:** User registration API, payment webhook receiver, product catalog
- **When:** You need custom business logic per request

### Pattern 2: API Gateway → SQS (Async Ingestion)

```text
Client → API Gateway → SQS → Lambda (consumer) → Backend
```

- **Use case:** High-throughput async ingestion, decoupled processing
- **Example:** Telemetry/event collection, IoT data intake, form submissions
- **When:** Client doesn't need immediate processing result (fire-and-forget)
- **Why:** Client gets `202 Accepted` immediately, processing happens async

### Pattern 3: API Gateway → Step Functions

```text
Client → API Gateway → Step Functions → (multiple services)
```

- **Use case:** Complex multi-step workflows
- **Example:** Order processing, document approval pipeline, multi-step onboarding
- **When:** Processing involves branching, retries, human approval, or orchestration

### Pattern 4: API Gateway → Kinesis

```text
Client → API Gateway → Kinesis Data Stream → Consumer(s)
```

- **Use case:** Real-time streaming at massive scale
- **Example:** Clickstream analytics, real-time fraud detection, live dashboards
- **When:** Multiple consumers need the same data stream simultaneously

### Pattern 5: API Gateway → HTTP Backend (Proxy)

```text
Client → API Gateway → ALB/NLB → EC2 / ECS / EKS
```

- **Use case:** Add API management to existing services
- **Example:** Migrating legacy APIs, adding throttling to microservices
- **When:** Backend already exists, you want gateway features in front of it

### Pattern 6: API Gateway → S3 (Serverless Static)

```text
Client → API Gateway → S3 Bucket
```

- **Use case:** Serve static content or accept file uploads without servers
- **Example:** Config file distribution, small file upload API, public JSON endpoints
- **When:** Content is static or you just need simple PUT/GET on objects

### Pattern 7: API Gateway → DynamoDB (Direct CRUD)

```text
Client → API Gateway → DynamoDB (via VTL mapping)
```

- **Use case:** Simple CRUD without any business logic
- **Example:** Feature flags API, key-value config store, leaderboard
- **When:** You literally just need to read/write items — no processing needed

---

## Decision Framework

### Do I Need API Gateway?

```text
Do I need to expose an endpoint to clients over HTTPS?
├── YES: Do I need throttling, logging, auth, or transformations?
│   ├── YES → Use API Gateway ✅
│   └── NO  → Direct ALB/NLB might be simpler and cheaper
└── NO: Is it internal service-to-service?
    └── Use ALB, NLB, service mesh, or direct SDK calls instead
```

### What Type of Integration?

```text
What's behind the API?
├── AWS service (SQS, DynamoDB, S3, Kinesis) → Direct integration (no Lambda!) 🎯
├── Lambda function                          → API Gateway + Lambda integration
├── Container / EC2                          → API Gateway + HTTP proxy or VPC Link
└── External service                         → API Gateway + HTTP integration
```

> 💡 **Pro tip:** Direct AWS service integrations (API Gateway → SQS, DynamoDB, etc.)
> are underrated. Most teams default to API Gateway → Lambda → SQS, adding unnecessary
> cost, latency, and failure points. If you don't need business logic in the middle,
> skip the Lambda.

---

## Authentication Options

| Method               | How It Works                                              | Best For                                      |
|---------------------|----------------------------------------------------------|----------------------------------------------|
| **IAM**              | AWS Sig v4 signed requests                                | Service-to-service, internal APIs             |
| **Cognito**          | JWT tokens from Cognito User Pool                         | Mobile/web apps with user login               |
| **Lambda Authorizer**| Custom Lambda validates token/header                      | Custom auth logic, third-party tokens         |
| **API Keys**         | Static key in `x-api-key` header                          | Usage tracking, basic throttling per client   |
| **Resource Policy**  | IP-based allow/deny (JSON IAM policy)                     | VPC restriction, partner IP whitelisting      |
| **None**             | No auth — open to anyone (⚠️ use with Resource Policy)    | Public APIs with IP-level protection          |

### Combining Auth Methods

You can (and often should) combine multiple methods:

```text
Resource Policy (IP restriction)
  + Lambda Authorizer (token validation)
    + API Key (usage tracking)
      = Defense in depth ✅
```

---

## Security Best Practices

1. **Never use `authorization = "NONE"` without a Resource Policy** — your API becomes publicly accessible
2. **Always enable access logging** — you need audit trails for debugging and compliance
3. **Set throttling limits** — default AWS limits are generous; set your own based on expected traffic
4. **Use custom domains with TLS 1.2+** — avoid exposing the default `execute-api` URL
5. **Enable WAF** (Web Application Firewall) for public-facing APIs — protects against SQL injection, XSS, etc.
6. **Restrict binary content types explicitly** — only accept content types your backend can handle
7. **Validate payload size** — prevent queue/database flooding with oversized requests

---

## Cost Mental Model

| Component      | Pricing (approximate)                                |
|----------------|-----------------------------------------------------|
| REST API v1    | ~$3.50 per million requests + data transfer          |
| HTTP API v2    | ~$1.00 per million requests                          |
| WebSocket API  | ~$1.00 per million messages + connection minutes     |
| Caching        | $0.02 - $3.80/hour depending on cache size           |
| Custom Domain  | Free (but ACM cert required — also free)             |

### Quick Cost Estimates

| Daily Volume    | REST API v1/month | HTTP API v2/month |
|----------------|-------------------|-------------------|
| 100K req/day   | ~$10              | ~$3               |
| 1M req/day     | ~$105             | ~$30              |
| 10M req/day    | ~$1,050           | ~$300             |
| 100M req/day   | ~$10,500          | ~$3,000           |

---

## Monitoring & Observability

### Key CloudWatch Metrics

| Metric        | What It Tells You                                    | Alert Threshold (suggested)   |
|---------------|-----------------------------------------------------|-------------------------------|
| `4XXError`    | Client errors (bad requests, auth failures)          | > 100 in 5 min                |
| `5XXError`    | Server/integration errors (your problem)             | > 10 in 5 min (**critical**)  |
| `Latency`     | End-to-end response time                             | p95 > 5s                      |
| `Count`       | Total API calls                                      | Useful for traffic baselines  |
| `IntegrationLatency` | Time spent in backend only                    | p95 > 3s                      |

### Access Log Fields (Recommended)

```json
{
  "requestId": "$context.requestId",
  "requestTime": "$context.requestTime",
  "httpMethod": "$context.httpMethod",
  "path": "$context.path",
  "status": "$context.status",
  "responseLength": "$context.responseLength",
  "integrationError": "$context.integrationErrorMessage",
  "integrationStatus": "$context.integrationStatus",
  "sourceIp": "$context.identity.sourceIp",
  "userAgent": "$context.identity.userAgent"
}
```

---

## Key Concepts Cheat Sheet

| Term                | What It Means                                                              |
|--------------------|---------------------------------------------------------------------------|
| **Stage**           | A version/environment of your API (`dev`, `staging`, `prod`)               |
| **Resource**        | A URL path segment (`/v1`, `/v1/traces`, `/users/{id}`)                    |
| **Method**          | HTTP verb on a resource (`GET /users`, `POST /v1/traces`)                  |
| **Integration**     | What happens when a method is called (→ SQS, → Lambda, → HTTP, etc.)      |
| **VTL Template**    | Apache Velocity code that transforms requests/responses (REST v1 only)     |
| **Resource Policy** | JSON IAM policy controlling who can invoke the API (REST v1 only)          |
| **Custom Domain**   | Your own domain instead of the default `xxxxxxxx.execute-api.region.amazonaws.com` |
| **Deployment**      | A snapshot of API configuration that gets pushed to a stage                 |
| **Throttling**      | Rate limiting — burst (peak) + sustained rate (steady state)               |
| **Usage Plan**      | Ties API keys to throttling limits and quotas per client                   |
| **Mapping Template**| VTL code for reshaping request/response payloads                           |
| **Binary Media Type**| Content types API Gateway should treat as binary (not text)               |
| **CORS**            | Cross-Origin Resource Sharing — required when browsers call your API       |

---

## Common Gotchas & Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `403 Missing Authentication Token` | Hitting undefined route on REST v1 | Check path and method match your API resources |
| `403 User anonymous not authorized` | Resource policy blocking your IP | Verify source IP is in allowed CIDRs |
| `429 Too Many Requests` | Throttling limit hit | Increase burst/rate limits or implement client-side retry with backoff |
| `502 Bad Gateway` | Backend returned invalid response | Check Lambda response format or backend health |
| `504 Endpoint Request Timed Out` | Backend took > 29s (API Gateway hard limit) | Optimize backend or switch to async pattern (SQS) |
| Changes not reflected | Forgot to deploy | Create new deployment after any resource/method/integration change |
| CORS errors in browser | Missing CORS headers | Add OPTIONS method with CORS headers or enable CORS on HTTP API |
| Binary data corrupted | Missing `binary_media_types` config | Add content type to `binary_media_types` list |

---

## Useful AWS CLI Commands

```bash
# List all REST APIs
aws apigateway get-rest-apis

# Get resources (routes) for an API
aws apigateway get-resources --rest-api-id <api-id>

# Get stages
aws apigateway get-stages --rest-api-id <api-id>

# Test invoke a method (bypasses resource policy — great for debugging)
aws apigateway test-invoke-method \
  --rest-api-id <api-id> \
  --resource-id <resource-id> \
  --http-method POST \
  --body '{"key": "value"}'

# Get API Gateway account settings (CloudWatch role)
aws apigateway get-account

# View access logs
aws logs filter-log-events \
  --log-group-name "/aws/api-gateway/<api-name>" \
  --start-time $(date -v-30M +%s000) \
  --limit 20

# Flush stage cache
aws apigateway flush-stage-cache \
  --rest-api-id <api-id> \
  --stage-name <stage>
```

---

## Further Reading

- [AWS API Gateway Developer Guide](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [REST vs HTTP API comparison](https://docs.aws.amazon.com/apigateway/latest/developerguide/http-api-vs-rest.html)
- [VTL Reference](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-mapping-template-reference.html)
- [API Gateway Limits & Quotas](https://docs.aws.amazon.com/apigateway/latest/developerguide/limits.html)
- [Best Practices for REST APIs](https://docs.aws.amazon.com/apigateway/latest/developerguide/rest-api-best-practices.html)
