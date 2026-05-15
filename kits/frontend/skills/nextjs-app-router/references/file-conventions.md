# File Conventions

## Project Structure

A typical App Router project:

```
src/
├── app/
│   ├── layout.tsx            # Root layout (required)
│   ├── page.tsx              # Home page (/)
│   ├── loading.tsx           # Home loading state
│   ├── error.tsx             # Home error boundary
│   ├── not-found.tsx         # Home 404
│   ├── global-error.tsx      # Root error boundary (catches layout errors)
│   ├── default.tsx           # Default parallel route fallback
│   ├── favicon.ico           # Static favicon
│   ├── opengraph-image.png   # OG image for /
│   ├── robots.ts             # Dynamic robots.txt
│   ├── sitemap.ts            # Dynamic sitemap.xml
│   ├── manifest.ts           # Web app manifest
│   │
│   ├── (auth)/               # Route group — no URL segment
│   │   ├── layout.tsx        # Auth layout (different nav)
│   │   ├── login/
│   │   │   └── page.tsx      # /login
│   │   └── register/
│   │   │   └── page.tsx      # /register
│   │
│   ├── dashboard/
│   │   ├── layout.tsx        # Dashboard layout
│   │   ├── page.tsx          # /dashboard
│   │   ├── @analytics/       # Parallel route slot
│   │   │   ├── page.tsx
│   │   │   └── default.tsx
│   │   ├── @team/            # Parallel route slot
│   │   │   ├── page.tsx
│   │   │   └── default.tsx
│   │   └── default.tsx       # Fallback for unmatched slots
│   │
│   ├── products/
│   │   ├── page.tsx          # /products
│   │   ├── [id]/             # Dynamic segment
│   │   │   ├── page.tsx      # /products/:id
│   │   │   └── layout.tsx
│   │   ├── create/
│   │   │   └── page.tsx      # /products/create
│   │   │
│   │   └── (.)login/         # Intercept /login from /products
│   │       └── page.tsx
│   │
│   ├── api/
│   │   ├── auth/
│   │   │   └── route.ts      # POST /api/auth
│   │   ├── webhooks/
│   │   │   └── route.ts      # POST /api/webhooks
│   │   ├── health/
│   │   │   └── route.ts      # GET /api/health
│   │
│   └── _components/          # Private folder — not a route
│       ├── header.tsx
│       ├── footer.tsx
│
├── middleware.ts              # Middleware (runs before routes)
├── lib/
│   ├── db.ts
│   ├── auth.ts
│   ├── utils.ts
├── components/
│   ├── ui/                   # Shared UI components
│   └── features/             # Feature-specific components
```

## Special Files

### page.tsx

The only file that makes a route segment publicly accessible. Must export a React component as default. Can be async (Server Component) or `'use client'`.

```tsx
// app/products/page.tsx
export default async function ProductsPage() {
  const products = await fetchProducts()
  return <ProductList products={products} />
}
```

### layout.tsx

Wraps all pages and nested layouts within a route segment. Must accept and render `children`. Layouts persist across route navigations (state preserved). Root layout is required and must include `<html>` and `<body>`.

```tsx
// app/layout.tsx — Root layout (required)
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'MyApp',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={inter.className}>{children}</body>
    </html>
  )
}

// app/dashboard/layout.tsx — Nested layout
export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex">
      <Sidebar />
      <main className="flex-1">{children}</main>
    </div>
  )
}
```

### loading.tsx

Creates an instant loading UI. Next.js wraps the page and nested children in `<Suspense>` using this file as the fallback. Prevents blank screens during navigation.

```tsx
// app/dashboard/loading.tsx
export default function DashboardLoading() {
  return (
    <div className="p-8">
      <div className="animate-pulse space-y-4">
        <div className="h-8 bg-gray-200 rounded w-1/3" />
        <div className="h-64 bg-gray-200 rounded" />
      </div>
    </div>
  )
}
```

### error.tsx

Client Component error boundary for a route segment. Catches unexpected runtime errors. Must be `'use client'`.

```tsx
// app/error.tsx
'use client'

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <div>
      <h2>Something went wrong!</h2>
      <button onClick={reset}>Try again</button>
    </div>
  )
}
```

### not-found.tsx

Server Component 404 UI. Rendered when `notFound()` is called or when no matching route exists.

