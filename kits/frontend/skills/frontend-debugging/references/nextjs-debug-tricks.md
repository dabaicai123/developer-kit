# Next.js Debug Tricks

Next.js-specific debugging techniques for cache invalidation, Suspense bailout, build issues, and routing problems.

## Cache Invalidation Debugging

Next.js App Router uses fetch caching by default. When data appears stale after a mutation, the cache is likely not invalidated properly.

### revalidateTag not working

```tsx
// Server Component with tagged fetch
async function ProductList() {
  const products = await fetch('/api/products', {
    next: { tags: ['products'] }
  }).then(r => r.json());
  return <ProductGrid items={products} />;
}

// Server Action that should invalidate
async function createProduct(formData: FormData) {
  await db.insertProduct({ name: formData.get('name') });
  revalidateTag('products'); // must match the EXACT tag used in fetch
}
```

**Common failures**:
- Tag string mismatch between `next: { tags: ['products'] }` and `revalidateTag('product')` — typo or singular vs plural
- `revalidateTag` called before the database write completes (call it after)
- Multiple tags needed but only one revalidated (check all tags your data depends on)
- Route not using the tagged fetch — the cache entry has no tag to match

**Debugging steps**:
1. Log the tag before revalidating: `console.log('revalidating tag:', 'products')`
2. Confirm the fetch uses the same tag: search for `next: { tags: [...] }` in your codebase
3. Check that `revalidateTag` is called after the mutation, not before
4. Try `revalidatePath('/products')` as a broader alternative if tag-level revalidation fails

### revalidatePath not working

```tsx
// Revalidate a specific path
async function updateProduct(id: string, data: ProductInput) {
  await db.updateProduct(id, data);
  revalidatePath(`/products/${id}`);    // revalidates this specific page
  revalidatePath('/products', 'page');  // revalidates the listing page
  revalidatePath('/products', 'layout'); // revalidates the layout
}
```

**Common failures**:
- Path doesn't match the actual route (e.g., `/products/123` but the route is `/shop/products/123`)
- Only revalidating the page but not the layout that holds shared data
- `revalidatePath('/products')` only revalidates the exact URL — not nested routes. Use `revalidatePath('/products', 'layout')` for layout-level revalidation
- Client-side navigation doesn't trigger revalidation — use `router.refresh()` for full refetch on the client

```tsx
// Client-side: force refresh after mutation
import { useRouter } from 'next/navigation';

function ProductForm() {
  const router = useRouter();

  async function handleSubmit(formData: FormData) {
    await createProduct(formData); // Server Action with revalidateTag/revalidatePath
    router.refresh(); // force server refetch of current route data
  }
}
```

## Suspense Bailout Detection

When a component inside `<Suspense>` never streams and always renders synchronously, it has bailed out of streaming. Common causes:

### Client-only hooks in Server Components

```tsx
// PROBLEM: useState in a Server Component bails out of Suspense
// This file has no "use client" directive but uses client-only hooks
async function SearchResults({ query }) {
  const [page, setPage] = useState(1); // ERROR: useState in Server Component
  const results = await search(query, page);
  return <ResultGrid items={results} />;
}

// FIX: split into server data fetch + client state
// search-results.tsx (Server Component)
async function SearchResultsServer({ query }) {
  const results = await search(query);
  return <ResultGrid items={results} />;
}

// search-results-client.tsx ("use client")
'use client';
function SearchResultsClient({ initialQuery }) {
  const [page, setPage] = useState(1);
  // client-side pagination with SWR or React Query
}
```

**Detection**:
- `next build` output shows the page as `dynamic` instead of rendering via streaming
- Suspense fallback never appears — component renders immediately
- Console warning: "Cannot use useState in a Server Component"

**Debugging steps**:
1. Run `next build` and check the route output — does it show `dynamic`?
2. Check for `cookies()`, `headers()`, `searchParams` access — these force dynamic rendering
3. Ensure Server Components don't import client-only modules (useState, useEffect, onClick)
4. Verify `"use client"` boundary is at the correct level — not too high (entire page becomes client)

### Dynamic rendering markers

These functions force dynamic rendering and bypass Suspense streaming:

```tsx
// These force dynamic rendering:
cookies();      // reads request cookies
headers();      // reads request headers
searchParams;   // in page component, if accessed directly (not awaited)
unstable_noStore(); // explicitly opt out of caching

// If your page uses any of these, it will render dynamically, not stream
```

