---
name: nextjs-app-router
description: "Next.js App Router patterns for React Server Components, file conventions, data fetching, streaming, directives, error handling, route handlers, metadata, image/font optimization, hydration, Suspense, parallel routes, bundling, and self-hosting. Use when building or reviewing Next.js pages, layouts, server actions, or API routes."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Next.js App Router

Patterns and conventions for building Next.js applications with the App Router, React Server Components, and TypeScript.

## When to use this skill

- Creating pages, layouts, and route handlers in the App Router
- Deciding between server and client components
- Implementing data fetching with Server Components or Server Actions
- Setting up error boundaries, loading states, and Suspense streaming
- Configuring metadata, OG images, and sitemaps
- Debugging hydration mismatches and CSR bailout warnings
- Implementing parallel routes, intercepting routes, or modal patterns
- Self-hosting Next.js with Docker or standalone output

## Instructions

### 1. Understand File Conventions

The App Router uses file-based routing under `src/app/`. Each route segment is a directory containing special files:

| File | Purpose | Runs on |
|------|---------|---------|
| `page.tsx` | Route UI — publicly accessible | Server |
| `layout.tsx` | Shared layout — wraps children | Server |
| `loading.tsx` | Instant loading UI — Suspense fallback | Server |
| `error.tsx` | Error boundary for route segment | Client |
| `not-found.tsx` | 404 UI for segment | Server |
| `route.ts` | API endpoint (GET, POST, etc.) | Server |
| `default.tsx` | Fallback for unmatched parallel routes | Server |
| `template.tsx` | Re-rendered layout (no state persistence) | Server |

> For full project structure and route segment details, see `references/file-conventions.md`.

### 2. Place 'use client' Judiciously

Server Components are the default. Only add `'use client'` when a component needs:

- `useState`, `useReducer`, `useEffect`, or other React hooks with state/effects
- Browser-only APIs (`window`, `document`, `addEventListener`)
- Event handlers (`onClick`, `onChange`)
- A library that only works client-side

Push `'use client'` down to the leaf components. Keep parent components as Server Components so they can fetch data, access cookies/headers, and render children without a network round-trip.

```tsx
// app/dashboard/page.tsx — Server Component (default, no directive needed)
import { DashboardHeader } from './header'
import { StatsGrid } from './stats-grid'

export default async function DashboardPage() {
  const stats = await fetchDashboardStats() // server-side fetch

  return (
    <div>
      <DashboardHeader title="Dashboard" />
      <StatsGrid stats={stats} />
    </div>
  )
}

// app/dashboard/stats-grid.tsx — Client Component (needs onClick)
'use client'

import { useState } from 'react'

export function StatsGrid({ stats }: { stats: Stats[] }) {
  const [selected, setSelected] = useState<string | null>(null)

  return (
    <div className="grid grid-cols-3 gap-4">
      {stats.map((s) => (
        <button
          key={s.id}
          onClick={() => setSelected(s.id)}
          className={selected === s.id ? 'ring-2' : ''}
        >
          {s.label}: {s.value}
        </button>
      ))}
    </div>
  )
}
```

> For detailed RSC boundary rules and Server Action exceptions, see `references/rsc-boundaries.md`.

### 3. Fetch Data on the Server

Prefer server-side data fetching in async Server Components. This eliminates client-server waterfalls and reduces TTFB:

```tsx
// app/products/page.tsx — Server Component fetches data directly
export default async function ProductsPage() {
  const products = await fetch('https://api.example.com/products', {
    next: { revalidate: 300 }, // ISR: revalidate every 5 minutes
  }).then(r => r.json())

  return (
    <ul>
      {products.map((p: Product) => (
        <li key={p.id}>{p.name} — {p.price}</li>
      ))}
    </ul>
  )
}
```

For mutations, use Server Actions:

```tsx
// app/products/actions.ts
'use server'

import { revalidatePath } from 'next/cache'

export async function createProduct(formData: FormData) {
  const name = formData.get('name') as string

  await db.product.create({ data: { name } })
  revalidatePath('/products')
}

// app/products/create/page.tsx
import { createProduct } from '../actions'

export default function CreateProductPage() {
  return (
    <form action={createProduct}>
      <input name="name" required />
      <button type="submit">Create</button>
    </form>
  )
}
```

> For full data patterns, streaming, and waterfall avoidance, see `references/data-patterns.md`.

### 4. Handle Async APIs (Next.js 15+)

