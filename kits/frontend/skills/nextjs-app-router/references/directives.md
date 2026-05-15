# Directives

## 'use client'

### Purpose

Marks a file (and all components/functions within it) as a Client Component. Client Components render on both server and client: the server pre-renders them to HTML, then the client hydrates them for interactivity.

### Placement

`'use client'` must be at the **top of the file**, before any imports or code:

```tsx
'use client'    // must be the first line in the file

import { useState } from 'react'

export function Counter() {
  const [count, setCount] = useState(0)
  return <button onClick={() => setCount(count + 1)}>Count: {count}</button>
}
```

### Scope

`'use client'` applies to the entire module. All exports from a `'use client'` file are Client Component entry points. Modules imported by that Client Component become part of the client bundle, but a Server Component can import and render a Client Component without becoming a Client Component itself.

```tsx
// components/ui/button.tsx - 'use client'
'use client'

export function Button({ children }: { children: React.ReactNode }) {
  return <button onClick={() => console.log('clicked')}><ButtonIcon />{children}</button>
}

// components/ui/button-icon.tsx - imported by Button, part of the client graph
export function ButtonIcon() {
  return <span aria-hidden>+</span>
}
```

Server Components can render Client Components at an explicit boundary. Props passed across that boundary must be serializable; event handlers and other functions stay inside the Client Component.

```tsx
// app/page.tsx - Server Component imports Client Component, boundary stays at Button
import { Button } from '@/components/ui/button'

export default function Page() {
  return (
    <div>
      <h1>Page title</h1>          {/* Server-rendered */}
      <Button>Click me</Button>    {/* Client Component boundary */}
    </div>
  )
}
```

Do not pass functions from Server Components into Client Components:

```tsx
// BAD: function props are not serializable across the Server -> Client boundary
import { Button } from '@/components/ui/button'

export default function Page() {
  return <Button onClick={() => {}}>Click me</Button>
}
```

### When to Use

| Scenario | Use 'use client'? |
|----------|-------------------|
| `useState`, `useReducer` | Yes |
| `useEffect`, `useLayoutEffect` | Yes |
| `onClick`, `onChange` handlers | Yes |
| Browser APIs (`window`, `document`) | Yes |
| Client-only libraries | Yes |
| Data fetching on server | No — use async Server Component |
| Static rendering (no interactivity) | No — use Server Component |
| Server Actions only (form actions) | No — form actions work without 'use client' |

### Common Mistakes

```tsx
// BAD: 'use client' on entire page — makes everything client-rendered
'use client'

export default function DashboardPage() {
  // This entire page and all its children lose Server Component benefits
  // No server-side data fetching, no streaming, no direct DB access
}

// GOOD: 'use client' only on interactive leaf components
// app/dashboard/page.tsx — Server Component (no directive)
export default async function DashboardPage() {
  const data = await fetchData()
  return <DashboardClient data={data} />
}

// app/dashboard/dashboard-client.tsx — Client Component (leaf)
'use client'

export function DashboardClient({ data }: { data: Data }) {
  const [selected, setSelected] = useState(null)
  // Only the interactive parts are client-rendered
}
```

## 'use server'

### Purpose

Marks a function as a Server Action — an async function that executes on the server and can be called from Client Components. Server Actions enable progressive enhancement: they work without client-side JavaScript.

### Placement

Two forms:

1. **Top of file**: Marks all exported functions as Server Actions. The file becomes a Server Action module.

```tsx
// app/actions.ts — entire file is Server Actions
'use server'

import { revalidatePath } from 'next/cache'
import { db } from '@/lib/db'

export async function createProduct(formData: FormData) {
  const name = formData.get('name') as string
  await db.product.create({ data: { name } })
  revalidatePath('/products')
}

export async function deleteProduct(formData: FormData) {
  const id = formData.get('id') as string
  await db.product.delete({ where: { id } })
  revalidatePath('/products')
}
```

2. **Inline in a Server Component**: Marks a single function inside a Server Component. Must be at the top of the function body.

