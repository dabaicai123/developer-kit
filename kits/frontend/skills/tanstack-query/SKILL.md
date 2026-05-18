---
name: tanstack-query
description: "Implements TanStack Query v5 for React and Next.js frontends: QueryClient setup, providers, query keys, useQuery, useMutation, infinite queries, optimistic updates, invalidation, hydration, Devtools, and API-client integration. Use when wiring frontend components to backend APIs, managing server state, caching, pagination, mutations, or replacing raw useEffect fetch logic."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# TanStack Query

Use this skill when client components own server state: interactive filters,
user-triggered refetching, polling, pagination, infinite scroll, optimistic UI,
or mutation flows that need cache coordination.

This skill targets TanStack Query v5 for React. It is the standard for
client-owned server state in this frontend kit.

Primary official references:

- TanStack Query React docs: `https://tanstack.com/query/latest/docs/framework/react/overview`
- Query keys: `https://tanstack.com/query/latest/docs/framework/react/guides/query-keys`
- Important defaults: `https://tanstack.com/query/latest/docs/framework/react/guides/important-defaults`
- Mutations: `https://tanstack.com/query/latest/docs/framework/react/guides/mutations`
- Optimistic updates: `https://tanstack.com/query/latest/docs/framework/react/guides/optimistic-updates`
- Server rendering and hydration: `https://tanstack.com/query/latest/docs/framework/react/guides/server-rendering`
- TanStack Intent registry: `https://tanstack.com/intent/registry`

## Install

```bash
npm install @tanstack/react-query
npm install -D @tanstack/eslint-plugin-query
```

Optional during development:

```bash
npm install @tanstack/react-query-devtools
```

Use the existing package manager if the project already standardizes on `pnpm`,
`yarn`, or `bun`.

## Next.js App Router Setup

Create a client provider and instantiate `QueryClient` once per browser session.
Do not create `new QueryClient()` directly inside a component body without a
stable initializer.

```tsx
// app/providers.tsx
"use client";

import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState } from "react";

export function Providers({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60_000,
            refetchOnWindowFocus: true,
            retry: 2,
          },
        },
      }),
  );

  return (
    <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
  );
}
```

Wrap `app/layout.tsx` with `Providers`. Keep `layout.tsx` as a Server Component;
only the provider file needs `"use client"`.

## API Client Boundary

Keep network details out of components. Create a small API layer that handles:

- Base URL and environment selection.
- Credentials, auth headers, CSRF headers, or Supabase/session tokens.
- JSON parsing and non-2xx errors.
- Runtime validation with Zod when data crosses an untrusted boundary.

```ts
// lib/api/client.ts
export async function apiJson<T>(
  input: RequestInfo | URL,
  init?: RequestInit,
): Promise<T> {
  const res = await fetch(input, {
    ...init,
    headers: {
      "content-type": "application/json",
      ...init?.headers,
    },
  });

  if (!res.ok) {
    throw new Error(`Request failed: ${res.status}`);
  }

  return res.json() as Promise<T>;
}
```

If the backend exposes OpenAPI, prefer a generated typed client such as Orval,
`openapi-typescript`, or `openapi-fetch`, then wrap generated calls in query
options and hooks.

## Query Keys

Use array query keys. Put all parameters that affect the result in the key.

```ts
// lib/api/query-keys.ts
export const queryKeys = {
  products: {
    all: ["products"] as const,
    list: (filters: ProductFilters) =>
      ["products", "list", filters] as const,
    detail: (id: string) => ["products", "detail", id] as const,
  },
};
```

Rules:

- Never use string concatenation for keys.
- Keep keys serializable and deterministic.
- Do not include unstable object identities; normalize filters first when needed.
- Invalidate the narrowest key that covers changed data.

## Queries

Prefer colocated query option factories for reuse in hooks, prefetching, and
tests.

```tsx
import { queryOptions, useQuery } from "@tanstack/react-query";
import { apiJson } from "@/lib/api/client";
import { queryKeys } from "@/lib/api/query-keys";

export function productListOptions(filters: ProductFilters) {
  return queryOptions({
    queryKey: queryKeys.products.list(filters),
    queryFn: () => apiJson<Product[]>(`/api/products?${toSearch(filters)}`),
    staleTime: 60_000,
  });
}

export function useProducts(filters: ProductFilters) {
  return useQuery(productListOptions(filters));
}
```

Every query UI must handle loading, error, empty, and success states. Prefer
skeletons for page sections and inline spinners for compact controls.

## Mutations

Use `useMutation` for writes. After success, update the cache from the mutation
response or invalidate affected queries.

```tsx
import { useMutation, useQueryClient } from "@tanstack/react-query";

export function useCreateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (input: CreateProductInput) =>
      apiJson<Product>("/api/products", {
        method: "POST",
        body: JSON.stringify(input),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: queryKeys.products.all });
    },
  });
}
```

Use optimistic updates only when the user experience needs immediate feedback.
Always cancel in-flight queries, snapshot previous cache data, rollback on
error, and invalidate on settlement.

## Pagination and Infinite Queries

Use ordinary `useQuery` for URL-driven page/limit pagination. Use
`useInfiniteQuery` only for load-more or infinite-scroll experiences.

Query keys must include filters but not the page cursor for infinite queries;
the cursor belongs in `pageParam`.

## Server Rendering and Hydration

Default to Server Components for initial SEO-critical data. Use TanStack Query
hydration when the same data must be prefetched on the server and then owned by
a Client Component for refetching, polling, mutation coordination, or optimistic
updates.

Avoid double-fetching by either:

- Fetching in a Server Component and passing plain data into presentational
  Client Components, or
- Prefetching into a `QueryClient`, dehydrating it, and reading it with
  `useQuery` under a hydration boundary.

Do not mix both approaches for the same data without a clear reason.

## Defaults and Gotchas

- Query data is considered stale by default. Set `staleTime` intentionally.
- Inactive queries remain cached before garbage collection; configure `gcTime`
  only when the default is wrong for the product.
- Query functions must return data or throw. Do not return `undefined`.
- Use `enabled` for dependent queries.
- Use `placeholderData` or `keepPreviousData`-style patterns for smoother page
  transitions when changing filters.
- Do not mirror server state into Zustand or local component state.
- Do not fetch with raw `useEffect` unless the request is not server state.
- Add TanStack Query Devtools only in development.
- Add `@tanstack/eslint-plugin-query` when touching shared Query code.

## Related Skills

- `frontend-api-contracts` for backend API contracts, generated clients, Zod
  validation, normalized errors, and mocks.
- `frontend-quality-gates` for loading/error/empty verification, smoke tests,
  and release checks.
- `nextjs-supabase-template` for Supabase auth/session integration before API
  calls that depend on identity.
