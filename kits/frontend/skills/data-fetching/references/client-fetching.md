# Client-Side Fetching

TanStack Query v5 for client-side data fetching: setup, queries, mutations, caching, optimistic updates, prefetching, and error handling.

## Setup

### QueryClientProvider

Wrap your app with the provider once in a Client Component layout:

```tsx
// app/providers.tsx
"use client";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { useState, type ReactNode } from "react";

export function Providers({ children }: { children: ReactNode }) {
  const [queryClient] = useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            staleTime: 60 * 1000,        // 1 minute before refetch
            gcTime: 5 * 60 * 1000,       // 5 minutes cache lifetime
            retry: 1,                    // retry once on failure
            refetchOnWindowFocus: false,  // don't refetch on focus by default
          },
        },
      })
  );

  return (
    <QueryClientProvider client={queryClient}>
      {children}
    </QueryClientProvider>
  );
}
```

**Important**: Create `QueryClient` inside `useState` (not outside the component) to avoid sharing the client across server renders in Next.js SSR.

```tsx
// app/layout.tsx
import { Providers } from "./providers";

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
```

### DevTools (optional)

```tsx
import { ReactQueryDevtools } from "@tanstack/react-query-devtools";

// Inside Providers:
<QueryClientProvider client={queryClient}>
  {children}
  <ReactQueryDevtools initialIsOpen={false} />
</QueryClientProvider>
```

## useQuery

### Basic query

```tsx
import { useQuery } from "@tanstack/react-query";
import { ProductSchema } from "@/lib/schemas";

function useProducts() {
  return useQuery({
    queryKey: ["products"],
    queryFn: async () => {
      const res = await fetch("/api/products");
      if (!res.ok) throw new Error(`Products fetch failed: ${res.status}`);
      const data = await res.json();
      return ProductSchema.array().parse(data); // Zod validation
    },
  });
}

function ProductList() {
  const { data, isLoading, error } = useProducts();

  if (isLoading) return <ProductSkeleton />;
  if (error) return <ErrorBanner message={error.message} />;
  if (!data?.length) return <EmptyState />;

  return (
    <div className="grid grid-cols-3 gap-6">
      {data.map((p) => <ProductCard key={p.id} product={p} />)}
    </div>
  );
}
```

### Query with parameters

```tsx
function useProducts(filters: ProductFilters) {
  return useQuery({
    queryKey: ["products", filters],
    queryFn: async () => {
      const params = new URLSearchParams({
        q: filters.search,
        status: filters.status,
        sort: filters.sortBy,
        page: String(filters.page),
      });
      const res = await fetch(`/api/products?${params}`);
      if (!res.ok) throw new Error(`Products fetch failed: ${res.status}`);
      return ProductListSchema.parse(await res.json());
    },
    // Don't fetch with empty/default filters
    enabled: filters.search.length > 0 || filters.status !== "all",
  });
}
```

### staleTime and gcTime

```tsx
function useUserProfile(userId: string) {
  return useQuery({
    queryKey: ["user", userId],
    queryFn: () => fetchUser(userId),
    staleTime: 5 * 60 * 1000,  // 5 min: data is fresh, no background refetch
    gcTime: 30 * 60 * 1000,    // 30 min: keep in cache even when unused
  });
}

// Common defaults:
// - Static data (categories, config): staleTime = Infinity
// - Semi-static data (user profile): staleTime = 5 min
// - Dynamic data (search results): staleTime = 0 (always refetch)
// - Real-time data (notifications): staleTime = 0 + refetchInterval
```

| Option | Default | Purpose |
|---|---|---|
| `staleTime` | 0 | How long before data is considered stale. Stale data triggers background refetch on mount/window focus. |
| `gcTime` | 5 min | How long inactive queries stay in cache. After gcTime, the data is garbage collected. |
| `enabled` | true | Set to false to pause the query. Good for dependent queries. |
| `refetchOnWindowFocus` | true | Refetch stale data when user returns to the tab. |
| `retry` | 3 | Number of retries on failure. Set to 0 or 1 for non-critical data. |

## useMutation

### Basic mutation

```tsx
import { useMutation } from "@tanstack/react-query";

function useCreateProduct() {
  return useMutation({
    mutationFn: async (input: CreateProductInput) => {
      const res = await fetch("/api/products", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(CreateProductSchema.parse(input)),
      });
      if (!res.ok) throw new Error(`Create product failed: ${res.status}`);
      return ProductSchema.parse(await res.json());
    },
    onSuccess: () => {
      // Invalidate related queries to refetch fresh data
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
  });
}

function CreateProductButton() {
  const { mutate, isPending, error } = useCreateProduct();

  return (
    <div>
      <button
        onClick={() => mutate({ name: "New Product", price: 99 })}
        disabled={isPending}
        className="bg-blue-500 text-white px-4 py-2 rounded-md disabled:opacity-50"
      >
        {isPending ? "Creating..." : "Create Product"}
      </button>
      {error && <p className="text-red-500 mt-2">{error.message}</p>}
    </div>
  );
}
```

### Optimistic updates

Show the expected result immediately, then roll back if the mutation fails.