```tsx
// app/products/page.tsx - Server Component with inline Server Action
import { revalidatePath } from 'next/cache'
import { db } from '@/lib/db'

export default function ProductPage() {
  async function handleDelete(formData: FormData) {
    'use server'
    const id = formData.get('id') as string
    await db.product.delete({ where: { id } })
    revalidatePath('/products')
  }

  return <form action={handleDelete}><input name="id" /><button>Delete</button></form>
}
```

Client Components must import Server Actions from a top-level `'use server'` module; do not define inline Server Actions inside a `'use client'` file.

### Rules

- Server Actions must be **async** functions
- They can only accept **serializable arguments** and `FormData`
- Return values must be **serializable** (JSON-safe)
- They cannot call client-only APIs (`useState`, `useEffect`, `window`)
- They cannot be used inside `useEffect` or event handlers directly — call them through `form action` or `startTransition`
- A `'use server'` file cannot also have `'use client'`

### Calling Server Actions from Client Components

```tsx
// Option 1: Form action (progressive enhancement — works before JS loads)
<form action={createProduct}>
  <input name="name" required />
  <button type="submit">Create</button>
</form>

// Option 2: Programmatic with startTransition (requires JS)
'use client'

import { startTransition } from 'react'
import { deleteProduct } from '../actions'

export function DeleteButton({ id }: { id: string }) {
  function handleClick() {
    startTransition(async () => {
      await deleteProduct(id)
    })
  }
  return <button onClick={handleClick}>Delete</button>
}

// Option 3: useActionState for loading/error states
'use client'

import { useActionState } from 'react'
import { createProduct } from '../actions'

export function CreateForm() {
  const [state, formAction, isPending] = useActionState(createProduct, null)
  return (
    <form action={formAction}>
      <input name="name" required />
      <button type="submit" disabled={isPending}>
        {isPending ? 'Creating...' : 'Create'}
      </button>
    </form>
  )
}
```

## 'use cache' (Experimental)

### Purpose

`'use cache'` is an experimental directive that marks a function or component's output as cacheable. It provides explicit caching control at the function level, similar to `fetch`'s `next.revalidate` but for any async operation.

### Placement

Two forms (same as `'use server'`):

1. **Top of file**: Marks all exports as cacheable.

2. **Inline in a function**: Marks a specific function as cacheable.

```tsx
// Experimental — may change in future releases
'use cache'

import { db } from '@/lib/db'

export async function getProduct(id: string) {
  return db.product.findUnique({ where: { id } })
}

// Or inline on a specific function
async function getFeaturedProducts() {
  'use cache'
  return db.product.findMany({ where: { featured: true } })
}
```

### Cache Lifetime Configuration

```tsx
'use cache'

import { cacheLife } from 'next/cache'

export async function getProduct(id: string) {
  // Configure cache lifetime
  cacheLife('hours')     // predefined profile: revalidate every hour
  return db.product.findUnique({ where: { id } })
}

// Custom profile
export async function getProducts() {
  cacheLife({
    stale: 300,    // seconds before stale
    revalidate: 600, // seconds before revalidation
    expire: 3600,    // seconds before expiration
  })
  return db.product.findMany()
}
```

### Cache Tagging for On-Demand Revalidation

```tsx
'use cache'

import { cacheTag } from 'next/cache'

export async function getProduct(id: string) {
  cacheTag(`product-${id}`)   // tag this cache entry
  return db.product.findUnique({ where: { id } })
}

// Invalidate in a Server Action
import { revalidateTag } from 'next/cache'

export async function updateProduct(id: string, data: UpdateData) {
  await db.product.update({ where: { id }, data })
  revalidateTag(`product-${id}`)
}
```

### Status

`'use cache'` is experimental and subject to change. Do not use in production without testing. Prefer `fetch` with `next.revalidate` or `React.cache()` for stable caching patterns.

## Directive Interaction Summary

| Directive | File-level | Inline | Server runtime | Client runtime |
|-----------|-----------|--------|----------------|----------------|
| `'use client'` | Yes | No | Pre-render to HTML | Hydrate + interactive |
| `'use server'` | Yes | Server Components only | Execute on server | Called via imported Server Action |
| `'use cache'` | Yes | Yes | Cache output | Transparent |

A file cannot have both `'use client'` and `'use server'`. A `'use client'` file imports Server Actions from a separate top-level `'use server'` file.
