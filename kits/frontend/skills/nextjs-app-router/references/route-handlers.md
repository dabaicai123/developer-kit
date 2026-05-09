# Route Handlers

## Basics

Route Handlers are defined in `route.ts` files inside the `app/` directory. They export named functions for HTTP methods:

```tsx
// app/api/health/route.ts
export async function GET() {
  return Response.json({ status: 'ok', timestamp: Date.now() })
}

// app/api/users/route.ts
export async function POST(request: Request) {
  const body = await request.json()
  const user = await db.user.create({ data: body })
  return Response.json(user, { status: 201 })
}

// app/api/users/[id]/route.ts
export async function GET(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const user = await db.user.findUnique({ where: { id } })

  if (!user) {
    return Response.json({ error: 'Not found' }, { status: 404 })
  }

  return Response.json(user)
}

export async function PUT(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  const body = await request.json()
  const user = await db.user.update({ where: { id }, data: body })
  return Response.json(user)
}

export async function DELETE(
  request: Request,
  { params }: { params: Promise<{ id: string }> }
) {
  const { id } = await params
  await db.user.delete({ where: { id } })
  return new Response(null, { status: 204 })
}
```

Supported methods: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`.

## GET Route Conflicts

A `route.ts` file with a `GET` handler **cannot coexist** with a `page.tsx` in the same route segment. This is because both would handle GET requests for the same URL.

```tsx
// WRONG: page.tsx and route.ts in the same directory
app/products/
├── page.tsx      // handles GET /products (renders UI)
├── route.ts      // also handles GET /products (returns JSON) — CONFLICT!
```

Solutions:

1. **Separate API routes under `/api/`**: Keep UI pages at `/products/page.tsx` and API at `/api/products/route.ts`.

2. **Use Server Actions instead of API routes**: For mutations triggered by the UI, Server Actions are simpler than Route Handlers.

3. **Use Route Handlers for non-UI endpoints**: Webhooks, SSE, file uploads, and third-party integrations belong in `/api/`.

```
app/
├── products/
│   └── page.tsx           // UI: GET /products
├── api/
│   ├── products/
│   │   └── route.ts       // API: GET /api/products (JSON)
│   ├── webhooks/
│   │   └── route.ts       // Webhook: POST /api/webhooks
```

## Environment Behavior

Route Handlers run in the **Node.js runtime** by default. You can switch to the Edge runtime for lower latency:

```tsx
// app/api/health/route.ts — Edge runtime
export const runtime = 'edge'