In Next.js 15+, `params` and `searchParams` are Promises. Always `await` them:

```tsx
// app/products/[id]/page.tsx — Next.js 15+ async params
export default async function ProductPage({
  params,
}: {
  params: Promise<{ id: string }>
}) {
  const { id } = await params
  const product = await getProduct(id)
  return <ProductDetail product={product} />
}
```

> For migration guide and all async API changes, see `references/async-patterns.md`.

### 5. Handle Errors and Redirects

Use `error.tsx` for route-level error boundaries and `not-found.tsx` for 404 UI:

```tsx
// app/error.tsx — Client Component (required for error boundaries)
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div className="p-8 text-center">
      <h2 className="text-xl font-bold text-red-600">Something went wrong</h2>
      <p className="mt-2 text-gray-600">{error.message}</p>
      <button onClick={reset} className="mt-4 px-4 py-2 bg-blue-600 text-white rounded">
        Try again
      </button>
    </div>
  )
}

// app/not-found.tsx — Server Component
export default function NotFound() {
  return (
    <div className="p-8 text-center">
      <h2 className="text-2xl font-bold">404 — Page not found</h2>
      <a href="/" className="mt-4 text-blue-600 underline">Go home</a>
    </div>
  )
}
```

For intentional redirects, use `redirect()` in Server Components and `useRouter().push()` in Client Components.

> For full error handling patterns, `global-error.tsx`, and `unstable_rethrow`, see `references/error-handling.md`.

### 6. Set Up Metadata and SEO

Define static metadata in `layout.tsx` and dynamic metadata with `generateMetadata`:

```tsx
// app/layout.tsx — static metadata
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: 'MyApp',
  description: 'Application description',
}

// app/products/[id]/page.tsx — dynamic metadata
export async function generateMetadata({
  params,
}: {
  params: Promise<{ id: string }>
}): Promise<Metadata> {
  const { id } = await params
  const product = await getProduct(id)

  return {
    title: product.name,
    description: product.description,
    openGraph: { title: product.name, images: [product.imageUrl] },
  }
}
```

> For OG images, sitemaps, and file-based conventions, see `references/metadata.md`.

### 7. Optimize Images and Fonts

Use `next/image` for automatic optimization and `next/font` for zero-layout-shift fonts:

```tsx
import Image from 'next/image'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export default function Hero() {
  return (
    <div className={inter.className}>
      <h1>Welcome</h1>
      <Image
        src="/hero.jpg"
        alt="Hero image"
        width={1200}
        height={600}
        sizes="(max-width: 768px) 100vw, 50vw"
        priority
      />
    </div>
  )
}
```

> For remote images, blur placeholders, and Tailwind font integration, see `references/image-font-optimization.md`.

### 8. Stream with Suspense

Wrap slow data-fetching sections in Suspense boundaries so the rest of the page renders immediately:

```tsx
// app/dashboard/page.tsx — streaming with Suspense
import { Suspense } from 'react'

export default async function DashboardPage() {
  return (
    <div>
      <DashboardHeader />              {/* renders immediately */}
      <Suspense fallback={<Skeleton />}>
        <SlowStats />                   {/* streams in when ready */}
      </Suspense>
      <Suspense fallback={<Skeleton />}>
        <RecentActivity />              {/* streams in independently */}
      </Suspense>
    </div>
  )
}
```

> For hydration debugging and CSR bailout patterns, see `references/hydration-and-suspense.md`.

### 9. Use Directives Correctly

| Directive | Where | Purpose |
|-----------|-------|---------|
| `'use client'` | Top of file | Marks component/module for client-side rendering |
| `'use server'` | Top of file or function | Marks Server Actions callable from client |
| `'use cache'` | Top of file or function | Marks function/component output as cacheable (experimental) |

> For full directive rules and placement, see `references/directives.md`.

### 10. Implement Parallel Routes and Modals

Use `@slot` directories for parallel routes and `(.)intercept` for modal interception:

```
app/
├── dashboard/
│   ├── @analytics/      ← parallel route slot
│   ├── @team/           ← parallel route slot
│   ├── default.tsx      ← fallback for unmatched slots
│   ├── layout.tsx       ← renders all slots
│   └── page.tsx
├── photo/[id]/
│   └ (.)login/          ← intercepts /login when navigating from /photo
│   └ login/             ← actual /login route
```