Check your Server Components for these markers. Remove them if you want streaming.

## Debug Build

### `next build` output analysis

Run `next build` to see which routes are static vs dynamic and identify issues.

```bash
next build

# Output shows:
# Route (app)              Size     First Load JS
# ┌ ○ /                    5.2 kB   84.3 kB
# ├ ○ /about               1.1 kB   80.2 kB
# ├ λ /products/[id]       3.4 kB   86.5 kB
# └ f /dashboard           2.1 kB   85.2 kB

# ○ = static ( prerendered at build time )
# λ = dynamic ( server rendered on each request )
# f = streaming ( server rendered with Suspense streaming )
```

Key signals:
- A route that should be static shows as `λ` — check for dynamic markers (cookies, headers, searchParams)
- A route that should stream shows as `λ` instead of `f` — check for Suspense bailout
- Large First Load JS — client bundle is too heavy, check for unnecessary client components

### Debug build with verbose output

```bash
# Detailed build output
next build --debug

# Shows:
# - Which components are Server vs Client
# - Which routes use caching and which are dynamic
# - Detailed webpack/turbopack bundle analysis
# - Module dependency graph for each route
```

### Clear .next directory for clean rebuild

```bash
# When builds behave strangely (stale cache, wrong route types)
rm -rf .next
next build

# Windows:
rmdir /s /q .next
next build
```

When to clear `.next`:
- Route type changes not reflecting (static route still showing as dynamic)
- Build errors referencing files that no longer exist
- Development server caching stale data despite code changes
- After adding/removing `"use client"` directives

## Turbopack Debug Mode

Turbopack is Next.js's incremental bundler. Use it in development for faster builds.

```bash
# Enable Turbopack in dev
next dev --turbopack

# Verbose logging for debugging Turbopack issues
next dev --turbopack --experimental-verbose-logging
```

**Known Turbopack issues**:
- Some webpack plugins may not be compatible — check Turbopack compatibility docs
- CSS processing differences — Tailwind v4 should work, but check for @import order issues
- Hot module replacement (HMR) may miss some file changes — do a full page refresh if state seems stale

When Turbopack causes issues, fall back to webpack:

```bash
# Standard dev server (webpack)
next dev
```

## Route Debugging

### Dynamic route 404

```tsx
// PROBLEM: /products/abc returns 404
// Cause: generateStaticParams missing or incomplete
export async function generateStaticParams() {
  const products = await db.getAllProducts();
  return products.map(p => ({ id: p.id }));
}

// If this function is missing, Next.js only builds the page shell
// but doesn't prerender any specific product routes
```

**Debugging steps**:
1. Check that `generateStaticParams` returns all needed slug values
2. Check that the param key matches the folder name: `[id]` folder means `{ id: string }`
3. For development, dynamic routes always work — test 404s with `next build` + `next start`
4. Add `export const dynamicParams = true` to allow on-demand rendering for missing params

### Route group debugging

Route groups `(folder)` should not affect the URL. If they do, the parentheses are wrong.

```bash
# Correct route group — doesn't appear in URL
app/(marketing)/about/page.tsx → URL: /about

# Wrong — missing parentheses, becomes part of URL
app/marketing/about/page.tsx → URL: /marketing/about
```

## MCP Endpoint

Next.js provides a debug endpoint at `/api/nextjs-debug` when running in development mode.

```bash
# Access route information
curl http://localhost:3000/api/nextjs-debug

# Returns:
# - Route tree and layout hierarchy
# - Which routes are static vs dynamic
# - Cache entries and their tags
# - Active Suspense boundaries
```

Note: This endpoint is only available in development mode and should not be exposed in production.

## Quick Reference Table

| Problem | Detection | Fix |
|---|---|---|
| Stale data after mutation | Data unchanged after form submit | Check revalidateTag/revalidatePath matches fetch tags, call after mutation |
| Suspense fallback never shows | Page renders immediately, no streaming | Remove client-only hooks from Server Components, check dynamic markers |
| Route shows 404 | Page not found in production | Check generateStaticParams, verify param key matches folder name |
| Build route type wrong | Static route shows as dynamic in `next build` | Remove cookies()/headers()/searchParams access, clear .next and rebuild |
| Turbopack issues | HMR not working, CSS processing errors | Fall back to `next dev`, check compatibility, do full page refresh |
| Client navigation stale data | Data stale after client-side navigation | Use `router.refresh()` after Server Actions |