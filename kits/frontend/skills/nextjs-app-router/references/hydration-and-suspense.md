# Hydration and Suspense

## Hydration Errors

### What Is Hydration

When a Server Component renders on the server, it produces HTML. On the client, React hydrates this HTML by attaching event handlers and reconciling the server-rendered tree with the client-rendered tree. If the trees differ, hydration fails.

### Common Hydration Error Causes

1. **Mismatched content between server and client renders**

```tsx
// BAD: Different content on server vs client
'use client'

export function Greeting() {
  // Server renders "It is daytime" but client may render "It is nighttime"
  const hour = new Date().getHours()
  return <p>{hour < 18 ? 'It is daytime' : 'It is nighttime'}</p>
}

// FIX: Suppress hydration warning for intentional mismatches
'use client'

export function Greeting() {
  const hour = new Date().getHours()
  return <p suppressHydrationWarning>{hour < 18 ? 'It is daytime' : 'It is nighttime'}</p>
}
```

`suppressHydrationWarning` only suppresses the warning for the text content of that element, not its children.

2. **Browser extensions modifying DOM**

Browser extensions (grammar checkers, translation tools, ad blockers) can modify the rendered HTML before React hydrates. This causes mismatches that are outside your control.

Fix: These are typically harmless. Check if the error disappears when extensions are disabled.

3. **Using `window` or `document` during render**

```tsx
// BAD: Browser-only API during render
'use client'

export function Layout() {
  // Server: window is undefined, client: window exists
  const width = window.innerWidth // ReferenceError on server
  return <div style={{ width }}>{width}px</div>
}

// FIX: Use useEffect to defer browser-only access
'use client'

import { useState, useEffect } from 'react'

export function Layout() {
  const [width, setWidth] = useState(0)

  useEffect(() => {
    setWidth(window.innerWidth)
    window.addEventListener('resize', () => setWidth(window.innerWidth))
  }, [])

  return <div>{width > 0 ? `${width}px` : 'Loading...'}</div>
}
```

4. **Invalid HTML nesting**

```tsx
// BAD: <p> cannot contain <div>
export function Page() {
  return <p><div>Nested div inside p</div></p>  // invalid HTML
}

// FIX: Use valid nesting
export function Page() {
  return <div><p>Text</p><div>Nested div</div></div>
}
```

Invalid nesting causes the browser to restructure the DOM before React hydrates, leading to mismatches.

5. **Conditional rendering based on client-only state**

```tsx
// BAD: Different initial render between server and client
'use client'

import { useState } from 'react'

export function ThemeToggle() {
  const [isDark, setIsDark] = useState(localStorage.getItem('theme') === 'dark') // undefined on server
  return <div className={isDark ? 'dark' : 'light'}>Theme</div>
}

// FIX: Match server render, update in useEffect
'use client'

import { useState, useEffect } from 'react'

export function ThemeToggle() {
  const [isDark, setIsDark] = useState(false) // match server render (light theme)

  useEffect(() => {
    setIsDark(localStorage.getItem('theme') === 'dark') // update after hydration
  }, [])

  return <div className={isDark ? 'dark' : 'light'} suppressHydrationWarning>Theme</div>
}
```

### Debugging Hydration Errors

1. Read the error message carefully — React tells you which element differs
2. Check for browser extensions modifying DOM
3. Search for `window`, `document`, `localStorage`, `sessionStorage` usage in render functions
4. Search for `new Date()`, `Math.random()`, or `uuid()` in render functions (values differ per render)
5. Validate HTML nesting — no `<div>` inside `<p>`, no `<a>` inside `<a>`
6. Check conditional rendering that depends on client-only data
7. Use React DevTools to compare server vs client rendered output

## CSR Bailout

### What Is CSR Bailout

When a component is marked `'use client'` but its props are fully static (no hooks, no events, no browser APIs), Next.js may skip server pre-rendering and render it entirely on the client. This produces a console warning:

```
Warning: Cannot pre-render a component that requires client rendering.
```

This warning indicates that the `'use client'` directive is unnecessary — the component could be a Server Component.

### When CSR Bailout Happens

CSR bailout occurs when:
- A `'use client'` component uses `useState`, `useEffect`, or other client hooks but the initial render differs from the server render
- A component imports another component that triggers CSR bailout
- `useSearchParams()` is used in a component not wrapped in Suspense

### Fixing CSR Bailout

```tsx
// BAD: useSearchParams without Suspense causes CSR bailout
'use client'

import { useSearchParams } from 'next/navigation'

export function SearchResults() {
  const searchParams = useSearchParams() // may cause CSR bailout warning
  const q = searchParams.get('q')
  return <div>Results for: {q}</div>
}

// FIX: Wrap in Suspense
import { Suspense } from 'react'

export function SearchPage() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <SearchResults />
    </Suspense>
  )
}
```

## Suspense Boundaries

### Why Suspense

Suspense enables streaming: fast parts of a page render immediately, slow parts stream in when ready. Without Suspense, the entire page waits for all data to load before showing anything.

### Automatic Suspense (loading.tsx)

`loading.tsx` creates an automatic Suspense boundary around the page and its children:

