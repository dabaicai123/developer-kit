# RSC Boundaries

## Server vs Client Components

In the App Router, all components are **Server Components** by default. They render on the server and send HTML to the client. Only add `'use client'` when a component needs interactivity or browser APIs.

### Server Components (default, no directive)

Server Components can:
- Fetch data directly (async functions, `fetch`, database queries)
- Access server-only resources (`cookies()`, `headers()`, environment variables)
- Import and render Client Components as children
- Keep secrets on the server (API keys, database credentials)

Server Components cannot:
- Use `useState`, `useReducer`, `useEffect`, or any stateful hook
- Use browser APIs (`window`, `document`, `localStorage`)
- Handle events (`onClick`, `onChange`, `onSubmit`)
- Import client-only libraries (e.g., libraries that access `window`)

### Client Components (`'use client'`)

Client Components can:
- Use all React hooks (`useState`, `useEffect`, `useRef`, etc.)
- Handle user events (`onClick`, `onChange`)
- Use browser APIs (`window`, `document`, `matchMedia`)
- Import client-only libraries

Client Components cannot:
- Fetch data server-side (no async component body)
- Access server-only resources (`cookies()`, `headers()`)
- Import Server Components directly (Server Components can only be passed as children)

## When to Add 'use client'

Add `'use client'` only when the component needs:

1. **Stateful hooks**: `useState`, `useReducer`, `useContext` (for client-only context)
2. **Effect hooks**: `useEffect`, `useLayoutEffect`, `useInsertionEffect`
3. **Browser APIs**: `window`, `document`, `navigator`, `matchMedia`, `addEventListener`
4. **Event handlers**: `onClick`, `onChange`, `onSubmit`, `onKeyDown`
5. **Client-only libraries**: anything that imports `window` or `document`

```tsx
// GOOD: Only interactive leaf becomes a client component
// app/products/page.tsx — Server Component
export default async function ProductsPage() {
  const products = await fetchProducts()
  return <ProductList products={products} />
}

// app/products/product-list.tsx — Client Component (needs onClick)
'use client'

export function ProductList({ products }: { products: Product[] }) {
  const [selected, setSelected] = useState<string | null>(null)
  return (
    <ul>
      {products.map((p) => (
        <li key={p.id} onClick={() => setSelected(p.id)}>
          {p.name}
        </li>
      ))}
    </ul>
  )
}
```

## The Children Pattern

Server Components can pass Client Components as `children` without making the parent a Client Component. This preserves the parent's ability to fetch data:

```tsx
// app/dashboard/page.tsx — Server Component (fetches data)
import { InteractiveChart } from './interactive-chart'

export default async function DashboardPage() {
  const data = await fetchChartData()  // server-side fetch

  // Passes server-fetched data as props to a Client Component
  // The parent stays a Server Component
  return (
    <div>
      <h1>Dashboard</h1>
      <InteractiveChart data={data} />  {/* 'use client' component */}
    </div>
  )
}
```

What you **cannot** do:

```tsx
// BAD: Server Component cannot import and call a Server Component
// from within a Client Component
'use client'

import { ServerDataFetcher } from './server-fetcher' // ERROR

export function ClientWrapper() {
  return <ServerDataFetcher /> // Server Components can't be used this way
}
```

The workaround is to pass Server Components as children or props:

```tsx
// app/layout.tsx — Server Component passes child through Client boundary
import { ClientSidebar } from './client-sidebar'
import { ServerNav } from './server-nav'

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <ClientSidebar>
      <ServerNav />           {/* Server Component passed as children */}
      {children}              {/* Server Component children propagate */}
    </ClientSidebar>
  )
}

// app/client-sidebar.tsx
'use client'

export function ClientSidebar({ children }: { children: React.ReactNode }) {
  const [isOpen, setIsOpen] = useState(false)
  return (
    <aside>
      <button onClick={() => setIsOpen(!isOpen)}>Toggle</button>
      {isOpen && children}    {/* children are still Server-rendered */}
    </aside>
  )
}
```

## Async Client Component Detection