export async function GET() {
  return Response.json({ status: 'ok' })
}
```

| Runtime | Cold start | Limits | Good for |
|---------|-----------|--------|----------|
| Node.js | ~250ms | Full Node API | Database access, file I/O, heavy computation |
| Edge | ~5ms | Limited API, no Node modules | Quick responses, geolocation, auth checks |

Edge runtime constraints:
- No `fs`, `path`, `crypto` (Node versions), or other Node.js-only modules
- No access to environment variables set in `next.config.ts` (only `NEXT_PUBLIC_*` and Edge-compatible vars)
- No database connections that require long-lived TCP sockets

## Streaming Responses

Route Handlers can return streaming responses for real-time data, SSE, or large payloads:

```tsx
// app/api/events/route.ts — Server-Sent Events
export async function GET() {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    async start(controller) {
      // Send initial connection message
      controller.enqueue(encoder.encode('data: connected\n\n'))

      // Periodically send updates
      const interval = setInterval(() => {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify({ time: Date.now() })}\n\n`))
      }, 1000)

      // Clean up on close
      // Note: cleanup requires abort signal handling
    },
  })

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
    },
  })
}
```

### Streaming JSON

```tsx
// app/api/search/route.ts — streaming JSON results
export async function GET(request: Request) {
  const query = new URL(request.url).searchParams.get('q')
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    async start(controller) {
      for await (const result of searchStream(query!)) {
        controller.enqueue(encoder.encode(JSON.stringify(result) + '\n'))
      }
      controller.close()
    },
  })

  return new Response(stream, {
    headers: { 'Content-Type': 'application/x-ndjson' },
  })
}
```

## Request and Response Helpers

### Reading Request Body

```tsx
export async function POST(request: Request) {
  // JSON body
  const json = await request.json()

  // Form data
  const formData = await request.formData()
  const file = formData.get('file') as File

  // Raw text
  const text = await request.text()

  // ArrayBuffer (for binary data)
  const buffer = await request.arrayBuffer()
}
```

### Cookie and Header Access

```tsx
import { cookies, headers } from 'next/headers'

export async function POST(request: Request) {
  const cookieStore = await cookies()
  const headersList = await headers()

  const sessionToken = cookieStore.get('session')?.value
  const contentType = headersList.get('content-type')

  // ...
}
```

### Redirect from Route Handlers

```tsx
import { redirect } from 'next/navigation'

export async function GET(request: Request) {
  redirect('/dashboard') // throws a redirect error
}

// Or use Response.redirect for standard HTTP redirect
export async function GET(request: Request) {
  return Response.redirect(new URL('/dashboard', request.url), 302)
}
```

## Webhook Patterns

Route Handlers are ideal for receiving webhooks from external services:

```tsx
// app/api/webhooks/stripe/route.ts
import { headers } from 'next/headers'
import { stripe } from '@/lib/stripe'

export async function POST(request: Request) {
  const body = await request.text()
  const headersList = await headers()
  const signature = headersList.get('stripe-signature')

  if (!signature) {
    return Response.json({ error: 'Missing signature' }, { status: 400 })
  }

  try {
    const event = stripe.webhooks.constructEvent(
      body,
      signature,
      process.env.STRIPE_WEBHOOK_SECRET!
    )

    switch (event.type) {
      case 'payment_intent.succeeded':
        await handlePaymentSuccess(event.data.object)
        break
      case 'customer.subscription.updated':
        await handleSubscriptionUpdate(event.data.object)
        break
      default:
        console.log(`Unhandled event type: ${event.type}`)
    }

    return Response.json({ received: true })
  } catch (err) {
    return Response.json({ error: 'Invalid signature' }, { status: 400 })
  }
}
```

### Webhook Security Checklist

- Verify the signature from the sender (Stripe, GitHub, etc.)
- Return a response quickly — process the webhook asynchronously if needed
- Use `POST` method only — reject `GET` requests
- Store webhook secrets in environment variables, not in code
- Log all incoming webhooks for debugging

## Caching Route Handlers

By default, Route Handlers are **dynamic** (not cached). To cache a GET handler, set `export const dynamic = 'force-static'`:

```tsx
// app/api/config/route.ts — cached at build time
export const dynamic = 'force-static'

export async function GET() {
  return Response.json({ config: await getAppConfig() })
}
```

For ISR-style revalidation:

```tsx
export const revalidate = 300 // revalidate every 5 minutes

export async function GET() {
  return Response.json({ data: await fetchData() })
}
```

## CORS in Route Handlers

Route Handlers do not automatically handle CORS. For cross-origin requests, set headers manually:

```tsx
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://app.example.com',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  'Access-Control-Max-Age': '86400',
}

export async function OPTIONS() {
  return new Response(null, { status: 204, headers: corsHeaders })
}

export async function GET() {
  const data = await fetchData()
  return Response.json(data, { headers: corsHeaders })
}
```

## When to Use Route Handlers vs Server Actions

| Scenario | Use Route Handler | Use Server Action |
|----------|-------------------|-------------------|
| Form submission from UI | No | Yes |
| Webhook from external service | Yes | No |
| SSE / streaming response | Yes | No |
| File upload (multipart) | Yes | Yes (FormData) |
| REST API for external consumers | Yes | No |
| Quick mutation with revalidation | No | Yes |
| CORS / cross-origin access | Yes | No |

Prefer Server Actions for UI-driven mutations. Use Route Handlers for non-UI endpoints that need raw HTTP access.