```tsx
// app/dashboard/loading.tsx — automatic Suspense fallback
export default function DashboardLoading() {
  return (
    <div className="animate-pulse space-y-4">
      <div className="h-8 bg-gray-200 rounded w-1/3" />
      <div className="h-64 bg-gray-200 rounded" />
    </div>
  )
}
```

### Manual Suspense Boundaries

Use `<Suspense>` to wrap specific slow sections, allowing other sections to render immediately:

```tsx
import { Suspense } from 'react'

export default async function DashboardPage() {
  return (
    <div>
      <DashboardHeader />                     {/* fast — renders immediately */}
      <Suspense fallback={<StatsSkeleton />}>
        <SlowStats />                          {/* slow — streams in */}
      </Suspense>
      <Suspense fallback={<ActivitySkeleton />}>
        <RecentActivity />                     {/* slow — streams in independently */}
      </Suspense>
    </div>
  )
}
```

### Suspense Fallback Strategy

| Situation | Fallback | Example |
|-----------|----------|---------|
| Entire page | `loading.tsx` | Full page skeleton |
| Section of page | Inline Suspense | Section skeleton matching layout |
| Component with `use()` | Suspense boundary | Spinner or skeleton |
| `useSearchParams` | Suspense boundary | Loading state for search |
| Nested route | Nested Suspense | Progressively loading content |

### Hooks Requiring Suspense

Some React hooks and APIs require a Suspense boundary:

| Hook/API | Requires Suspense? | Reason |
|----------|---------------------|--------|
| `useSearchParams()` | Yes (in Server Components) | Accessing search params may suspend |
| `use()` | Yes | Suspends until the Promise resolves |
| `fetch()` in async Server Component | No (automatic) | `loading.tsx` handles it |
| `useState` | No | Client-only, never suspends |
| `useEffect` | No | Client-only, never suspends |

### use() Hook with Suspense

React `use()` reads a Promise or context. When the Promise hasn't resolved, it suspends the component:

```tsx
import { use, Suspense } from 'react'

// Wrap fetch promise with React.cache for deduplication
const getProduct = cache(async (id: string) => {
  return fetch(`https://api.example.com/products/${id}`).then(r => r.json())
})

// Server Component using use()
export function ProductDetail({ id }: { id: string }) {
  const product = use(getProduct(id)) // suspends until resolved
  return <ProductCard product={product} />
}

// Parent must wrap in Suspense
export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  return (
    <Suspense fallback={<ProductSkeleton />}>
      <ProductDetail id={id} />
    </Suspense>
  )
}
```

## Streaming Patterns

### Basic Streaming

When a Server Component is async and wrapped in Suspense, Next.js streams the HTML progressively:

1. Server renders fast content immediately
2. Suspense fallback replaces slow content
3. When slow data resolves, server streams the real content
4. Client replaces the fallback with the real content

### Nested Suspense for Progressive Loading

```tsx
export default async function Page() {
  return (
    <div>
      <Header />                                     {/* instant */}
      <Suspense fallback={<MainSkeleton />}>
        <MainContent>                                {/* streams */}
          <Suspense fallback={<SidebarSkeleton />}>
            <Sidebar />                               {/* streams independently */}
          </Suspense>
          <Suspense fallback={<CommentsSkeleton />}>
            <Comments />                              {/* streams independently */}
          </Suspense>
        </MainContent>
      </Suspense>
    </div>
  )
}
```

### Streaming with Route Handlers

```tsx
// app/api/stream/route.ts
export async function GET() {
  const encoder = new TextEncoder()

  const stream = new ReadableStream({
    async start(controller) {
      for (const chunk of await getDataChunks()) {
        controller.enqueue(encoder.encode(JSON.stringify(chunk) + '\n'))
      }
      controller.close()
    },
  })

  return new Response(stream, {
    headers: { 'Content-Type': 'text/event-stream' },
  })
}
```

### Client-Side Streaming with Suspense

For client-side data fetching with Suspense, use a library that supports Suspense mode:

```tsx
'use client'

import { Suspense } from 'react'
import { useQuery } from '@tanstack/react-query'

function ProductListInner() {
  const { data } = useQuery({
    queryKey: ['products'],
    queryFn: fetchProducts,
    suspense: true,
  })
  return <ul>{data.map(p => <li key={p.id}>{p.name}</li>)}</ul>
}

export function ProductList() {
  return (
    <Suspense fallback={<ProductListSkeleton />}>
      <ProductListInner />
    </Suspense>
  )
}
```

## Hydration and Suspense Checklist

- [ ] Server and client renders produce identical initial HTML
- [ ] No `window`, `document`, or `localStorage` during render (move to `useEffect`)
- [ ] No invalid HTML nesting (`<div>` inside `<p>`, etc.)
- [ ] `useSearchParams()` wrapped in Suspense in Server Components
- [ ] `loading.tsx` defined for routes with async data
- [ ] `error.tsx` defined at route or feature boundaries where failures should be contained
- [ ] Slow data sections wrapped in Suspense for streaming
- [ ] `suppressHydrationWarning` used only as a narrow escape hatch for intentional, unavoidable mismatches
- [ ] No `new Date()` or `Math.random()` in render unless output is deterministic, client-only after hydration, or narrowly suppressed
