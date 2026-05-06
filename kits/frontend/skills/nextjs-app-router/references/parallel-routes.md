# Parallel Routes

## @slot Parallel Routes

Parallel routes let you render multiple pages simultaneously in the same layout. Each slot is a `@folder` directory that becomes a prop on the parent layout.

### Directory Structure

```
app/
├── dashboard/
│   ├── layout.tsx             # receives children + @slot props
│   ├── page.tsx               # /dashboard (default page)
│   ├── @analytics/            # parallel route slot
│   │   ├── page.tsx           # analytics content
│   │   ├── loading.tsx        # analytics loading state
│   │   ├── error.tsx          # analytics error boundary
│   │   └── default.tsx        # fallback when /dashboard is visited without analytics
│   ├── @team/                 # parallel route slot
│   │   ├── page.tsx           # team content
│   │   ├── default.tsx        # fallback
│   └── default.tsx            # fallback for dashboard page itself
```

### Layout Receives Slot Props

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
    <div className="flex h-screen">
      <Sidebar />
      <main className="flex-1 overflow-hidden">
        <section className="h-1/2 border-b">{analytics}</section>
        <section className="h-1/2">{team}</section>
      </main>
      <aside className="w-64">{children}</aside>
    </div>
  )
}
```

The `children` prop renders the current route's `page.tsx`. The `@analytics` and `@team` props render their respective slot pages.

### How Slots Navigate

Parallel routes navigate independently. When you visit `/dashboard/analytics`, the `@analytics` slot shows its `page.tsx`, while other slots show their `default.tsx`.

URL structure:
- `/dashboard` — all slots show `default.tsx`
- `/dashboard/analytics` — `@analytics` shows `page.tsx`, `@team` shows `default.tsx`
- `/dashboard/team` — `@team` shows `page.tsx`, `@analytics` shows `default.tsx`

### Independent Loading and Error States

Each slot has its own `loading.tsx` and `error.tsx`:

```tsx
// app/dashboard/@analytics/loading.tsx
export default function AnalyticsLoading() {
  return (
    <div className="animate-pulse space-y-2">
      <div className="h-4 bg-gray-200 rounded w-1/4" />
      <div className="h-32 bg-gray-200 rounded" />
    </div>
  )
}

// app/dashboard/@analytics/error.tsx
'use client'

export default function AnalyticsError({ error, reset }: { error: Error; reset: () => void }) {
  return (
    <div>
      <p>Analytics failed to load</p>
      <button onClick={reset}>Retry</button>
    </div>
  )
}
```

One slot's error does not affect other slots — they continue to render normally.

## default.tsx Requirement

`default.tsx` is required for every parallel route slot. It serves as the fallback when the slot is not actively matched by a URL segment. Without `default.tsx`, visiting `/dashboard` would throw an error because Next.js cannot find content for the `@analytics` and `@team` slots.

```tsx
// app/dashboard/@analytics/default.tsx
export default function AnalyticsDefault() {
  return <div className="text-gray-400">Select an analytics view</div>
}

// app/dashboard/@team/default.tsx
export default function TeamDefault() {
  return <div className="text-gray-400">Select a team view</div>
}
```

A root `default.tsx` is also needed for the `children` slot:

```tsx
// app/dashboard/default.tsx
export default function DashboardDefault() {
  return <div className="text-gray-400">Dashboard sidebar</div>
}
```

## Intercepting Routes

Intercepting routes let you show a route in a different context (typically a modal) when navigating from a specific page, while showing the full page when accessing the URL directly.

### Convention

| Convention | Meaning | Intercept from |
|------------|---------|----------------|
| `(.)` | Intercept same level | `app/photo/(.)login/` intercepts `/login` from `/photo` |
| `(..)` | Intercept one level up | `app/photo/(..)login/` intercepts `/login` from `/photo` |
| `(..)(..)` | Intercept two levels up | |
| `(...)` | Intercept from root | `app/shop/(...)cart/` intercepts `/cart` from anywhere under `/shop` |

### Modal Pattern

```tsx
// Directory structure
app/
├── login/
│   └── page.tsx               # full /login page (hard navigation)
├── photo/[id]/
│   ├── page.tsx               # /photo/:id page
│   ├── (.)login/
│   │   └── page.tsx           # intercepted /login as modal overlay
│   ├── default.tsx
│   └── layout.tsx
```

```tsx
// app/photo/[id]/layout.tsx — renders the intercepted route as a modal
export default function PhotoLayout({
  children,
  login,          // intercepted login slot
}: {
  children: React.ReactNode
  login: React.ReactNode
}) {
  return (
    <div>
      {children}
      {login && (
        <div className="fixed inset-0 bg-black/50 z-50">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-lg p-6">
            {login}            {/* login rendered as modal */}
          </div>
        </div>
      )}
    </div>
  )
}
```

When a user clicks a link to `/login` from `/photo/123`, the intercepted `(.)login/page.tsx` renders as a modal overlay. When the user navigates directly to `/login` (hard navigation, new tab, or refresh), the full `login/page.tsx` renders instead.

### Hard vs Soft Navigation

- **Soft navigation** (client-side `router.push`): Intercepting route renders as modal
- **Hard navigation** (full page load, URL typed in browser): Actual route renders as full page

### Closing the Modal

Use `router.back()` to close an intercepted modal:

```tsx
// app/photo/[id]/(.)login/page.tsx
'use client'

import { useRouter } from 'next/navigation'

export default function LoginModal() {
  const router = useRouter()

  return (
    <div>
      <h2>Login</h2>
      <form action={loginAction}>
        <input name="email" />
        <input name="password" type="password" />
        <button type="submit">Login</button>
      </form>
      <button onClick={() => router.back()}>Close</button>
    </div>
  )
}
```

### Intercepting Route with Parallel Routes

Combine intercepting routes with parallel routes for full modal behavior:

```tsx
// app/layout.tsx — root layout with intercepted login
export default function RootLayout({
  children,
  login,         // intercepted login slot (from parallel route)
}: {
  children: React.ReactNode
  login: React.ReactNode
}) {
  return (
    <html>
      <body>
        {children}
        {login && (
          <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center">
            <div className="bg-white rounded-lg max-w-md w-full p-6">
              {login}
            </div>
          </div>
        )}
      </body>
    </html>
  )
}
```

## Use Cases

| Pattern | Use case | Example |
|---------|----------|---------|
| Parallel routes | Dashboard with multiple independent panels | Analytics + Team panel |
| Intercepting routes | Modal overlay for route navigation | Login modal from photo page |
| Parallel + intercepting | Modal that shares state with parent | Edit form modal in dashboard |
| `default.tsx` | Fallback for unmatched parallel slots | Empty state when no sub-route is active |

## Anti-patterns

- **Missing `default.tsx` in a parallel route** — causes runtime error when parent route is visited
- **Using intercepting routes without `default.tsx`** — the intercepted slot needs a fallback when not active
- **Putting heavy logic in `default.tsx`** — keep it minimal; it's just a fallback
- **Relying on intercepting routes for SEO-critical pages** — intercepted routes render client-side only; the actual route must render server-side for crawlers