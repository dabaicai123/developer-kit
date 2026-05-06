# Async Patterns (Next.js 15+)

## Overview

Next.js 15 introduced async APIs for route parameters, search params, cookies, and headers. These changes improve performance and enable better caching, but require migration from the synchronous versions used in Next.js 14.

## Async Params

Route `params` are now `Promise<Params>` instead of `Params`. Always `await` before accessing values:

```tsx
// Next.js 14 (deprecated)
export default function ProductPage({ params }: { params: { id: string } }) {
  const id = params.id // synchronous access — no longer works
  // ...
}

// Next.js 15+ (correct)
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

### GenerateMetadata with Async Params

```tsx
// app/products/[id]/page.tsx
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
  }
}

// Generate static params still returns plain objects
export async function generateStaticParams() {
  const products = await db.product.findMany()
  return products.map((p) => ({ id: p.id })) // plain objects, not Promises
}
```

### Catch-All Segments

```tsx
// app/docs/[...slug]/page.tsx
export default async function DocsPage({
  params,
}: {
  params: Promise<{ slug: string[] }>
}) {
  const { slug } = await params
  // slug = ['getting-started', 'installation']
}
```

## Async SearchParams

Page `searchParams` are now `Promise<SearchParams>`:

```tsx
// Next.js 14 (deprecated)
export default function SearchPage({ searchParams }: { searchParams: { q?: string } }) {
  const q = searchParams.q // synchronous — no longer works
  // ...
}

// Next.js 15+ (correct)
export default async function SearchPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>
}) {
  const { q } = await searchParams
  const results = await searchProducts(q ?? '')
  return <SearchResults results={results} query={q} />
}
```

Search params are Promises because they may change during streaming. By making them async, Next.js can resolve the page HTML before knowing the final search params, improving streaming performance.

## Async Cookies

`cookies()` now returns a Promise:

```tsx
// Next.js 14 (deprecated)
import { cookies } from 'next/headers'

export default function Page() {
  const token = cookies().get('auth-token') // synchronous — no longer works
  // ...
}

// Next.js 15+ (correct)
import { cookies } from 'next/headers'

export default async function Page() {
  const cookieStore = await cookies()
  const token = cookieStore.get('auth-token')
  // ...
}
```

### Setting Cookies in Server Actions

```tsx
'use server'

import { cookies } from 'next/headers'

export async function setTheme(theme: 'light' | 'dark') {
  const cookieStore = await cookies()
  cookieStore.set('theme', theme)
}
```

## Async Headers

`headers()` now returns a Promise:

```tsx
// Next.js 14 (deprecated)
import { headers } from 'next/headers'

export default function Page() {
  const userAgent = headers().get('user-agent') // synchronous — no longer works
  // ...
}

// Next.js 15+ (correct)
import { headers } from 'next/headers'

export default async function Page() {
  const headersList = await headers()
  const userAgent = headersList.get('user-agent')
  // ...
}
```

## Migration Codemod

Next.js provides a codemod to automatically migrate synchronous API usage:

```bash
npx @next/codemod@latest next-15-async-params .
```

The codemod transforms:
- `params.id` -> `{ params }: { params: Promise<{ id: string }> }` with `await params`
- `searchParams.q` -> `{ searchParams }: { searchParams: Promise<{ q?: string }> }` with `await searchParams`

Run the codemod before upgrading to Next.js 15. Review the output — the codemod may add type annotations that need refinement.

### Manual Migration Checklist

1. Find all `page.tsx`, `layout.tsx`, `error.tsx`, `not-found.tsx`, `default.tsx`, and `loading.tsx` files that use `params` or `searchParams`
2. Change the prop type from `Params` to `Promise<Params>`
3. Add `await` before accessing `params` or `searchParams`
4. Ensure the component is `async` (it must be if it uses `await`)
5. Update `generateMetadata` and `generateStaticParams` similarly
6. Replace `cookies()` synchronous calls with `await cookies()`
7. Replace `headers()` synchronous calls with `await headers()`
8. Test all dynamic routes after migration

## Async APIs in Route Handlers

Route Handlers receive `Request` directly — no changes needed for `params` or `searchParams`. However, `cookies()` and `headers()` are now async:

```tsx
// app/api/auth/route.ts
import { cookies, headers } from 'next/headers'

export async function POST(request: Request) {
  const headersList = await headers()
  const cookieStore = await cookies()

  const authHeader = headersList.get('authorization')
  const sessionToken = cookieStore.get('session')?.value

  // ...
}
```

## Handling Params in Client Components

Client Components do not receive `params` as a prop. Use `useParams()` from `next/navigation` instead:

```tsx
'use client'

import { useParams } from 'next/navigation'

export function ProductActions() {
  const params = useParams() // returns { id: string } — synchronous on client
  // No change needed; useParams is synchronous in Client Components

  return <button>Delete product {params.id}</button>
}
```

Similarly, use `useSearchParams()` for search params in Client Components:

```tsx
'use client'

import { useSearchParams } from 'next/navigation'

export function SearchFilters() {
  const searchParams = useSearchParams() // synchronous on client
  const q = searchParams.get('q')
  // ...
}
```

## Error Handling with Async APIs

When an async API call fails (e.g., `await cookies()` in a component that shouldn't be dynamic), Next.js throws an error. Handle these cases:

```tsx
// If cookies() is called in a static page, it forces dynamic rendering
// This is correct behavior but may cause unexpected revalidation

// To suppress the dynamic rendering warning, use:
export const dynamic = 'force-dynamic'

// app/dashboard/page.tsx
export const dynamic = 'force-dynamic'

export default async function DashboardPage() {
  const cookieStore = await cookies()
  // ...
}
```