# Self-Hosting

## output: 'standalone'

For production deployment outside of the managed platform, configure standalone output to produce a minimal, self-contained build:

```ts
// next.config.ts
const nextConfig = {
  output: 'standalone',
}

export default nextConfig
```

After `next build`, the `standalone` directory contains:
- A minimal Node.js server that serves the app
- Only the necessary production dependencies (not devDependencies)
- No source maps or development tooling

The standalone output is significantly smaller than the full build — typically 10-50% of the total `node_modules` size.

### What standalone Does NOT Include

- Static assets from `public/` — copy these manually
- `node_modules` for devDependencies — only production deps are traced
- `.next/static/` — copy this manually for static file serving

### File Structure After Build

```
.next/
├── standalone/
│   ├── .next/              # compiled server and static files
│   ├── node_modules/       # traced production dependencies only
│   ├── package.json        # minimal package.json
│   ├── server.js           # production server entry point
│   └── .env               # environment variables (if present)
├── static/                # static assets (must be copied separately)
```

## Docker

### Minimal Docker Image

```dockerfile
FROM node:22-alpine AS base

# Install dependencies only when needed
FROM base AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Build the application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/public ./public
COPY --from=builder /app/.next/standalone ./
COPY --from=builder /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "server.js"]
```

### Docker Compose

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/myapp
    depends_on:
      - db

  db:
    image: postgres:18
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: myapp
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7
    ports:
      - "6379:6379"

volumes:
  pgdata:
```

### Docker Best Practices

- Use `node:22-alpine` for minimal image size
- Run `npm ci --omit=dev` for production-only dependencies
- Copy only `standalone`, `public`, and `.next/static` — do not copy the full build
- Run as a non-root user (`nextjs`)
- Set `NODE_ENV=production`
- Do not copy `.env` files into the image — use environment variables at runtime

## Custom Server

The standalone output includes `server.js` which runs a minimal HTTP server. You can customize it for advanced use cases:

```js
// custom server.js (modify the standalone server.js)
const { createServer } = require('http')
const { parse } = require('url')
const next = require('next')

const dev = process.env.NODE_ENV !== 'production'
const app = next({ dev })
const handle = app.getRequestHandler()

app.prepare().then(() => {
  createServer((req, res) => {
    const parsedUrl = parse(req.url, true)
    handle(req, res, parsedUrl)
  }).listen(3000, () => {
    console.log('> Ready on http://localhost:3000')
  })
})
```

However, using a custom server is generally not recommended. The standalone `server.js` handles all Next.js routing correctly. Custom servers may break:
- Automatic static file optimization
- Route-based caching
- Middleware execution
- Edge runtime compatibility

Only write a custom server if you need:
- Health check endpoints at a specific path
- WebSocket integration that cannot use Route Handlers
- Custom authentication middleware before Next.js

## Custom Cache Handlers

Next.js uses a file-system cache by default. For production deployments, you may need a distributed cache:

```ts
// next.config.ts
const nextConfig = {
  cacheHandler: require.resolve('./cache-handler.ts'),
  cacheMaxMemorySize: 0, // disable in-memory cache when using custom handler
}

export default nextConfig
```

```ts
// cache-handler.ts
import type { CacheHandler } from 'next'

export default class RedisCacheHandler implements CacheHandler {
  private redis: Redis

  constructor() {
    this.redis = new Redis(process.env.REDIS_URL!)
  }

  async get(key: string) {
    const data = await this.redis.get(`next-cache:${key}`)
    return data ? JSON.parse(data) : null
  }

  async set(key: string, data: any) {
    await this.redis.set(
      `next-cache:${key}`,
      JSON.stringify(data),
      'EX',
      data.revalidate || 3600
    )
  }

  async revalidateTag(tag: string) {
    // Find all keys tagged with this tag and delete them
    const keys = await this.redis.smembers(`next-tags:${tag}`)
    if (keys.length > 0) {
      await this.redis.del(...keys.map((k: string) => `next-cache:${k}`))
      await this.redis.del(`next-tags:${tag}`)
    }
  }
}
```

### Cache Handler Requirements

- Must implement `get(key)`, `set(key, data)`, and `revalidateTag(tag)` methods
- Must be specified as an absolute path in `next.config.ts`
- The `set` method receives data with `revalidate` (seconds) and `tags` (string array)
- The `revalidateTag` method must invalidate all cache entries associated with the tag

## ISR Configuration

### On-Demand Revalidation

ISR (Incremental Static Regeneration) revalidates pages on a schedule or on demand.

Time-based revalidation:

```tsx
// app/products/page.tsx
export const revalidate = 300 // revalidate every 5 minutes

export default async function ProductsPage() {
  const products = await fetch('https://api.example.com/products', {
    next: { revalidate: 300 },
  }).then(r => r.json())
  return <ProductList products={products} />
}
```

On-demand revalidation via Route Handler (for webhook-triggered updates):

```tsx
// app/api/revalidate/route.ts
import { revalidateTag, revalidatePath } from 'next/headers'
import { NextRequest } from 'next/server'

export async function POST(request: NextRequest) {
  const body = await request.json()
  const secret = body.secret

  // Verify the request is authorized
  if (secret !== process.env.REVALIDATION_SECRET) {
    return Response.json({ error: 'Invalid secret' }, { status: 401 })
  }

  // Revalidate by tag or path
  if (body.tag) {
    revalidateTag(body.tag)
  } else if (body.path) {
    revalidatePath(body.path)
  }

  return Response.json({ revalidated: true, now: Date.now() })
}
```

### ISR with Self-Hosting

For self-hosted ISR, ensure:
- The cache persists across container restarts (use a custom cache handler)
- The `revalidate` interval is set correctly per route
- On-demand revalidation endpoints are protected with a secret
- The cache handler supports tag-based revalidation for on-demand updates

## Environment Variables

### Runtime vs Build-Time

| Variable type | Prefix | Available | When |
|---------------|--------|-----------|------|
| Build-time | `NEXT_PUBLIC_` | Client + Server | At build time |
| Runtime | No prefix | Server only | At runtime (not in standalone bundle) |

```ts
// Build-time — embedded in client bundle
NEXT_PUBLIC_API_URL=https://api.example.com

// Runtime — only available on the server at runtime
DATABASE_URL=postgresql://...
STRIPE_SECRET_KEY=sk_live_...
```

For runtime-only variables in standalone deployments, pass them as environment variables at container start:

```bash
docker run -e DATABASE_URL=postgresql://... -e STRIPE_SECRET_KEY=sk_live_... app-image
```

Or mount a `.env` file in the standalone directory.

### Environment Variable Checklist

- [ ] All secrets use runtime-only variables (no `NEXT_PUBLIC_` prefix)
- [ ] Public variables (`NEXT_PUBLIC_*`) contain no secrets
- [ ] Runtime variables are passed at container startup, not baked into the image
- [ ] `.env` files are never committed to source control
- [ ] Production `.env` uses real values, not defaults