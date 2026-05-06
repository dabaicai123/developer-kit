# k6 Test Script Templates for Spring Boot

Ready-to-use k6 test scripts for specialized load testing scenarios. Basic CRUD and pagination patterns are in the SKILL.md.

> **Spring Boot 3.5.x note**: Ensure Actuator metrics endpoints are exposed via `management.endpoints.web.exposure.include=health,metrics,prometheus` before running these templates. JWT tokens expire (typically 15-30 min); for soak tests, implement periodic re-authentication.

## Template 1: Cache Hit/Miss Verification

Tests that `@Cached` actually reduces database calls under load.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.JWT_TOKEN || '';  // ✅ Use __ENV for token, not hardcoded

const cacheMissDuration = new Trend('cache_miss_duration');
const cacheHitDuration = new Trend('cache_hit_duration');

export const options = {
  stages: [
    { duration: '30s', target: 1 },
    { duration: '3m', target: 100 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    cache_hit_duration: ['p(95)<50'],
    http_req_failed: ['rate<0.01'],
  },
};

let isFirstCall = true;

export default function () {
  const headers = { 'Authorization': `Bearer ${TOKEN}` };
  const userId = (__ITER === 0) ? Math.floor(Math.random() * 100) + 1 : 1;
  const res = http.get(`${BASE_URL}/v1/users/${userId}`, { headers });

  if (__ITER === 0 && isFirstCall) {
    cacheMissDuration.add(res.timings.duration);
    isFirstCall = false;
  } else {
    cacheHitDuration.add(res.timings.duration);
  }

  check(res, {
    'Result code 200': (r) => JSON.parse(r.body).code === 200,  // ✅ Check business error code
    'has user data': (r) => JSON.parse(r.body).data !== null,
  });

  sleep(0.5);
}
```

> ❌ **Anti-pattern**: Always using `userId = 1` only tests cache hits after warm-up. Mix random IDs (cache misses) with fixed IDs (cache hits) to validate realistic hit ratio.

## Template 2: Connection Pool Soak Test

Long-running test to verify HikariCP doesn't leak connections under sustained load.

> **Spring Boot 3.5.x with virtual threads**: When `spring.threads.virtual.enabled=true`, this soak test may reveal that HikariCP pool sizing needs significant increase. Monitor `hikaricp.connections.pending` closely — virtual threads can create far more concurrent requests than platform threads.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.JWT_TOKEN || '';  // ✅ Use __ENV for token, not hardcoded

export const options = {
  stages: [
    { duration: '5m', target: 50 },
    { duration: '30m', target: 50 },
    { duration: '5m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.005'],
  },
};

export default function () {
  const headers = { 'Authorization': `Bearer ${TOKEN}` };

  if (__ITER % 3 === 0) {
    http.get(`${BASE_URL}/v1/users?pageNum=1&pageSize=10`, { headers });
  } else if (__ITER % 3 === 1) {
    http.post(`${BASE_URL}/v1/users`, JSON.stringify({
      username: `perf_user_${__VU}_${__ITER}`,
      email: `perf${__VU}${__ITER}@test.com`,
    }), { headers });
  } else {
    http.get(`${BASE_URL}/v1/users/1`, { headers });
  }

  sleep(Math.random() * 1.5);
}

export function handleSummary(data) {
  const poolMetrics = http.get(`${BASE_URL}/actuator/metrics/hikaricp.connections.active`, {
    headers: { 'Authorization': `Bearer ${TOKEN}` },
  });
  if (poolMetrics.status === 200) {
    const metrics = JSON.parse(poolMetrics.body);
    console.log(`Final active connections: ${metrics.measurements[0].value}`);
  }
  return { stdout: JSON.stringify(data) };
}
```

## Template 3: Spike Test

Simulates sudden traffic burst (flash sale, viral event).

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.JWT_TOKEN || '';  // ✅ Use __ENV for token, not hardcoded

export const options = {
  stages: [
    { duration: '10s', target: 10 },
    { duration: '10s', target: 500 },
    { duration: '1m', target: 500 },
    { duration: '30s', target: 10 },
    { duration: '30s', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],
    http_req_failed: ['rate<0.05'],
  },
};

export default function () {
  const headers = { 'Authorization': `Bearer ${TOKEN}` };
  const res = http.get(`${BASE_URL}/v1/products?pageNum=1&pageSize=20`, { headers });

  check(res, {
    'status OK': (r) => r.status === 200 || r.status === 429,  // ✅ Accept 429 (rate-limited) as OK — expected under spike load
    'Result wrapper': (r) => JSON.parse(r.body).code !== undefined,
  });

  sleep(Math.random() * 0.5);
}
```