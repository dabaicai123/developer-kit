# Client-Side Data Fetching

Rules for fetching data on the client. When data must be fetched client-side (interactive filters, real-time updates, user-specific data), use a dedicated library for deduplication, caching, and revalidation.

---

## Rule 1: Use SWR or TanStack Query -- Never Raw useEffect + fetch

Raw `useEffect + fetch` causes waterfalls, no deduplication, no caching, and stale data bugs. SWR and TanStack Query solve all of these.

**Bad (no deduplication, no caching, stale data risk):**

```tsx
'use client'

import { useState, useEffect } from 'react'

function UserList() {
  const [users, setUsers] = useState<User[]>([])
  const [error, setError] = useState<Error | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    setLoading(true)
    fetch('/api/users')
      .then(r => r.json())
      .then(setUsers)
      .catch(setError)
      .finally(() => setLoading(false))
  }, [])

  if (loading) return <Skeleton />
  if (error) return <ErrorMessage error={error} />
  return <div>{users.map(u => <UserCard key={u.id} user={u} />)}</div>
}
```

Problems: no request deduplication, no background revalidation, manual loading/error state, potential race conditions.

**Good (TanStack Query):**

```tsx
'use client'

import { useQuery } from '@tanstack/react-query'

function UserList() {
  const { data: users, error, isLoading } = useQuery({
    queryKey: ['users'],
    queryFn: () => fetch('/api/users').then(r => r.json()),
  })

  if (isLoading) return <Skeleton />
  if (error) return <ErrorMessage error={error} />
  return <div>{users.map(u => <UserCard key={u.id} user={u} />)}</div>
}
```

**Good (SWR):**

```tsx
'use client'

import useSWR from 'swr'

const fetcher = (url: string) => fetch(url).then(r => r.json())

function UserList() {
  const { data: users, error, isLoading } = useSWR('/api/users', fetcher)

  if (isLoading) return <Skeleton />
  if (error) return <ErrorMessage error={error} />
  return <div>{users.map(u => <UserCard key={u.id} user={u} />)}</div>
}
```

Both provide: automatic deduplication across component instances, background revalidation, built-in loading/error states, and caching.

---

## Rule 2: Colocate Fetch with the Consuming Component

Each component fetches its own data. Avoid top-level fetches that pass data through multiple layers of props.

**Bad (parent fetches, passes through three layers):**

```tsx
// app/dashboard/page.tsx — Server Component fetches everything
export default async function DashboardPage() {
  const [user, stats, activity, notifications] = await Promise.all([
    fetchUser(),
    fetchStats(),
    fetchActivity(),
    fetchNotifications(),
  ])

  return (
    <DashboardShell
      user={user}
      stats={stats}
      activity={activity}
      notifications={notifications}
    />
  )
}

// DashboardShell passes everything down to children
function DashboardShell({ user, stats, activity, notifications }) {
  return (
    <div>
      <UserPanel user={user} />
      <StatsPanel stats={stats} />
      <ActivityPanel activity={activity} notifications={notifications} />
    </div>
  )
}
```

Every intermediate component receives props it doesn't use. Adding a new data requirement means changing the entire chain.

**Good (each component fetches its own data):**

```tsx
// With Suspense — each section fetches independently
import { Suspense } from 'react'

export default function DashboardPage() {
  return (
    <div>
      <Suspense fallback={<UserSkeleton />}>
        <UserPanel />
      </Suspense>
      <Suspense fallback={<StatsSkeleton />}>
        <StatsPanel />
      </Suspense>
      <Suspense fallback={<ActivitySkeleton />}>
        <ActivityPanel />
      </Suspense>
    </div>
  )
}

// Each component fetches its own data
async function UserPanel() {
  const user = await fetchUser()
  return <div>{user.name}</div>
}

async function StatsPanel() {
  const stats = await fetchStats()
  return <div>{stats.summary}</div>
}
```

For client-side fetching with TanStack Query:

```tsx
'use client'

function ActivityPanel() {
  const { data: activity } = useQuery({
    queryKey: ['activity'],
    queryFn: fetchActivity,
  })
  const { data: notifications } = useQuery({
    queryKey: ['notifications'],
    queryFn: fetchNotifications,
  })
  // Component owns its own data dependencies
}
```

---

## Rule 3: Stale-While-Revalidate Pattern

Show cached data immediately, then refresh in the background. Users never wait for repeated visits.

**TanStack Query configuration:**

```tsx
'use client'

import { useQuery } from '@tanstack/react-query'

function ProductList() {
  const { data: products } = useQuery({
    queryKey: ['products'],
    queryFn: () => fetch('/api/products').then(r => r.json()),
    staleTime: 5 * 60 * 1000,    // 5 minutes — data is fresh, no refetch
    gcTime: 30 * 60 * 1000,      // 30 minutes — cached data stays in memory
    refetchOnWindowFocus: true,   // Refetch when user returns to tab
  })

  return <ProductGrid products={products} />
}
```

