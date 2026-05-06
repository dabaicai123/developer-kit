# Eliminating Waterfalls

Rules for eliminating sequential async operations that cause 2-10x slowdowns. Every independent fetch that waits for an unrelated await is wasted time.

---

## Rule 1: Use Promise.all() for Independent Operations

When async operations have no interdependencies, execute them concurrently.

**Bad (sequential execution, 3 round trips):**

```tsx
// app/dashboard/page.tsx
export default async function DashboardPage() {
  const user = await fetchUser()         // round trip 1
  const posts = await fetchPosts()       // round trip 2 (waits for 1 to finish)
  const comments = await fetchComments() // round trip 3 (waits for 2 to finish)

  return (
    <div>
      <UserProfile user={user} />
      <PostList posts={posts} />
      <CommentList comments={comments} />
    </div>
  )
}
```

**Good (parallel execution, 1 round trip):**

```tsx
// app/dashboard/page.tsx
export default async function DashboardPage() {
  const [user, posts, comments] = await Promise.all([
    fetchUser(),
    fetchPosts(),
    fetchComments(),
  ])

  return (
    <div>
      <UserProfile user={user} />
      <PostList posts={posts} />
      <CommentList comments={comments} />
    </div>
  )
}
```

All three fetches start simultaneously. Total wait time is the longest single fetch, not the sum of all three.

---

## Rule 2: Defer Await Until Needed

Move `await` operations into the branches where they are actually used to avoid blocking code paths that don't need them.

**Bad (blocks both branches):**

```tsx
async function handleRequest(userId: string, skipProcessing: boolean) {
  const userData = await fetchUserData(userId)

  if (skipProcessing) {
    // Returns immediately but still waited for userData
    return { skipped: true }
  }

  // Only this branch uses userData
  return processUserData(userData)
}
```

**Good (only blocks when needed):**

```tsx
async function handleRequest(userId: string, skipProcessing: boolean) {
  if (skipProcessing) {
    // Returns immediately without waiting
    return { skipped: true }
  }

  // Fetch only when needed
  const userData = await fetchUserData(userId)
  return processUserData(userData)
}
```

This is especially valuable when the skipped branch is frequently taken or when the deferred operation is expensive.

---

## Rule 3: Check Cheap Conditions Before Async Flags

When a branch uses `await` for a flag and also requires a cheap synchronous condition, evaluate the cheap condition first. Otherwise you pay for the async call even when the compound condition can never be true.

**Bad (always pays for async):**

```tsx
async function processOrder(orderId: string) {
  const featureFlag = await getFeatureFlag('newPricing')

  if (featureFlag && order.isPriority) {
    // process with new pricing
  }
}
```

**Good (skips async when sync condition fails):**

```tsx
async function processOrder(orderId: string) {
  if (order.isPriority) {
    const featureFlag = await getFeatureFlag('newPricing')
    if (featureFlag) {
      // process with new pricing
    }
  }
}
```

When `getFeatureFlag` hits the network or a feature-flag service, skipping it when `isPriority` is false removes that cost from the cold path.

---

## Rule 4: Use Suspense for Streaming Content

Instead of awaiting data in a parent component before returning JSX, use Suspense boundaries so the shell renders immediately while data streams in.

**Bad (entire page blocked by one fetch):**

```tsx
async function Page() {
  const data = await fetchData() // Blocks entire page

  return (
    <div>
      <Sidebar />
      <Header />
      <DataDisplay data={data} />
      <Footer />
    </div>
  )
}
```

Sidebar, Header, and Footer wait for `fetchData` even though only `DataDisplay` needs it.

**Good (shell renders immediately, data streams in):**

```tsx
import { Suspense } from 'react'

function Page() {
  return (
    <div>
      <Sidebar />
      <Header />
      <Suspense fallback={<Skeleton />}>
        <DataDisplay />
      </Suspense>
      <Footer />
    </div>
  )
}

async function DataDisplay() {
  const data = await fetchData() // Only blocks this component
  return <div>{data.content}</div>
}
```

Sidebar, Header, and Footer render immediately. Only `DataDisplay` waits for data.

---

## Rule 5: Share Promises Across Components with use()

When multiple components need the same data, start the fetch in the parent and pass the promise. Each child unwraps it with `use()`.

**Bad (fetching twice for the same data):**

```tsx
async function Page() {
  const data = await fetchData()

  return (
    <div>
      <DataDisplay data={data} />
      <DataSummary data={data} />
    </div>
  )
}
```

The parent must await before rendering anything.

**Good (shared promise, independent unwrapping):**

