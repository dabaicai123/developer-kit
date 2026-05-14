# Error Handling

## error.tsx

`error.tsx` creates a React error boundary for a route segment. It catches unexpected runtime errors in its subtree (page, nested layouts, and child routes). Must be a Client Component.

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
    <div className="flex flex-col items-center justify-center min-h-[400px]">
      <h2 className="text-2xl font-bold text-red-600">Something went wrong</h2>
      <p className="mt-2 text-gray-500">{error.message}</p>
      {error.digest && (
        <p className="mt-1 text-xs text-gray-400">Error ID: {error.digest}</p>
      )}
      <button
        onClick={() => reset()}
        className="mt-4 px-4 py-2 bg-blue-600 text-white rounded hover:bg-blue-700"
      >
        Try again
      </button>
    </div>
  )
}
```

Key properties:
- `error`: The thrown error object. Has a `digest` property (hash) for server errors — useful for error tracking without exposing internal details.
- `reset()`: Attempts to re-render the error boundary subtree. Useful for transient errors.

### error.tsx Does NOT Catch

- Errors in the **parent layout** — layout errors propagate up to the next error boundary
- Errors in **server-only** code that runs before rendering (e.g., `generateMetadata` failures)
- Errors thrown by `redirect()` and `notFound()` — these are intentional navigation, not errors

## global-error.tsx

`global-error.tsx` catches errors in the **root layout**. It replaces the entire page when the root layout throws an error. Must be a Client Component.

```tsx
// app/global-error.tsx
'use client'

export default function GlobalError({
  error,
  reset,
}: {
  error: Error & { digest?: string }
  reset: () => void
}) {
  return (
    <html>
      <body>
        <div className="flex flex-col items-center justify-center min-h-screen bg-gray-50">
          <h2 className="text-3xl font-bold text-red-600">Application Error</h2>
          <p className="mt-2 text-gray-500">An unexpected error occurred.</p>
          <button
            onClick={() => reset()}
            className="mt-4 px-6 py-3 bg-blue-600 text-white rounded hover:bg-blue-700"
          >
            Try again
          </button>
        </div>
      </body>
    </html>
  )
}
```

Important: `global-error.tsx` must define its own `<html>` and `<body>` tags because the root layout (which normally provides them) is the component that errored.

## not-found.tsx

`not-found.tsx` renders when `notFound()` is called or when no route matches the URL. Unlike `error.tsx`, it is a Server Component.

```tsx
// app/not-found.tsx — root-level 404
import Link from 'next/link'

export default function NotFound() {
  return (
    <div className="flex flex-col items-center justify-center min-h-screen">
      <h2 className="text-4xl font-bold">404</h2>
      <p className="mt-4 text-gray-600">Page not found</p>
      <Link href="/" className="mt-6 text-blue-600 underline hover:text-blue-800">
        Return home
      </Link>
    </div>
  )
}
```

### Nested not-found.tsx

You can add `not-found.tsx` at any route level. Call `notFound()` from Server Components or Server Actions to trigger it:

```tsx
// app/products/[id]/not-found.tsx
export default function ProductNotFound() {
  return (
    <div className="text-center p-8">
      <h2>Product not found</h2>
      <p>The product you are looking for does not exist.</p>
    </div>
  )
}

// app/products/[id]/page.tsx
import { notFound } from 'next/navigation'

export default async function ProductPage({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)

  if (!product) {
    notFound() // triggers the nearest not-found.tsx
  }

  return <ProductDetail product={product} />
}
```

## Redirect Functions

### redirect() — Server-Side

Use `redirect()` in Server Components, Server Actions, and Route Handlers. It throws a special error that Next.js intercepts for navigation.

```tsx
import { redirect } from 'next/navigation'

// In a Server Component
export default async function AdminPage() {
  const session = await getSession()
  if (!session) {
    redirect('/login') // throws, not returns — code after this never runs
  }
  return <AdminDashboard />
}

// In a Server Action
'use server'

import { redirect } from 'next/navigation'

export async function login(formData: FormData) {
  const email = formData.get('email') as string
  const password = formData.get('password') as string

  const session = await authenticate(email, password)
  if (!session) {
    return { error: 'Invalid credentials' }
  }
  redirect('/dashboard') // after successful login
}
```

Important: `redirect()` throws an error internally. Code after `redirect()` will not execute. Do not wrap `redirect()` in try/catch unless you use `unstable_rethrow()`.

### useRouter() — Client-Side

Use `useRouter().push()` in Client Components for client-side navigation:

```tsx
'use client'