A `'use client'` component **cannot** be an async function. If you need async data, fetch it in a Server Component parent and pass the result as props:

```tsx
// BAD: Async Client Component — this will NOT work
'use client'

export default async function ProductList() {
  const products = await fetchProducts() // ERROR: can't be async in 'use client'
  return <ul>{products.map(p => <li key={p.id}>{p.name}</li>)}</ul>
}

// GOOD: Fetch in Server Component, pass to Client Component
// app/products/page.tsx — Server Component (async)
export default async function ProductsPage() {
  const products = await fetchProducts() // server-side fetch OK
  return <ProductList products={products} />
}

// app/products/product-list.tsx — Client Component (not async)
'use client'

export function ProductList({ products }: { products: Product[] }) {
  const [filter, setFilter] = useState('')
  const filtered = products.filter(p => p.name.includes(filter))
  return (
    <div>
      <input onChange={(e) => setFilter(e.target.value)} />
      <ul>{filtered.map(p => <li key={p.id}>{p.name}</li>)}</ul>
    </div>
  )
}
```

If a Client Component needs client-side data fetching (e.g., for real-time updates), use SWR, React Query, or `use()` with Suspense on the client side.

## Non-Serializable Props

Props crossing the server-client boundary must be serializable. The following types **cannot** be passed from a Server Component to a Client Component:

| Type | Example | Why |
|------|---------|-----|
| Function | `onClick={() => ...}` | Functions are not serializable |
| Class instance | `new Date()` custom subclass | Not serializable |
| Symbol | `Symbol('key')` | Not serializable |
| DOM element | `document.createElement('div')` | Not available on server |
| WeakMap/WeakSet | `new WeakMap()` | Not serializable |

```tsx
// BAD: Passing a function from server to client
// app/page.tsx — Server Component
export default function Page() {
  const handler = () => console.log('clicked') // function — not serializable
  return <ClientButton onClick={handler} />     // ERROR at build time
}

// GOOD: Define the handler inside the Client Component
// app/page.tsx — Server Component
export default function Page() {
  return <ClientButton label="Click me" />
}

// app/client-button.tsx
'use client'

export function ClientButton({ label }: { label: string }) {
  const handleClick = () => console.log('clicked') // handler defined on client
  return <button onClick={handleClick}>{label}</button>
}
```

Regular `Date` objects, plain objects, arrays, strings, numbers, booleans, and `null` are serializable and can be passed across the boundary.

## Server Actions as an Exception

Server Actions (`'use server'`) are a special case. They allow Client Components to call server-side functions:

```tsx
// app/actions.ts — dedicated file with 'use server' at the top
'use server'

import { revalidatePath } from 'next/cache'
import { db } from '@/lib/db'

export async function createProduct(formData: FormData) {
  const name = formData.get('name') as string
  await db.product.create({ data: { name } })
  revalidatePath('/products')
}

// app/products/create/page.tsx — can be Server or Client Component
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

Client Components use Server Actions by importing them from a top-level `'use server'` module:

```tsx
// app/products/create/create-form.tsx - Client Component
'use client'

import { createProduct } from '../actions'

export function CreateProductForm() {
  return (
    <form action={createProduct}>
      <input name="name" required />
      <button type="submit">Create</button>
    </form>
  )
}
```

Server Action constraints:
- Must be async functions
- Can only accept serializable arguments and `FormData`
- Cannot use client-only hooks or APIs inside the `'use server'` function
- Return values must be serializable
- Always execute on the server, even when called from Client Components
- Inline Server Actions belong in Server Components; Client Components import actions from a top-level `'use server'` module

## Component Placement Strategy

Where to place components:

| Component type | Location | Reason |
|---|---|---|
| Server Component (data fetcher) | `app/[route]/_components/` | Close to the route that uses it |
| Client Component (interactive leaf) | `app/[route]/_components/` | Same folder, close to parent |
| Shared Server Component | `components/` | Shared across routes |
| Shared Client Component | `components/ui/` | Reusable interactive components |

Use `_components/` inside route folders for route-specific components. These private folders are excluded from routing.
