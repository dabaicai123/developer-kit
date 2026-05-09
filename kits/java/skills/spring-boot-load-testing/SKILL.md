---
name: spring-boot-load-testing
description: "Spring Boot API load testing with k6: REST endpoint benchmarks, MyBatis-Plus pagination queries, JWT auth scenarios, HikariCP pool validation, and JetCache hit/miss verification. Use when running load tests, stress tests, or performance benchmarks against Spring Boot services."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Spring Boot Load Testing with k6

## When to use this skill

- Running load/stress/spike/soak tests against Spring Boot REST APIs
- Benchmarking MyBatis-Plus pagination query performance under concurrency
- Verifying HikariCP connection pool sizing under load
- Testing JetCache or Spring Cache behavior under concurrent reads
- Validating JWT authentication throughput and token refresh under load
- Setting up k6 performance regression tests in CI/CD

## Prerequisites

- k6 installed (`brew install k6` / `choco install k6` / `docker run grafana/k6`)
- Target Spring Boot application running in a staging/performance environment
- Baseline SLA targets defined (e.g., p95 < 200ms, error rate < 1%)
- Monitoring stack for server-side metrics (Actuator + Prometheus/Grafana or Datadog)

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

function checkResult(res) {
  return check(res, {
    'Result wrapper present': (r) => JSON.parse(r.body).code !== undefined,
    'HTTP 200': (r) => r.status === 200,
    'code is 200': (r) => JSON.parse(r.body).code === 200,
    'p95 < 500ms': (r) => r.timings.duration < 500,
  });
}
```

### 3. Authenticate with JWT tokens

Spring Boot Security JWT requires obtaining a token before testing protected endpoints:

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

// Obtain JWT token per virtual user
export function setup() {
  const res = http.post(`${BASE_URL}/v1/auth/token`, JSON.stringify({
    username: 'admin',
    password: 'admin123',
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

> For token refresh scenarios, add a separate test stage that re-authenticates and measures token endpoint throughput.

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
  const pageNum = Math.floor(Math.random() * 10) + 1;  // Randomize to avoid cache-only hits
  const pageSize = [10, 20, 50][Math.floor(Math.random() * 3)];
  const res = http.get(`${BASE_URL}/v1/users?pageNum=${pageNum}&pageSize=${pageSize}`, { headers });
  const body = JSON.parse(res.body);
  check(res, {
    'paginated response': (r) => body.data && body.data.total !== undefined,
    'records present': (r) => body.data.records.length > 0,
  });
  sleep(Math.random() * 2);  // Random think time 0-2s
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

### 6. Verify cache behavior under load

Test that JetCache (`@Cached`) or Spring Cache (`@Cacheable`) actually reduces repository calls:

```javascript
// Warm cache first, then verify second call is faster
export default function () {
  // First call — cache miss
  const res1 = http.get(`${BASE_URL}/v1/users/1`, { headers });
  const time1 = res1.timings.duration;

  sleep(0.1);  // Brief pause

  // Second call — should hit cache
  const res2 = http.get(`${BASE_URL}/v1/users/1`, { headers });
  const time2 = res2.timings.duration;

  check(res2, {
    'cache hit faster': () => time2 < time1 * 0.5,  // Cache hit should be <50% of miss time
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

## Best Practices

- **Always randomize parameters** — varied `pageNum`, `pageSize`, `userId` to avoid cache-only testing
- **Start with smoke test** — verify script works with 1-5 VUs before scaling
- **Use `setup()` for JWT auth** — obtain token once, share across VUs
- **Check `Result<T>` wrapper** — validate `code === 200` not just HTTP status
- **Monitor HikariCP active/pending connections, cache hit rates, and GC pause counts** via `/actuator/metrics/` during tests
- **Never load test production** — use staging/perf environment with production-like data volume
- **Add warm-up stage** — first 1-2 min at low VUs to warm caches and JIT compilation

## Constraints and Warnings

- **k6 is the primary tool** — this skill focuses on k6 patterns. For JMeter/Gatling, see their official documentation
- **Result<T> parsing** — Spring Boot's unified response wrapper requires checking `code` field, not just HTTP status
- **JWT token scope** — `setup()` token is shared across all VUs; for per-VU auth, use `__ENV` variables or a token pool
- **MyBatis-Plus pagination** — `Page<>` object generates `LIMIT/OFFSET` SQL; large offsets degrade performance — test with realistic page ranges
- **Actuator must be enabled** — pool and cache metrics require `spring-boot-starter-actuator` and appropriate exposure settings
- **Think time matters** — without `sleep()`, tests generate unrealistic burst traffic; use 0.5-2s think time

## References

- k6 documentation: https://grafana.com/docs/k6/latest/
- k6 thresholds: https://grafana.com/docs/k6/latest/use-cases/thresholds/
- Spring Boot Actuator metrics: https://docs.spring.io/spring-boot/docs/current/reference/html/actuator.html#actuator.metrics
- HikariCP metrics: https://github.com/brettwooldridge/HikariCP/wiki/Micrometer-Metrics
- [references/k6-test-templates.md](references/k6-test-templates.md) - Ready-to-use k6 test script templates for Spring Boot endpoints

## Related Skills

- `spring-boot-actuator` — Actuator endpoints for monitoring during load tests
- `mybatis-plus-patterns` — Query optimization to reduce DB pressure under load
- `spring-boot-jetcache` — Cache patterns that reduce load on database
- `spring-boot-security-jwt` — JWT authentication setup for authenticated test scenarios
- `spring-boot-transaction-management` — Transaction scope optimization to reduce connection hold time