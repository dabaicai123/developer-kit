# k6 Test Script Templates for Spring Boot

Ready-to-use k6 test scripts for common Spring Boot + MyBatis-Plus scenarios.

## Template 1: CRUD API Load Test

Basic load test for CRUD endpoints with JWT authentication and `Result<T>` response parsing.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';

export function setup() {
  // Obtain JWT token
  const res = http.post(`${BASE_URL}/v1/auth/token`, JSON.stringify({
    username: __ENV.TEST_USER || 'admin',
    password: __ENV.TEST_PASS || 'admin123',
  }), { headers: { 'Content-Type': 'application/json' } });

  check(res, { 'auth successful': (r) => JSON.parse(r.body).code === 200 });
  return { token: JSON.parse(res.body).data.token };
}

export const options = {
  stages: [
    { duration: '1m', target: 20 },    // Warm-up
    { duration: '5m', target: 100 },    // Sustained load
    { duration: '2m', target: 200 },    // Stress
    { duration: '1m', target: 0 },      // Cool-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<300', 'p(99)<800'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function (data) {
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${data.token}`,
  };

  // Randomized paginated query — avoids cache-only testing
  const pageNum = Math.floor(Math.random() * 10) + 1;
  const pageSize = [10, 20, 50][Math.floor(Math.random() * 3)];

  const res = http.get(`${BASE_URL}/v1/users?pageNum=${pageNum}&pageSize=${pageSize}`, { headers });
  const body = JSON.parse(res.body);

  check(res, {
    'HTTP 200': (r) => r.status === 200,
    'Result code 200': () => body.code === 200,
    'has records': () => body.data && body.data.records.length > 0,
    'has total': () => body.data && body.data.total !== undefined,
  });

  sleep(Math.random() * 2);  // Think time 0-2s
}
```

Run: `k6 run -e BASE_URL=http://staging:8080 -e TEST_USER=admin -e TEST_PASS=admin123 crud-load-test.js`

## Template 2: Paginated Query Benchmark

Focuses on MyBatis-Plus pagination performance at different page offsets.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.JWT_TOKEN || '';

export const options = {
  scenarios: {
    // Early pages — should be fast (index-backed)
    early_pages: {
      executor: 'constant-vus',
      vus: 50,
      duration: '3m',
      env: { PAGE_RANGE: '1-5' },
    },
    // Deep pages — OFFSET gets expensive on large tables
    deep_pages: {
      executor: 'constant-vus',
      vus: 50,
      duration: '3m',
      startTime: '3m',
      env: { PAGE_RANGE: '100-105' },
    },
  },
  thresholds: {
    'http_req_duration{scenario:early_pages}': ['p(95)<200'],
    'http_req_duration{scenario:deep_pages}': ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

export default function () {
  const headers = {
    'Authorization': `Bearer ${TOKEN}`,
    'Content-Type': 'application/json',
  };

  const [min, max] = __ENV.PAGE_RANGE.split('-').map(Number);
  const pageNum = Math.floor(Math.random() * (max - min + 1)) + min;

  const res = http.get(`${BASE_URL}/v1/orders?pageNum=${pageNum}&pageSize=20`, { headers });
  const body = JSON.parse(res.body);

  check(res, {
    'Result code 200': () => body.code === 200,
    'records present': () => body.data && body.data.records !== undefined,
  });

  sleep(1);
}
```

## Template 3: Cache Hit/Miss Verification

Tests that `@Cached` / `@Cacheable` actually reduces database calls under load.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Trend } from 'k6/metrics';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.JWT_TOKEN || '';

const cacheMissDuration = new Trend('cache_miss_duration');
const cacheHitDuration = new Trend('cache_hit_duration');

export const options = {
  stages: [
    { duration: '30s', target: 1 },   // Single user — measure cache miss then hit
    { duration: '3m', target: 100 },   // Load — most should hit cache
    { duration: '30s', target: 0 },    // Cool-down
  ],
  thresholds: {
    cache_hit_duration: ['p(95)<50'],    // Cache hits should be very fast
    http_req_failed: ['rate<0.01'],
  },
};

let isFirstCall = true;

export default function () {
  const headers = { 'Authorization': `Bearer ${TOKEN}` };

  // Use same ID to ensure cache hit on second call
  const userId = (__ITER === 0) ? Math.floor(Math.random() * 100) + 1 : 1;
  const res = http.get(`${BASE_URL}/v1/users/${userId}`, { headers });

  if (__ITER === 0 && isFirstCall) {
    cacheMissDuration.add(res.timings.duration);
    isFirstCall = false;
  } else {
    cacheHitDuration.add(res.timings.duration);
  }

  check(res, {
    'Result code 200': (r) => JSON.parse(r.body).code === 200,
    'has user data': (r) => JSON.parse(r.body).data !== null,
  });

  sleep(0.5);
}
```

## Template 4: Connection Pool Soak Test

Long-running test to verify HikariCP doesn't leak connections under sustained load.

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.JWT_TOKEN || '';

export const options = {
  stages: [
    { duration: '5m', target: 50 },    // Ramp up
    { duration: '30m', target: 50 },    // Soak — watch for connection leaks
    { duration: '5m', target: 0 },      // Cool-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.005'],     // Very strict for soak test
  },
};

export default function () {
  const headers = { 'Authorization': `Bearer ${TOKEN}` };

  // Mix of operations to stress different connection patterns
  if (__ITER % 3 === 0) {
    // Read — short connection usage
    http.get(`${BASE_URL}/v1/users?pageNum=1&pageSize=10`, { headers });
  } else if (__ITER % 3 === 1) {
    // Write — longer connection hold
    http.post(`${BASE_URL}/v1/users`, JSON.stringify({
      username: `perf_user_${__VU}_${__ITER}`,
      email: `perf${__VU}${__ITER}@test.com`,
    }), { headers });
  } else {
    // Single read — verify cache behavior
    http.get(`${BASE_URL}/v1/users/1`, { headers });
  }

  sleep(Math.random() * 1.5);
}

// Post-test: check Actuator pool metrics
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

Run: `k6 run --out json=soak-results.json -e BASE_URL=http://staging:8080 soak-test.js`

## Template 5: Spike Test

Simulates sudden traffic burst (flash sale, viral event).

```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

const BASE_URL = __ENV.BASE_URL || 'http://localhost:8080';
const TOKEN = __ENV.JWT_TOKEN || '';

export const options = {
  stages: [
    { duration: '10s', target: 10 },    // Baseline
    { duration: '10s', target: 500 },   // Spike!
    { duration: '1m', target: 500 },    // Hold spike
    { duration: '30s', target: 10 },    // Recovery
    { duration: '30s', target: 0 },     // Cool-down
  ],
  thresholds: {
    http_req_duration: ['p(95)<1000'],   // Allow higher latency during spike
    http_req_failed: ['rate<0.05'],      // 5% error tolerance during spike
  },
};

export default function () {
  const headers = { 'Authorization': `Bearer ${TOKEN}` };
  const res = http.get(`${BASE_URL}/v1/products?pageNum=1&pageSize=20`, { headers });

  check(res, {
    'status OK': (r) => r.status === 200 || r.status === 429,  // 429 is acceptable during spike
    'Result wrapper': (r) => JSON.parse(r.body).code !== undefined,
  });

  sleep(Math.random() * 0.5);  // Short think time for burst scenario
}
```