import { useRouter } from 'next/navigation'

export function LoginButton() {
  const router = useRouter()

  async function handleLogin() {
    const success = await login()
    if (success) {
      router.push('/dashboard') // client-side navigation
    }
  }

  return <button onClick={handleLogin}>Login</button>
}
```

### permanentRedirect()

For permanent URL changes (301 redirect):

```tsx
import { permanentRedirect } from 'next/navigation'

export default async function OldPage() {
  permanentRedirect('/new-url') // 301 redirect
}
```

### replace() vs push()

`redirect()` and `router.push()` add a new history entry. To replace the current entry (no back navigation):

```tsx
// Server-side
import { redirect } from 'next/navigation'
redirect('/dashboard') // adds history entry

// Client-side replace (no history entry)
router.replace('/dashboard')
```

## unstable_rethrow

When wrapping `redirect()` or `notFound()` in try/catch, these functions throw internal errors that Next.js must intercept. Use `unstable_rethrow()` to re-throw these special navigation errors:

```tsx
'use server'

import { redirect } from 'next/navigation'
import { unstable_rethrow } from 'next/navigation'

export async function submitForm(formData: FormData) {
  try {
    const result = await processForm(formData)
    if (result.success) {
      redirect('/success') // throws an internal error
    }
    return { error: result.error }
  } catch (error) {
    unstable_rethrow(error) // re-throw if it's a redirect/notFound error
    // Handle actual errors here
    return { error: 'Something went wrong' }
  }
}
```

Without `unstable_rethrow`, a try/catch around `redirect()` would swallow the redirect, preventing navigation. This API is called `unstable_` because it may be renamed in a future release.

## Auth Error Patterns

### Auth Check in Server Component

```tsx
// app/dashboard/page.tsx
import { redirect } from 'next/navigation'
import { getSession } from '@/lib/auth'

export default async function DashboardPage() {
  const session = await getSession()

  if (!session) {
    redirect('/login')
  }

  return <Dashboard user={session.user} />
}
```

### Auth Check in Middleware

For global auth protection, use middleware:

```ts
// middleware.ts
import { NextRequest, NextResponse } from 'next/server'

export function middleware(request: NextRequest) {
  const token = request.cookies.get('auth-token')

  if (!token && !request.nextUrl.pathname.startsWith('/login')) {
    const loginUrl = new URL('/login', request.url)
    loginUrl.searchParams.set('from', request.nextUrl.pathname)
    return NextResponse.redirect(loginUrl)
  }

  return NextResponse.next()
}

export const config = {
  matcher: ['/dashboard/:path*', '/admin/:path*', '/settings/:path*'],
}
```

### Auth Error in Server Action

```tsx
'use server'

import { redirect } from 'next/navigation'
import { unstable_rethrow } from 'next/navigation'
import { getSession } from '@/lib/auth'

export async function deleteAccount(formData: FormData) {
  const session = await getSession()
  if (!session) {
    redirect('/login')
  }

  try {
    await deleteUser(session.userId)
    redirect('/goodbye')
  } catch (error) {
    unstable_rethrow(error)
    return { error: 'Failed to delete account' }
  }
}
```

## Error Boundary Strategy

| Error type | Handler | Level |
|------------|---------|-------|
| Route segment runtime error | `error.tsx` | Per route segment |
| Root layout error | `global-error.tsx` | Root level |
| 404 / resource not found | `notFound()` + `not-found.tsx` | Per route segment or root |
| Auth redirect | `redirect()` or middleware | Server Component / middleware |
| Server Action error | Return error object | Client handles response |

### Where to Place Error Boundaries

```
app/
├── global-error.tsx        ← catches root layout errors (must include html/body)
├── error.tsx               ← catches root page errors
├── not-found.tsx           ← root 404
├── dashboard/
│   ├── error.tsx           ← catches dashboard subtree errors
│   ├── not-found.tsx       ← dashboard 404
│   ├── analytics/
│   │   ├── error.tsx       ← catches analytics errors only
│   │   └── not-found.tsx   ← analytics 404
```

Place `error.tsx` where an error should be contained: a route segment, nested feature area, or high-risk dynamic section. Without an appropriate boundary, errors in a child route propagate up to the parent layout, potentially breaking navigation for the entire section.
