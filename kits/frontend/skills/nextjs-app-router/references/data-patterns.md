# Data Patterns

## Server-Side Fetch in Components

Server Components can fetch data directly with async functions. This is the preferred approach because it eliminates client-server waterfalls and reduces TTFB:

```tsx
// app/dashboard/page.tsx — async Server Component
export default async function DashboardPage() {
  const stats = await fetchDashboardStats()
  const recentActivity = await fetchRecentActivity()

  return (
    <div>
      <StatsDisplay stats={stats} />
      <ActivityFeed activities={recentActivity} />
    </div>
  )
}
```

### Fetch Options and Caching

```tsx
// Static data — fetched at build time, cached indefinitely
const data = await fetch('https://api.example.com/config', { cache: 'force-cache' })

// Dynamic data — fetched on every request, never cached
const data = await fetch('https://api.example.com/live', { cache: 'no-store' })

// ISR — revalidate every 5 minutes
const data = await fetch('https://api.example.com/products', {
  next: { revalidate: 300 },
})

// On-demand revalidation — tag-based
const data = await fetch('https://api.example.com/products', {
  next: { tags: ['products'] },
})

// In a Server Action, invalidate the tag:
import { revalidateTag } from 'next/cache'
revalidateTag('products')
```

### Direct Database Access

Server Components can access databases directly without an API route:

```tsx
// app/products/page.tsx — direct DB query in Server Component
import { db } from '@/lib/db'

export default async function ProductsPage() {
  const products = await db.product.findMany({
    orderBy: { createdAt: 'desc' },
    take: 20,
  })
  return <ProductList products={products} />
}
```

## Server Actions for Mutations

Server Actions are async functions marked with `'use server'` that execute on the server. They handle form submissions and mutations with progressive enhancement:

```tsx
// app/products/actions.ts
'use server'

import { revalidatePath } from 'next/cache'
import { db } from '@/lib/db'

export async function createProduct(formData: FormData) {
  const name = formData.get('name') as string
  const price = parseFloat(formData.get('price') as string)

  await db.product.create({ data: { name, price } })
  revalidatePath('/products')
}

export async function deleteProduct(id: string) {
  await db.product.delete({ where: { id } })
  revalidatePath('/products')
}
```

### Form Actions (Progressive Enhancement)

```tsx
// app/products/create/page.tsx
import { createProduct } from '../actions'

export default function CreateProductPage() {
  return (
    <form action={createProduct}>
      <input name="name" required className="border rounded px-2 py-1" />
      <input name="price" type="number" required className="border rounded px-2 py-1" />
      <button type="submit" className="bg-blue-600 text-white px-4 py-2 rounded">
        Create Product
      </button>
    </form>
  )
}
```

Form actions work before JavaScript loads (progressive enhancement). The form submits via standard HTML POST, and the Server Action handles it on the server.

### Programmatic Invocation with `useActionState`

For loading states, error handling, and optimistic updates:

```tsx
// app/products/create/page.tsx — Client Component with useActionState
'use client'

import { useActionState } from 'react'
import { createProduct } from '../actions'

export default function CreateProductPage() {
  const [state, formAction, isPending] = useActionState(
    async (prevState: { error?: string }, formData: FormData) => {
      try {
        await createProduct(formData)
        return { error: undefined }
      } catch (e) {
        return { error: (e as Error).message }
      }
    },
    { error: undefined }
  )

  return (
    <form action={formAction}>
      {state.error && <p className="text-red-600">{state.error}</p>}
      <input name="name" required className="border rounded px-2 py-1" />
      <button
        type="submit"
        disabled={isPending}
        className="bg-blue-600 text-white px-4 py-2 rounded disabled:opacity-50"
      >
        {isPending ? 'Creating...' : 'Create Product'}
      </button>
    </form>
  )
}
```

### Revalidation After Mutation

```tsx
// Revalidation strategies after Server Actions

// Path-based: revalidate specific pages
import { revalidatePath } from 'next/cache'
revalidatePath('/products')           // revalidate the products page
revalidatePath('/products/[id]', 'page') // revalidate all product detail pages

// Tag-based: revalidate by cache tag
import { revalidateTag } from 'next/cache'
revalidateTag('products')             // revalidate all fetches tagged 'products'

// Full revalidation: rarely needed, expensive
revalidatePath('/', 'layout')         // revalidate all pages below root layout
```

## Route Handlers for APIs

Use `route.ts` for REST API endpoints that need to handle raw HTTP requests (webhooks, streaming, file uploads):

```tsx
// app/api/webhooks/stripe/route.ts
import { headers } from 'next/headers'

export async function POST(request: Request) {
  const body = await request.text()
  const signature = (await headers()).get('stripe-signature')

  // Verify webhook signature
  const event = stripe.webhooks.constructEvent(body, signature, process.env.STRIPE_WEBHOOK_SECRET!)

  // Process event
  switch (event.type) {
    case 'payment.completed':
      await handlePaymentCompleted(event.data.object)
      break
  }

  return Response.json({ received: true })
}
```