> For full patterns and `default.tsx` requirements, see `references/parallel-routes.md`.

### 11. Handle Bundling Issues

Server-incompatible packages (those using `window`, `document`, or Node-only APIs in client code) need configuration. Use `next.config.ts` to handle ESM/CJS mismatches and server-only package bundling:

```ts
// next.config.ts
const nextConfig = {
  serverExternalPackages: ['oracledb', 'canvas'], // keep on server only
  experimental: {
    serverComponentsExternalPackages: ['some-pkg'],
  },
}
```

> For full bundling, CSS imports, polyfills, and script loading, see `references/bundling-and-scripts.md`.

### 12. Self-Host with Standalone Output

For Docker deployment, configure standalone output:

```ts
// next.config.ts
const nextConfig = {
  output: 'standalone',
}
```

> For Docker setup, custom cache handlers, and ISR, see `references/self-hosting.md`.

## Best Practices

- **Default to Server Components** — only add `'use client'` when hooks, events, or browser APIs are needed
- **Push client boundaries down** — keep parent components server-side; wrap only interactive leaves
- **Fetch data on the server** — avoid client-side waterfalls; use async Server Components or Server Actions
- **Always add `loading.tsx`** — provides instant loading UI via Suspense; prevents blank screens
- **Use `next/image` for all images** — automatic optimization, lazy loading, and responsive sizing
- **Use `next/font` for all fonts** — zero layout shift, self-hosted, no external network requests
- **Define `error.tsx` at every route level** — prevents unhandled errors from breaking the entire layout
- **Await params/searchParams** — Next.js 15+ makes these Promises; always await before use
- **Stream with Suspense** — wrap slow sections so fast content renders immediately
- **Use Server Actions for mutations** — progressive enhancement, no client API route needed
- **Set `sizes` on responsive images** — helps Next.js generate correct srcsets for device widths

## Anti-patterns

- **Fetching in client components when server data is available** — causes waterfalls, increases TTFB, exposes API endpoints unnecessarily
- **Adding `'use client'` at the page/layout level** — makes the entire subtree client-rendered, losing Server Component benefits
- **Missing `loading.tsx`** — pages with async data show blank screens until the full route resolves
- **Using `useEffect` for data fetching** — leads to client-server waterfalls; fetch in Server Components instead
- **Missing `error.tsx`** — unhandled errors propagate up and break parent layouts
- **Passing non-serializable props from server to client** — functions, class instances, and DOM elements cannot cross the server-client boundary
- **Async client components** — `'use client'` components cannot be async; move the async data fetch to a Server Component parent
- **Using `next/router` in App Router** — the Pages Router API; use `next/navigation` instead
- **Inline event handlers on Server Components** — `onClick` requires `'use client'`; extract interactive parts into Client Components

## References

- See `references/` directory for 12 detailed reference topics:
  1. `file-conventions.md` — Project structure, special files, route segments, parallel routes, middleware
  2. `rsc-boundaries.md` — Server/client component rules, async detection, non-serializable props, Server Action exceptions
  3. `data-patterns.md` — Server fetch, Server Actions, Route Handlers, deduplication, streaming, waterfall avoidance
  4. `async-patterns.md` — Next.js 15+ async params, searchParams, cookies, headers, migration codemod
  5. `directives.md` — 'use client', 'use server', 'use cache' placement and rules
  6. `error-handling.md` — error.tsx, global-error.tsx, not-found.tsx, redirect, unstable_rethrow
  7. `route-handlers.md` — route.ts basics, GET conflicts, streaming responses, webhook patterns
  8. `metadata.md` — generateMetadata, OG images, sitemaps, file-based conventions
  9. `image-font-optimization.md` — next/image, next/font, remote images, blur placeholders, Tailwind integration
  10. `hydration-and-suspense.md` — hydration errors, CSR bailout, Suspense boundaries, streaming patterns
  11. `parallel-routes.md` — @slot parallel routes, intercepting routes, modal patterns, default.tsx
  12. `bundling-and-scripts.md` — server-incompatible packages, CSS, polyfills, ESM/CJS, next/script
  13. `self-hosting.md` — standalone output, Docker, custom cache handlers, ISR

## Related Skills

- `react-best-practices` — React component patterns, hooks, and composition
- `data-fetching` — data fetching strategies, caching, and real-time updates
- `frontend-debugging` — debugging React rendering, network, and performance issues
- `typescript-react` — TypeScript patterns for React components and props