```tsx
import { use, Suspense } from 'react'

function Page() {
  // Start fetch immediately, but don't await
  const dataPromise = fetchData()

  return (
    <div>
      <Sidebar />
      <Suspense fallback={<Skeleton />}>
        <DataDisplay dataPromise={dataPromise} />
        <DataSummary dataPromise={dataPromise} />
      </Suspense>
    </div>
  )
}

function DataDisplay({ dataPromise }: { dataPromise: Promise<Data> }) {
  const data = use(dataPromise) // Unwraps the promise
  return <div>{data.content}</div>
}

function DataSummary({ dataPromise }: { dataPromise: Promise<Data> }) {
  const data = use(dataPromise) // Reuses the same promise, no extra fetch
  return <div>{data.summary}</div>
}
```

Both components share the same promise, so only one fetch occurs. The shell renders immediately while both components wait together.

---

## Rule 6: Start Promises Early in API Routes

In API routes and Server Actions, start independent operations immediately. Create all promises upfront, then await only when results are needed.

**Bad (config waits for auth, data waits for both):**

```tsx
export async function GET(request: Request) {
  const session = await auth()            // round trip 1
  const config = await fetchConfig()      // round trip 2
  const data = await fetchData(session.user.id) // round trip 3
  return Response.json({ data, config })
}
```

**Good (auth and config start immediately):**

```tsx
export async function GET(request: Request) {
  const sessionPromise = auth()
  const configPromise = fetchConfig()
  const session = await sessionPromise

  const [config, data] = await Promise.all([
    configPromise,
    fetchData(session.user.id),
  ])

  return Response.json({ data, config })
}
```

Auth and config start in parallel. Data only waits for auth (its actual dependency), not config.

---

## Rule 7: Chain Nested Fetches Per Item in Promise.all

When fetching nested data (items -> sub-items), chain each item's dependent fetch within its own promise so a slow item doesn't block the rest.

**Bad (slow item blocks all nested fetches):**

```tsx
const chats = await Promise.all(
  chatIds.map(id => getChat(id))
)

const chatAuthors = await Promise.all(
  chats.map(chat => getUser(chat.author))
)
```

If one `getChat(id)` out of 100 is slow, author fetches for the other 99 chats can't start even though their data is ready.

**Good (each item chains independently):**

```tsx
const chatAuthors = await Promise.all(
  chatIds.map(id => getChat(id).then(chat => getUser(chat.author)))
)
```

Each item independently chains `getChat` -> `getUser`. A slow chat doesn't block author fetches for the others.

---

## Rule 8: Avoid Sequential Client Fetch Chains

The worst waterfall pattern is client components that fetch in `useEffect` chains where each fetch depends on the previous result.

**Bad (three sequential round trips on the client):**

```tsx
'use client'

export function DashboardPage() {
  const [user, setUser] = useState(null)
  const [stats, setStats] = useState(null)
  const [activity, setActivity] = useState(null)

  useEffect(() => {
    fetchUser().then(setUser) // round trip 1
  }, [])

  useEffect(() => {
    if (user) fetchStats(user.id).then(setStats) // round trip 2
  }, [user])

  useEffect(() => {
    if (stats) fetchActivity(stats.period).then(setActivity) // round trip 3
  }, [stats])
}
```

**Good (server-side parallel fetches):**

```tsx
// app/dashboard/page.tsx — Server Component
export default async function DashboardPage() {
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

Or with Suspense for truly independent sections:

```tsx
import { Suspense } from 'react'

export default function DashboardPage() {
  return (
    <div>
      <Suspense fallback={<ProfileSkeleton />}>
        <UserProfile />
      </Suspense>
      <Suspense fallback={<StatsSkeleton />}>
        <StatsDisplay />
      </Suspense>
      <Suspense fallback={<ActivitySkeleton />}>
        <ActivityFeed />
      </Suspense>
    </div>
  )
}
```

---

## Rule 9: Router Prefetching

Next.js App Router automatically prefetches routes when `<Link>` components appear in the viewport. Don't disable this for performance-sensitive navigation.

**Bad (disables prefetch):**

```tsx
import Link from 'next/link'

<Link href="/dashboard" prefetch={false}>Dashboard</Link>
```

**Good (default prefetch is enabled):**

```tsx
import Link from 'next/link'

<Link href="/dashboard">Dashboard</Link>
```

For additional control, preload heavy route modules on hover intent:

```tsx
function NavItem({ href, label }: { href: string; label: string }) {
  const preload = () => {
    if (typeof window !== 'undefined') {
      void import('./dashboard-module')
    }
  }

  return (
    <Link href={href} onMouseEnter={preload} onFocus={preload}>
      {label}
    </Link>
  )
}
```

---

## When Sequential Fetches Are Required

If one fetch truly depends on another's result, do them sequentially in the Server Component. This is still faster than a client waterfall because there are no round trips between client and server:

```tsx
export default async function ProductDetailPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const product = await getProduct(id)        // must finish first
  const reviews = await getReviews(product.id) // depends on product.id

  return (
    <div>
      <ProductInfo product={product} />
      <Suspense fallback={<ReviewSkeleton />}>
        <ReviewSection productId={product.id} />
      </Suspense>
    </div>
  )
}
```

Split independent slow data into Suspense boundaries so the fast section renders immediately.