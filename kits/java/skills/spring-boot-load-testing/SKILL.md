---
name: spring-boot-load-testing
description: "Spring Boot API load testing with k6: REST endpoint benchmarks, MyBatis-Plus pagination queries, JWT auth scenarios, HikariCP pool validation, and JetCache hit/miss verification. Use when running load tests, stress tests, or performance benchmarks against Spring Boot services."
version: "1.1.0"
type: skill
---

# Spring Boot Load Testing with k6

## When to use this skill

- Running load/stress/spike/soak tests against Spring Boot REST APIs
- Benchmarking MyBatis-Plus pagination query performance under concurrency
- Verifying HikariCP connection pool sizing under load
- Testing JetCache or Spring Cache behavior under concurrent reads
- Validating JWT authentication throughput and token refresh under load
- Setting up k6 performance regression tests in CI/CD

## When NOT to Use

- General k6 usage (WebSocket, gRPC, Browser testing) → `k6-load-testing` skill from `claude-code-plugins-plus-skills`
- JMeter or Gatling load testing → their respective official documentation
- Unit or integration testing → `unit-test-scheduled-async` or Spring Boot test skills

## Prerequisites

- k6 installed (`brew install k6` / `choco install k6` / `docker run grafana/k6`)
- Target Spring Boot application running in a staging/performance environment
- Baseline SLA targets defined (e.g., p95 < 200ms, error rate < 1%)
- Monitoring stack for server-side metrics (Actuator + Prometheus/Grafana or Datadog)

> **Spring Boot 3.5.x Actuator configuration**: Metrics endpoints must be explicitly exposed. Without this configuration, `/actuator/metrics/hikaricp.*` will return 404:
> ```yaml
> management:
>   endpoints:
>     web:
>       exposure:
>         include: health,metrics,prometheus,info
>   metrics:
>     tags:
>       application: ${spring.application.name}
> ```
> For virtual threads (Spring Boot 3.5.x with `spring.threads.virtual.enabled=true`), note that HikariCP pool sizing may need adjustment — virtual threads can create far more concurrent requests than platform threads.

> For general k6 usage (WebSocket, gRPC, Browser), see the `k6-load-testing` skill from `claude-code-plugins-plus-skills`. This skill focuses on Spring Boot-specific patterns.

## Instructions

### 1. Define test scenarios based on Spring Boot endpoint patterns

Identify critical endpoints from production traffic:

| Endpoint Type | Example | Test Focus |
|---------------|---------|------------|
| CRUD single item | `GET /v1/users/{id}` | Cache hit/miss, single-row lookup |
| Paginated list | `GET /v1/users?pageNum=1&pageSize=20` | MyBatis-Plus pagination, query performance |
| Create/Update | `POST /v1/users` | Write throughput, transaction scope |
| Health check | `GET /actuator/health` | Infrastructure baseline |
| Auth token | `POST /v1/auth/token` | JWT signing throughput |

### 2. Handle Spring Boot response format

Spring Boot APIs using `Result<T>` wrapper return: `{"code": 200, "msg": "success", "data": {...}}`. Paginated responses return `Result<PageResult<T>>` with `data.records`, `data.total`, `data.pageNum`, `data.pageSize`.

```javascript
import http from 'k6/http';
import { check } from 'k6';

// ✅ Check both HTTP status and Result<T> code field
function checkResult(res) {
  return check(res, {
    'Result wrapper present': (r) => JSON.parse(r.body).code !== undefined,
    'HTTP 200': (r) => r.status === 200,
    'code is 200': (r) => JSON.parse(r.body).code === 200,  // ✅ Business error code, not just HTTP status
    'p95 < 500ms': (r) => r.timings.duration < 500,
  });
}

// ❌ Anti-pattern: only checking HTTP status — misses business errors wrapped in 200 responses
// A Spring Boot Result<T> can return HTTP 200 with code=500 (internal error)
function checkResultWrong(res) {
  return check(res, {
    'HTTP 200': (r) => r.status === 200,  // ❌ Misses business-level errors
  });
}
```

### 3. Authenticate with JWT tokens

