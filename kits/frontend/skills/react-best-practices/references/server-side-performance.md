# Server-Side Performance

Rules for optimizing React Server Components and server-side rendering. Every unnecessary serialization or sequential fetch on the server slows the response.

---

## Rule 1: Minimize Serialization at RSC Boundaries

The React Server/Client boundary serializes all object properties into strings and embeds them in the HTML response. Only pass fields that the client actually uses.

**Bad (serializes all 50 fields):**

```tsx
// app/profile/page.tsx — Server Component
async function Page() {
  const user = await fetchUser() // 50 fields from API
  return <Profile user={user} />
}

// components/profile.tsx — Client Component
'use client'

function Profile({ user }: { user: User }) {
  return <div>{user.name}</div> // uses 1 field
}
```

All 50 fields are serialized, transferred, and parsed on the client, even though only `name` is rendered.

**Good (serializes only 1 field):**

```tsx
// app/profile/page.tsx — Server Component
async function Page() {
  const user = await fetchUser()
  return <Profile name={user.name} />
}

// components/profile.tsx — Client Component
'use client'

function Profile({ name }: { name: string }) {
  return <div>{name}</div>
}
```

One string instead of 50 fields. The serialization cost drops from serializing an entire object graph to a single primitive.

---

## Rule 2: React.cache() for Per-Request Deduplication

Use `React.cache()` for server-side request deduplication. Database queries, authentication checks, and non-fetch async work benefit most.

**Bad (same query runs multiple times in one request):**

```tsx
// Multiple components call this independently within the same request
async function getCurrentUser() {
  const session = await auth()
  if (!session?.user?.id) return null
  return await db.user.findUnique({ where: { id: session.user.id } })
}
```

Each call hits the database again even within a single render pass.

**Good (deduplicated within the request):**

```tsx
import { cache } from 'react'

export const getCurrentUser = cache(async () => {
  const session = await auth()
  if (!session?.user?.id) return null
  return await db.user.findUnique({ where: { id: session.user.id } })
})
```

Multiple calls to `getCurrentUser()` within a single request execute the query only once.

### Avoid Inline Objects as Arguments

`React.cache()` uses `Object.is` for shallow equality. Inline objects create new references each call, preventing cache hits.

**Bad (always cache miss):**

```tsx
const getUser = cache(async (params: { uid: number }) => {
  return await db.user.findUnique({ where: { id: params.uid } })
})

getUser({ uid: 1 })
getUser({ uid: 1 }) // Cache miss — new object reference
```

**Good (cache hit with primitive arguments):**

```tsx
const getUser = cache(async (uid: number) => {
  return await db.user.findUnique({ where: { id: uid } })
})

getUser(1)
getUser(1) // Cache hit — primitive value equality
```

In Next.js, `fetch()` is automatically deduplicated by URL and options. `React.cache()` is still needed for database queries, auth checks, computations, and any non-fetch async work.

---

## Rule 3: Hoist Static I/O to Module Level

When loading static assets (fonts, logos, config files) in route handlers or server functions, hoist the I/O to module level. Module-level code runs once when the module is first imported, not on every request.

**Bad (reads font file on every request):**

```tsx
// app/api/og/route.tsx
import { ImageResponse } from 'next/og'

export async function GET(request: Request) {
  // Runs on EVERY request — expensive!
  const fontData = await fetch(
    new URL('./fonts/Inter.ttf', import.meta.url)
  ).then(res => res.arrayBuffer())

  return new ImageResponse(
    <div style={{ fontFamily: 'Inter' }}>Hello World</div>,
    { fonts: [{ name: 'Inter', data: fontData }] }
  )
}
```

**Good (loads once at module initialization):**

```tsx
// app/api/og/route.tsx
import { ImageResponse } from 'next/og'

// Module-level: runs ONCE when module is first imported
const fontDataPromise = fetch(
  new URL('./fonts/Inter.ttf', import.meta.url)
).then(res => res.arrayBuffer())

export async function GET(request: Request) {
  const fontData = await fontDataPromise // Await the already-started promise

  return new ImageResponse(
    <div style={{ fontFamily: 'Inter' }}>Hello World</div>,
    { fonts: [{ name: 'Inter', data: fontData }] }
  )
}
```

Use this pattern for: fonts for OG image generation, static logos/icons, config files, email templates, any static asset that is the same across all requests.

Do not use for: assets that vary per request, files that change at runtime (use caching with TTL), large files that consume too much memory.

---

## Rule 4: Parallel Data Fetching via Component Composition

React Server Components execute sequentially within a tree. Split fetches into separate async components so they run concurrently.