```tsx
function useUpdateProduct() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: async (input: UpdateProductInput) => {
      const res = await fetch(`/api/products/${input.id}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(input),
      });
      if (!res.ok) throw new Error(`Update failed: ${res.status}`);
      return ProductSchema.parse(await res.json());
    },
    // Optimistic: show update immediately
    onMutate: async (input) => {
      // Cancel any ongoing refetch to avoid overwriting optimistic state
      await queryClient.cancelQueries({ queryKey: ["products"] });

      // Snapshot current state for rollback
      const previousProducts = queryClient.getQueryData(["products"]);

      // Optimistically update the cache
      queryClient.setQueryData(["products"], (old: Product[]) =>
        old.map((p) => p.id === input.id ? { ...p, ...input } : p)
      );

      return { previousProducts }; // context for rollback
    },
    // On error: roll back to snapshot
    onError: (_err, _input, context) => {
      if (context?.previousProducts) {
        queryClient.setQueryData(["products"], context.previousProducts);
      }
    },
    // On success: refetch to confirm server state
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ["products"] });
    },
  });
}
```

### Mutation with invalidation patterns

```tsx
// Invalidate all product queries
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ["products"] });
};

// Invalidate specific product + all product lists
onSuccess: (updatedProduct) => {
  queryClient.invalidateQueries({ queryKey: ["product", updatedProduct.id] });
  queryClient.invalidateQueries({ queryKey: ["products"] });
};

// Invalidate all queries matching a prefix
onSuccess: () => {
  queryClient.invalidateQueries({ queryKey: ["products"], exact: false });
  // Matches ["products"], ["products", { page: 1 }], ["products", { search: "x" }]
};

// Remove a query entirely (force fresh fetch next time)
onSuccess: () => {
  queryClient.removeQueries({ queryKey: ["products"] });
};
```

## Prefetching

Prefetch data before the user navigates to reduce perceived loading time.

```tsx
// Prefetch on hover (in a Client Component)
function ProductLink({ productId }: { productId: string }) {
  const queryClient = useQueryClient();

  const handleMouseEnter = () => {
    queryClient.prefetchQuery({
      queryKey: ["product", productId],
      queryFn: () => fetchProduct(productId),
      staleTime: 5 * 60 * 1000,
    });
  };

  return (
    <Link href={`/products/${productId}`} onMouseEnter={handleMouseEnter}>
      View Product
    </Link>
  );
}

// Prefetch in RSC (using server-side fetch + dehydration)
// app/products/page.tsx
export default async function ProductsPage() {
  const products = await getProductList(); // server fetch

  return (
    <HydrationBoundary state={dehydrate(queryClient)}>
      <ProductClientList initialData={products} />
    </HydrationBoundary>
  );
}
```

### Prefetch with router

```tsx
// Prefetch when Next.js router prefetches a page
// This happens automatically for <Link> components in Next.js
// For manual prefetch:
import { useRouter } from "next/navigation";

function NavigationItem({ href }: { href: string }) {
  const router = useRouter();
  const queryClient = useQueryClient();

  const prefetch = () => {
    router.prefetch(href); // prefetch the RSC payload
    // Also prefetch client-side queries if known
    queryClient.prefetchQuery({
      queryKey: ["page-data", href],
      queryFn: () => fetchPageData(href),
    });
  };

  return <a href={href} onMouseEnter={prefetch}>Navigate</a>;
}
```

## Error Handling

### Query error boundary

```tsx
// Wrap components that use queries in an error boundary
import { QueryErrorResetBoundary } from "@tanstack/react-query";
import { ErrorBoundary } from "react-error-boundary";

function ProductSection() {
  return (
    <QueryErrorResetBoundary>
      ({ reset }) => (
        <ErrorBoundary
          onReset={reset}
          fallbackRender={({ error, resetErrorBoundary }) => (
            <div className="flex flex-col items-center gap-4 py-12">
              <p className="text-red-600">{error.message}</p>
              <button onClick={resetErrorBoundary} className="bg-blue-500 text-white px-4 py-2 rounded-md">
                Try again
              </button>
            </div>
          )}
        >
          <ProductList />
        </ErrorBoundary>
      )}
    </QueryErrorResetBoundary>
  );
}
```

### Error classification

```tsx
// Classify errors for different UI responses
type AppError = {
  status?: number;
  message: string;
};

function getErrorUI(error: AppError) {
  if (error.status === 404) return <NotFound />;
  if (error.status === 403) return <Forbidden />;
  if (error.status === 429) return <RateLimited />;
  if (error.status >= 500) return <ServerError />;
  return <GenericError message={error.message} />;
}
```

### Retry with exponential backoff

```tsx
function useProducts() {
  return useQuery({
    queryKey: ["products"],
    queryFn: fetchProducts,
    retry: (failureCount, error) => {
      // Don't retry client errors (4xx)
      if (error.status >= 400 && error.status < 500) return false;
      // Retry up to 3 times for server errors
      return failureCount < 3;
    },
    retryDelay: (attemptIndex) => Math.min(1000 * 2 ** attemptIndex, 30000), // exponential backoff, max 30s
  });
}
```

## Initial Data from Server

Pass server-fetched data as initialData to avoid a client refetch on mount:

```tsx
// app/products/page.tsx (Server Component)
export default async function ProductsPage() {
  const products = await getProductList(); // server fetch with Zod validation

  return <ProductClientList initialData={products} />;
}

// ProductClientList.tsx (Client Component)
function ProductClientList({ initialData }: { initialData: Product[] }) {
  const { data } = useQuery({
    queryKey: ["products"],
    queryFn: () => fetch("/api/products").then((r) => r.json()).then(ProductSchema.array().parse),
    initialData,          // no refetch on mount
    staleTime: 5 * 60 * 1000, // treat as fresh for 5 min
  });

  return <ProductGrid products={data} />;
}
```

**Important**: `initialData` must match the `queryFn` return type exactly. Zod validation at both server and client ensures this.