```tsx
// app/not-found.tsx
import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="text-center p-8">
      <h2 className="text-2xl font-bold">Not Found</h2>
      <Link href="/">Return home</Link>
    </div>
  )
}
```

### route.ts

API route handler. Export named functions for HTTP methods: `GET`, `POST`, `PUT`, `DELETE`, `PATCH`, `HEAD`, `OPTIONS`.

```tsx
// app/api/health/route.ts
export async function GET() {
  return Response.json({ status: 'ok' })
}
```

A `route.ts` file cannot coexist with a `page.tsx` in the same segment.

### default.tsx

Fallback UI for unmatched parallel routes. Required when using `@slot` parallel routes.

```tsx
// app/dashboard/default.tsx
export default function DashboardDefault() {
  return null
}
```

### template.tsx

Like `layout.tsx` but re-mounts on every navigation (no state persistence). Useful for page transitions or per-page analytics.

```tsx
// app/template.tsx
export default function Template({ children }: { children: React.ReactNode }) {
  return <div className="animate-fade-in">{children}</div>
}
```

## Route Segments

| Pattern | Example | Description |
|---------|---------|-------------|
| `folder` | `app/products/` | Static segment: `/products` |
| `[folder]` | `app/[id]/` | Dynamic segment: `/123` |
| `[...folder]` | `app/[...slug]/` | Catch-all: `/a/b/c` |
| `[[...folder]]` | `app/[[...slug]]/` | Optional catch-all: `/` or `/a/b/c` |
| `(folder)` | `app/(auth)/` | Route group: no URL segment, shared layout |
| `_folder` | `app/_components/` | Private folder: excluded from routing |
| `@folder` | `app/@team/` | Parallel route slot |

### Dynamic Segments (Next.js 15+)

Params are Promises in Next.js 15+. Always await:

```tsx
// app/products/[id]/page.tsx
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

### Catch-All and Optional Catch-All

```tsx
// app/docs/[...slug]/page.tsx — catch-all
// Matches /docs/a, /docs/a/b, /docs/a/b/c
export default async function DocsPage({
  params,
}: {
  params: Promise<{ slug: string[] }>
}) {
  const { slug } = await params
  // slug = ['a', 'b', 'c']
}

// app/docs/[[...slug]]/page.tsx — optional catch-all
// Matches /docs, /docs/a, /docs/a/b
```

### Route Groups

Route groups `(folder)` share a layout without creating a URL segment:

```
app/
├── (marketing)/
│   ├── layout.tsx    # Marketing layout (no nav sidebar)
│   ├── about/page.tsx  # /about (not /(marketing)/about)
│   └── contact/page.tsx # /contact
├── (dashboard)/
│   ├── layout.tsx    # Dashboard layout (sidebar nav)
│   ├── analytics/page.tsx # /analytics
│   └── settings/page.tsx  # /settings
```

## Middleware

`middleware.ts` runs before matching a route. Use for auth checks, redirects, and response modifications.

```ts
// middleware.ts
import { NextRequest, NextResponse } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('auth-token')

  if (!token && request.nextUrl.pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url))
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*', '/admin/:path*'],
}
```

Middleware runs on the Edge runtime by default. To use Node.js APIs, set `runtime: 'nodejs'` in the config.

## Parallel Routes

Use `@folder` to create parallel route slots. The parent layout receives each slot as a prop:

```tsx
// app/dashboard/layout.tsx
export default function DashboardLayout({
  children,
  analytics,
  team,
}: {
  children: React.ReactNode
  analytics: React.ReactNode
  team: React.ReactNode
}) {
  return (
    <div className="flex">
      <Sidebar />
      <main className="flex-1">
        {children}
        <div className="grid grid-cols-2 gap-4">
          <section>{analytics}</section>
          <section>{team}</section>
        </div>
      </main>
    </div>
  )
}
```

See [parallel-routes.md](parallel-routes.md) for full parallel and intercepting route patterns.

## Intercepting Routes

Intercept routes using `(.)`, `(..)`, `(...)` conventions:

| Convention | Meaning | Example |
|------------|---------|---------|
| `(.)` | Intercept same level | `app/photo/(.)login/` |
| `(..)` | Intercept one level up | `app/photo/(..)login/` |
| `(..)(..)` | Intercept two levels up | |
| `(...)` | Intercept from root | `app/photo/(...)login/` |

Intercepted routes show a modal overlay. When the URL is visited directly (hard navigation), the actual route renders instead.
