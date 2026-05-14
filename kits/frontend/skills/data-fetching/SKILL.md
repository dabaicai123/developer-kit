---
name: data-fetching
description: "Implements data fetching with server-side RSC fetch, client-side TanStack Query, Zod validation, Result<T,E>, and pagination patterns. Use when fetching API data, validating responses, handling loading/error states, or adding pagination."
version: "1.0.0"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Data Fetching

Fetch data correctly in Next.js App Router: server-side in RSC, client-side with TanStack Query, always validated with Zod.

## When to Use This Skill

- Fetching data in Server Components vs Client Components
- Setting up TanStack Query for client-side data fetching
- Validating API responses with Zod
- Implementing pagination (cursor-based, offset, infinite scroll)
- Creating typed API patterns with Result<T,E>

## Server vs Client Fetching Decision

| Scenario | Use Server (RSC) | Use Client (TanStack Query) |
|---|---|---|
| Initial page load data | Yes | No |
| SEO-critical data | Yes | No |
| Data that rarely changes | Yes | No |
| Interactive data (filters, search) | No | Yes |
| Data that updates frequently | No | Yes |
| Real-time or polling data | No | Yes |
| Data behind user interaction | No | Yes |
| Mutation responses | No | Yes (useMutation) |

## [HARD RULE] Always Validate with Zod

Every API response must be validated with Zod before use. Never trust raw JSON from any endpoint.

```tsx
// WRONG: trusting raw response
const data = await res.json() as Product[];
// TypeScript `as` does not validate at runtime. Shape mismatches cause runtime errors.

// RIGHT: Zod validation
const ProductSchema = z.object({
  id: z.string(),
  name: z.string(),
  price: z.number(),
  inStock: z.boolean(),
});

const data = ProductSchema.array().parse(await res.json());
// If the response shape doesn't match, Zod throws a clear error at the boundary.
```

**Why**: API contracts break silently. A field rename on the server causes `undefined` everywhere in the client without Zod. With Zod, you get an immediate error with the exact path and expected type.

## [HARD RULE] Always Handle Loading and Error States

Every data-fetching UI must handle three states: loading, error, and success. Never assume data is always available.

```tsx
// WRONG: no loading or error handling
function ProductList() {
  const { data } = useProducts();
  return data.map((p) => <ProductCard key={p.id} product={p} />); // crashes if data is undefined
}

// RIGHT: handle all states
function ProductList() {
  const { data, isLoading, error } = useProducts();
  if (isLoading) return <ProductSkeleton />;
  if (error) return <ErrorBanner message={error.message} />;
  if (!data) return <EmptyState message="No products found" />;
  return data.map((p) => <ProductCard key={p.id} product={p} />);
}
```

## Architecture Overview

```
┌─────────────────────────────────────────┐
│  Server Components (RSC)                │
│  - fetch() + React.cache() deduplication│
│  - Zod validation at fetch boundary     │
│  - Suspense streaming                   │
│  - generateStaticParams for SSG         │
│  - Server Actions for mutations         │
└─────────────────────────────────────────┘
          │
          │ initial data / searchParams
          ▼
┌─────────────────────────────────────────┐
│  Client Components                      │
│  - QueryClientProvider                  │
│  - useQuery / useMutation               │
│  - staleTime / gcTime                   │
│  - optimistic updates                   │
│  - prefetching                          │
│  - Result<T,E> typed responses          │
└─────────────────────────────────────────┘
```

## Related Skills

- **nextjs-app-router**: RSC, Suspense, Server Actions
- **state-management**: URL state for filters/pagination
- **forms-and-validation**: Server Actions, Zod schemas
- **typescript-react**: Result<T,E> type, discriminated unions

## References

- [server-fetching](references/server-fetching.md) - RSC fetch, React.cache, Suspense, ISR, Server Actions
- [client-fetching](references/client-fetching.md) - TanStack Query v5 setup, queries, mutations, caching
- [typed-api-patterns](references/typed-api-patterns.md) - Zod validation, Result<T,E>, typed fetch wrapper
- [pagination-patterns](references/pagination-patterns.md) - Cursor, offset, infinite scroll