**SWR configuration:**

```tsx
'use client'

import useSWR from 'swr'

function ProductList() {
  const { data: products } = useSWR('/api/products', fetcher, {
    dedupingInterval: 5 * 60 * 1000,  // 5 minutes dedup window
    revalidateOnFocus: true,           // Revalidate when tab regains focus
  })

  return <ProductGrid products={products} />
}
```

### For Immutable Data

Data that never changes (config, feature flags, static content) should use aggressive caching with no revalidation:

```tsx
// TanStack Query — immutable data
const { data: config } = useQuery({
  queryKey: ['config'],
  queryFn: fetchConfig,
  staleTime: Infinity,   // Never stale, never refetch
  gcTime: Infinity,      // Keep in cache forever
})

// SWR — immutable data
const { data: config } = useSWR('/api/config', fetcher, {
  revalidateIfStale: false,
  revalidateOnFocus: false,
  revalidateOnReconnect: false,
})
```

---

## Rule 4: Request Deduplication

Multiple components requesting the same data key share one network call.

**Bad (each instance fetches independently):**

```tsx
'use client'

function UserAvatar({ userId }: { userId: string }) {
  const [user, setUser] = useState(null)
  useEffect(() => {
    fetch(`/api/users/${userId}`)
      .then(r => r.json())
      .then(setUser)
  }, [userId]) // Each avatar instance makes its own request
}
```

If 5 avatars show the same user, 5 identical requests are made.

**Good (TanStack Query deduplicates):**

```tsx
'use client'

function UserAvatar({ userId }: { userId: string }) {
  const { data: user } = useQuery({
    queryKey: ['user', userId],
    queryFn: () => fetch(`/api/users/${userId}`).then(r => r.json()),
  })

  return <img src={user.avatarUrl} alt={user.name} />
}
```

5 avatars with the same `userId` share one request. The result is cached and served to all instances.

---

## Rule 5: Mutations with Cache Invalidation

After mutations, invalidate the relevant cache keys so stale data is refreshed.

**TanStack Query mutations:**

```tsx
'use client'

import { useMutation, useQueryClient } from '@tanstack/react-query'

function CreateProduct() {
  const queryClient = useQueryClient()

  const mutation = useMutation({
    mutationFn: (name: string) =>
      fetch('/api/products', {
        method: 'POST',
        body: JSON.stringify({ name }),
      }).then(r => r.json()),
    onSuccess: () => {
      // Invalidate and refetch products list
      queryClient.invalidateQueries({ queryKey: ['products'] })
    },
  })

  return (
    <button
      onClick={() => mutation.mutate('New Product')}
      disabled={mutation.isPending}
    >
      {mutation.isPending ? 'Creating...' : 'Create'}
    </button>
  )
}
```

**SWR mutations:**

```tsx
'use client'

import { useSWRMutation } from 'swr/mutation'

async function updateUser(url: string, { arg }: { arg: Partial<User> }) {
  return fetch(url, {
    method: 'PATCH',
    body: JSON.stringify(arg),
  }).then(r => r.json())
}

function UpdateButton({ userId }: { userId: string }) {
  const { trigger } = useSWRMutation(`/api/users/${userId}`, updateUser)

  return (
    <button onClick={() => trigger({ name: 'Updated Name' })}>
      Update
    </button>
  )
}
```

---

## Rule 6: Prefetching for Navigation

Prefetch data for likely next navigations to eliminate loading states.

**TanStack Query prefetch on hover:**

```tsx
'use client'

import { useQueryClient } from '@tanstack/react-query'
import Link from 'next/link'

function NavItem({ href, label, queryKey, queryFn }: NavItemProps) {
  const queryClient = useQueryClient()

  const prefetch = () => {
    queryClient.prefetchQuery({
      queryKey,
      queryFn,
    })
  }

  return (
    <Link href={href} onMouseEnter={prefetch} onFocus={prefetch}>
      {label}
    </Link>
  )
}
```

When the user hovers over a navigation link, the data starts loading. By the time they click, the data is likely cached and the page renders instantly.

---

## When to Fetch on Server vs Client

| Scenario | Approach |
|----------|----------|
| Initial page data, SEO content | Server Component fetch |
| User-specific data after login | Server Component with auth |
| Interactive filters, search | Client-side TanStack Query |
| Real-time updates (WebSocket) | Client-side subscription |
| Data shared across many components | Server fetch + Suspense |
| Data only needed after user action | Client-side lazy fetch |
| Mutation/submit | Server Action |

When both server and client need the same data, fetch on the server first. The client library picks up the cached version and handles revalidation.