Spring Boot Security 6.x (Spring Boot 3.5.x) uses `SecurityFilterChain` bean-based configuration. JWT requires obtaining a token before testing protected endpoints:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// ✅ Use setup() to obtain JWT token, pass to all VUs via data parameter
export function setup() {
  const res = http.post(`${BASE_URL}/v1/auth/token`, JSON.stringify({
    username: __ENV.TEST_USERNAME || 'perf_test_user',  // ✅ Use env vars, not hardcoded credentials
    password: __ENV.TEST_PASSWORD || 'perf_test_pass',
  }), { headers: { 'Content-Type': 'application/json' } });
  return { token: JSON.parse(res.body).data.token };
}

export default function (data) {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${data.token}`,
  };

  const res = http.get(`${BASE_URL}/v1/users?pageNum=1&pageSize=20`, { headers });
  check(res, {
    'status 200': (r) => r.status === 200,
    'Result code 200': (r) => JSON.parse(r.body).code === 200,
    'has records': (r) => JSON.parse(r.body).data.records.length > 0,
  });
  sleep(1);
}
```

### 4. Test paginated queries under load

MyBatis-Plus pagination is the most common high-traffic pattern. Test with varied page parameters:

```javascript
export const options = {
  stages: [
    { duration: '1m', target: 20 },   // Warm-up
    { duration: '5m', target: 100 },   // Sustained load
    { duration: '2m', target: 200 },   // Stress
    { duration: '1m', target: 0 },     // Cool-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<300', 'p(99)<800'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const pageNum = Math.floor(Math.random() * 10) + 1;  // ✅ Randomize to avoid cache-only hits
  const pageSize = [10, 20, 50][Math.floor(Math.random() * 3)];
  const res = http.get(`${BASE_URL}/v1/users?pageNum=${pageNum}&pageSize=${pageSize}`, { headers });
  const body = JSON.parse(res.body);
  check(res, {
    'paginated response': (r) => body.data && body.data.total !== undefined,
    'records present': (r) => body.data.records.length > 0,
  });
  sleep(Math.random() * 2);  // ✅ Random think time 0-2s — realistic user behavior
}
```

### 5. Verify HikariCP connection pool under load

Monitor connection pool metrics via Actuator during load tests:

```javascript
// After load test, check pool metrics
export function handleSummary(data) {
  const poolRes = http.get(`${BASE_URL}/actuator/metrics/hikaricp.connections.active`);
  const poolData = JSON.parse(poolRes.body);
  console.log(`Active connections: ${poolData.measurements[0].value}`);

  const waitRes = http.get(`${BASE_URL}/actuator/metrics/hikaricp.connections.pending`);
  const waitData = JSON.parse(waitRes.body);
  console.log(`Pending connections: ${waitData.measurements[0].value}`);

  // If pending > 0 consistently, pool size needs increase
  return { stdout: JSON.stringify(data) };
}
```

Key pool metrics to monitor during load tests:

| Metric | Actuator Endpoint | Warning Threshold |
|--------|-------------------|-------------------|
| Active connections | `/actuator/metrics/hikaricp.connections.active` | > 80% of maxPoolSize |
| Pending threads | `/actuator/metrics/hikaricp.connections.pending` | > 0 consistently |
| Idle connections | `/actuator/metrics/hikaricp.connections.idle` | < 2 at peak |
| Acquisition time | `/actuator/metrics/hikaricp.connections.creation` | > 100ms average |

> For HikariCP sizing formula: `connections = (core_count * 2) + effective_spindle_count`. See `mybatis-plus-patterns` for query optimization that reduces pool pressure.
>
> **Spring Boot 3.5.x with virtual threads**: When `spring.threads.virtual.enabled=true`, virtual threads can scale to thousands of concurrent requests. HikariCP pool sizing may need significant increase — the traditional formula may underestimate. Monitor `hikaricp.connections.pending` closely and adjust `maximum-pool-size` accordingly.

### 6. Verify cache behavior under load

Test that JetCache (`@Cached`) or Spring Cache (`@Cacheable`) actually reduces repository calls:

```javascript
// ✅ Warm cache first, then verify second call is faster
export default function () {
  // First call — cache miss
  const res1 = http.get(`${BASE_URL}/v1/users/1`, { headers });
  const time1 = res1.timings.duration;

  sleep(0.1);  // Brief pause

  // Second call — should hit cache
  const res2 = http.get(`${BASE_URL}/v1/users/1`, { headers });
  const time2 = res2.timings.duration;

  check(res2, {
    'cache hit faster': () => time2 < time1 * 0.5,  // ✅ Cache hit should be <50% of miss time
    'same data': (r) => JSON.parse(r.body).data.id === 1,
  });
}
```

### 7. Generate performance report

After each test run, summarize results:

```bash
k6 run --out json=results.json --summary-export=summary.json load-test.js
```

Interpret key metrics:

| Metric | Good | Warning | Critical |
|--------|------|---------|----------|
| p95 response time | < 200ms | 200-500ms | > 500ms |
| p99 response time | < 500ms | 500-1000ms | > 1000ms |
| Error rate | < 0.1% | 0.1-1% | > 1% |
| Throughput (req/s) | At or above defined SLA target (e.g., > 100 req/s) | Near limit | Below target |

## Test Types Quick Reference

| Type | VUs | Duration | Purpose |
|------|-----|----------|---------|
| Smoke | 1-5 | 1-2 min | Verify test script and basic functionality |
| Load | Expected peak | 10-15 min | Validate SLA under normal peak traffic |
| Stress | 2-5x peak | 5-10 min | Find breaking point and saturation behavior |
| Spike | 0 → 10x peak | 2-3 min | Test burst handling (flash sale, viral event) |
| Soak | 50-80% peak | 1-4 hours | Detect memory leaks, connection leaks, cache degradation |

## CI/CD Integration

In CI/CD, run k6 with `--summary-export=summary.json` and check thresholds via jq.

## Error Handling

| Error Pattern | Spring Boot Cause | Fix |
|---------------|-------------------|-----|
| `Connection is not available` | HikariCP pool exhausted under load | Increase `maximum-pool-size`; optimize slow queries; reduce transaction scope |
| 401/403 responses during test | JWT token expired mid-test | Use `setup()` to obtain token; implement token refresh in test script |
| P99 spikes on paginated queries | Missing DB indexes on filter columns | Add indexes on `WHERE` columns; use `EXPLAIN ANALYZE` to verify |
| Consistent slow responses regardless of VUs | Single slow query or external API call | Profile with Actuator; check `@Transactional` scope wrapping non-DB work |
| Inconsistent results across runs | Cache warming, GC pauses, cold starts | Add warm-up stage; run 3 times and average; use dedicated test env |

## Anti-patterns

- ❌ **Only checking HTTP status, not `Result<T>.code`** — Spring Boot APIs wrap business errors in HTTP 200. A `code=500` inside a 200 response is a failure your test must catch.
- ❌ **Hardcoded credentials in test scripts** — use `__ENV` variables (`k6 run -e TEST_USERNAME=... -e TEST_PASSWORD=...`). Hardcoded admin/admin123 credentials leak into CI logs and can't rotate.
- ❌ **No token refresh for soak tests** — JWT tokens expire (typically 15-30 min). Soak tests lasting hours will fail after expiry. Implement periodic re-authentication or use longer-lived test tokens.
- ❌ **Always testing same parameters** — always `pageNum=1`, `pageSize=20`, `userId=1` only tests cache hits. Randomize to cover cache misses, different query scopes, and realistic traffic patterns.
- ❌ **No think time (`sleep()`)** — generates unrealistic burst traffic. Without think time, 100 VUs = 100 simultaneous requests per iteration, not 100 concurrent users with human pauses.
- ❌ **Load testing without monitoring server-side metrics** — client-side k6 metrics alone cannot diagnose connection pool exhaustion, cache degradation, or GC pressure. Always monitor Actuator metrics during tests.
- ❌ **Load testing production** — risks data corruption, user impact, and cascading failures. Use a staging/performance environment with production-like data volume.

## References

- [references/k6-test-templates.md](references/k6-test-templates.md) — Ready-to-use k6 test script templates for Spring Boot endpoints

## Related Skills

- `spring-boot-actuator`
- `mybatis-plus-patterns`
- `spring-boot-jetcache`
- `spring-boot-security-jwt`
- `spring-boot-transaction-management`