> For full Route Handler patterns, see [route-handlers.md](route-handlers.md).

## Request Deduplication

Next.js automatically deduplicates `fetch` requests within a single render pass. Multiple components requesting the same URL produce only one network call:

```tsx
// Both components request the same URL — only one fetch happens
// app/products/layout.tsx
export default async function ProductsLayout({ children }: { children: React.ReactNode }) {
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

This only works for `fetch()` calls. Direct database calls and other async operations are not deduplicated. For those, use React `cache()`:

```tsx
import { cache } from 'react'

// Wrap a function with React cache() for deduplication within a render pass
export const getProduct = cache(async (id: string) => {
  return db.product.findUnique({ where: { id } })
})
```

## Streaming with Suspense

Wrap slow data-fetching sections in Suspense boundaries so the page streams progressively. Fast sections render immediately, slow sections stream in when ready:

```tsx
// app/dashboard/page.tsx — streaming with multiple Suspense boundaries
import { Suspense } from 'react'

export default async function DashboardPage() {
  return (
    <div>
      <DashboardHeader />              {/* renders immediately — no async */}
      <Suspense fallback={<StatsSkeleton />}>
        <StatsSection />               {/* streams in when ready */}
      </Suspense>
      <Suspense fallback={<ActivitySkeleton />}>
        <RecentActivity />              {/* streams in independently */}
      </Suspense>
    </div>
  )
}
```

### Suspense Fallback Patterns

```tsx
// Skeleton fallback — matches the layout of the real content
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

### Streaming API Response

```tsx
// app/api/stream/route.ts — streaming response from Route Handler
export async function GET() {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    async start(controller) {
      for (const item of await getItems()) {
        controller.enqueue(encoder.encode(JSON.stringify(item) + '\n'))
      }
      controller.close()
    },
  })

  return new Response(stream, {
    headers: { 'Content-Type': 'text/event-stream' },
  })
}
```

## Avoiding Waterfalls

### Problem: Sequential Client Fetches

```tsx
// BAD: Client-side waterfall — three sequential round trips
'use client'

export function DashboardPage() {
  const [user, setUser] = useState(null)
  const [stats, setStats] = useState(null)
  const [activity, setActivity] = useState(null)

  useEffect(() => {
    fetchUser().then(setUser)            // round trip 1
  }, [])

  useEffect(() => {
    if (user) fetchStats(user.id).then(setStats) // round trip 2 (depends on 1)
  }, [user])

  useEffect(() => {
    if (stats) fetchActivity(stats.period).then(setActivity) // round trip 3
  }, [stats])
}
```

### Solution: Server Component Parallel Fetches

```tsx
// GOOD: Server-side parallel fetches — all in one render pass
export default async function DashboardPage() {
  // All fetches start simultaneously on the server
  const [user, stats, activity] = await Promise.all([
    fetchUser(),
    fetchStats(),
    fetchActivity(),
  ])

  return (
    <div>
      <UserProfile user={user} />
      <StatsDisplay stats={stats} />
      <ActivityFeed activities={activity} />
    </div>
  )
}
```

### Solution: Suspense for Independent Sections

When data dependencies are truly independent, use Suspense to let each section load at its own pace:

```tsx
// GOOD: Each section resolves independently
import { Suspense } from 'react'

export default function DashboardPage() {
  return (
    <div>
      <Suspense fallback={<ProfileSkeleton />}>
        <UserProfile />       {/* fetches user data */}
      </Suspense>
      <Suspense fallback={<StatsSkeleton />}>
        <StatsDisplay />      {/* fetches stats data */}
      </Suspense>
      <Suspense fallback={<ActivitySkeleton />}>
        <ActivityFeed />      {/* fetches activity data */}
      </Suspense>
    </div>
  )
}
```

### When Sequential Fetches Are Required

If one fetch truly depends on another's result, do them sequentially in the Server Component:

```tsx
// Sequential but on the server — still faster than client waterfall
export default async function ProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)
  const reviews = await getReviews(product.id)   // depends on product.id

  return (
    <div>
      <ProductInfo product={product} />
      <ReviewList reviews={reviews} />
    </div>
  )
}
```

For independent data that might be slow, split into Suspense boundaries so the fast section renders immediately:

```tsx
export default async function ProductDetailPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)

  return (
    <div>
      <ProductInfo product={product} />
      <Suspense fallback={<ReviewSkeleton />}>
        <ReviewSection productId={product.id} />  {/* reviews stream in later */}
      </Suspense>
    </div>
  )
}
```