**Bad (Sidebar waits for Page's fetch):**

```tsx
export default async function Page() {
  const header = await fetchHeader()
  return (
    <div>
      <div>{header}</div>
      <Sidebar />
    </div>
  )
}

async function Sidebar() {
  const items = await fetchSidebarItems()
  return <nav>{items.map(renderItem)}</nav>
}
```

`Sidebar` only starts fetching after `Page`'s `fetchHeader()` completes.

**Good (both fetch simultaneously):**

```tsx
async function Header() {
  const data = await fetchHeader()
  return <div>{data}</div>
}

async function Sidebar() {
  const items = await fetchSidebarItems()
  return <nav>{items.map(renderItem)}</nav>
}

export default function Page() {
  return (
    <div>
      <Header />
      <Sidebar />
    </div>
  )
}
```

Both `Header` and `Sidebar` start fetching concurrently. Each resolves independently.

---

## Rule 5: Use after() for Non-Blocking Operations

Use `after()` from `next/server` to schedule work that should execute after the response is sent. This prevents logging, analytics, and side effects from blocking the response.

**Bad (logging blocks the response):**

```tsx
import { logUserAction } from '@/lib/analytics'

export async function POST(request: Request) {
  await updateDatabase(request)

  // Logging blocks the response
  const userAgent = request.headers.get('user-agent') || 'unknown'
  await logUserAction({ userAgent })

  return Response.json({ status: 'success' })
}
```

**Good (non-blocking):**

```tsx
import { after } from 'next/server'
import { headers } from 'next/headers'
import { logUserAction } from '@/lib/analytics'

export async function POST(request: Request) {
  await updateDatabase(request)

  // Log after response is sent
  after(async () => {
    const userAgent = (await headers()).get('user-agent') || 'unknown'
    logUserAction({ userAgent })
  })

  return Response.json({ status: 'success' })
}
```

The response is sent immediately while logging happens in the background.

Common use cases: analytics tracking, audit logging, sending notifications, cache invalidation, cleanup tasks.

`after()` runs even if the response fails or redirects. Works in Server Actions, Route Handlers, and Server Components.

---

## Rule 6: Keep Server Components Lean

Avoid importing client-only libraries in Server Components. Keep server logic focused on data fetching and static rendering.

**Bad (imports client-only library in Server Component):**

```tsx
// app/dashboard/page.tsx — Server Component
import { formatDistance } from 'date-fns'        // Works on server
import { motion } from 'framer-motion'           // Client-only — breaks SSR
import { Chart } from 'react-chartjs-2'          // Client-only — breaks SSR

export default async function DashboardPage() {
  const data = await fetchDashboardData()
  return (
    <div>
      <Chart data={data} />
      <motion.div animate={{ x: 100 }}>Content</motion.div>
    </div>
  )
}
```

**Good (client-only components are extracted):**

```tsx
// app/dashboard/page.tsx — Server Component
import { DashboardChart } from './dashboard-chart'
import { AnimatedPanel } from './animated-panel'

export default async function DashboardPage() {
  const data = await fetchDashboardData()
  return (
    <div>
      <DashboardChart data={data} />
      <AnimatedPanel>Content</AnimatedPanel>
    </div>
  )
}

// components/dashboard-chart.tsx — Client Component
'use client'
import { Chart } from 'react-chartjs-2'

export function DashboardChart({ data }: { data: ChartData }) {
  return <Chart data={data} />
}

// components/animated-panel.tsx — Client Component
'use client'
import { motion } from 'framer-motion'

export function AnimatedPanel({ children }: { children: React.ReactNode }) {
  return <motion.div animate={{ x: 100 }}>{children}</motion.div>
}
```

---

## Rule 7: Request Deduplication for fetch

Next.js automatically deduplicates `fetch` requests within a single render pass. Multiple components requesting the same URL produce only one network call.

```tsx
// Both components request the same URL — only one fetch happens

// app/products/layout.tsx
export default async function ProductsLayout({
  children,
}: {
  children: React.ReactNode
}) {
  const products = await fetch('https://api.example.com/products').then(r => r.json())
  return <div><ProductNav products={products} />{children}</div>
}

// app/products/page.tsx
export default async function ProductsPage() {
  // Same URL — deduplicated, uses cached result from layout
  const products = await fetch('https://api.example.com/products').then(r => r.json())
  return <ProductGrid products={products} />
}
```

This only works for `fetch()` calls. Direct database calls are not deduplicated — use `React.cache()` for those.

---

## Rule 8: Streaming with Suspense for Progressive Page Load

Wrap slow data-fetching sections in Suspense boundaries so the page streams progressively. Fast sections render immediately, slow sections stream in when ready.

**Good (streaming with multiple Suspense boundaries):**

```tsx
// app/dashboard/page.tsx
import { Suspense } from 'react'

export default async function DashboardPage() {
  return (
    <div className="grid grid-cols-3 gap-4">
      <DashboardHeader />                         {/* renders immediately */}
      <Suspense fallback={<StatsSkeleton />}>
        <StatsSection />                          {/* streams in when ready */}
      </Suspense>
      <Suspense fallback={<ActivitySkeleton />}>
        <RecentActivity />                        {/* streams in independently */}
      </Suspense>
    </div>
  )
}
```

### Skeleton Fallback Patterns

```tsx
// Skeleton matches the layout of real content
function StatsSkeleton() {
  return (
    <div className="grid grid-cols-3 gap-4">
      {[1, 2, 3].map((i) => (
        <div key={i} className="animate-pulse h-24 bg-gray-200 rounded-lg" />
      ))}
    </div>
  )
}

// loading.tsx — automatic Suspense fallback for the entire page
// app/dashboard/loading.tsx
export default function DashboardLoading() {
  return (
    <div className="p-8 space-y-4">
      <div className="animate-pulse h-8 bg-gray-200 rounded w-1/3" />
      <div className="animate-pulse h-64 bg-gray-200 rounded" />
    </div>
  )
}
```