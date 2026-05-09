# Pagination Patterns

Cursor-based (useInfiniteQuery), offset-based, and infinite scroll with Tailwind v4 styling.

## Pagination Types

| Type | Use When | Pros | Cons |
|---|---|---|---|
| Offset | Total count known, skip to specific pages | Easy to implement, supports page numbers | Slow on large datasets, items shift on insert/delete |
| Cursor | Large/infinite datasets, real-time data | Stable position, fast on large data | No page numbers, can't skip to arbitrary page |
| Infinite scroll | Mobile, feeds, continuous browsing | Smooth UX, no pagination UI | Hard to find specific items, memory grows |

## Offset-Based Pagination

### Server Component

```tsx
// app/products/page.tsx
export default async function ProductsPage({
  searchParams,
}: {
  searchParams: Promise<{ page?: string }>;
}) {
  const params = await searchParams;
  const page = Math.max(1, Number(params.page ?? "1"));
  const pageSize = 20;

  const result = await typedFetch(
    `/api/products?page=${page}&pageSize=${pageSize}`,
    ProductListSchema
  );

  if (!result.ok) throw new Error(result.error);

  return <ProductClientPage data={result.data} currentPage={page} />;
}
```

### Client Component with nuqs

```tsx
import { useQueryState, parseAsInteger } from "nuqs";

function ProductClientPage({ data: initialData, currentPage }: Props) {
  const [page, setPage] = useQueryState("page", parseAsInteger.withDefault(1));

  const { data, isLoading } = useQuery({
    queryKey: ["products", { page }],
    queryFn: () => typedFetch(`/api/products?page=${page}&pageSize=20`, ProductListSchema).then((r) => {
      if (!r.ok) throw new Error(r.error);
      return r.data;
    }),
    initialData: page === currentPage ? initialData : undefined,
    staleTime: 60 * 1000,
  });

  if (isLoading) return <ProductSkeleton />;

  return (
    <div>
      <ProductGrid products={data.items} />
      <PaginationControls
        currentPage={page}
        totalPages={Math.ceil(data.total / data.pageSize)}
        onPageChange={setPage}
      />
    </div>
  );
}
```

### Pagination Controls Component

```tsx
function PaginationControls({
  currentPage,
  totalPages,
  onPageChange,
}: {
  currentPage: number;
  totalPages: number;
  onPageChange: (page: number) => void;
}) {
  const pages = getPageRange(currentPage, totalPages);

  return (
    <nav className="flex items-center justify-center gap-2 mt-8" aria-label="Pagination">
      <button
        onClick={() => onPageChange(currentPage - 1)}
        disabled={currentPage <= 1}
        className="px-3 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-40 hover:bg-gray-50 disabled:hover:bg-transparent"
      >
        Previous
      </button>

      {pages.map((p, idx) =>
        p === "..." ? (
          <span key={`gap-${idx}`} className="px-2 text-gray-400">...</span>
        ) : (
          <button
            key={p}
            onClick={() => onPageChange(p as number)}
            className={[
              "px-3 py-2 rounded-lg text-sm border",
              currentPage === p
                ? "border-blue-500 bg-blue-50 text-blue-600 font-medium"
                : "border-gray-200 hover:bg-gray-50",
            ].join(" ")}
          >
            {p}
          </button>
        )
      )}

      <button
        onClick={() => onPageChange(currentPage + 1)}
        disabled={currentPage >= totalPages}
        className="px-3 py-2 rounded-lg border border-gray-200 text-sm disabled:opacity-40 hover:bg-gray-50 disabled:hover:bg-transparent"
      >
        Next
      </button>
    </nav>
  );
}

function getPageRange(current: number, total: number): (number | "...")[] {
  if (total <= 7) return Array.from({ length: total }, (_, i) => i + 1);
  if (current <= 3) return [1, 2, 3, 4, "...", total];
  if (current >= total - 3) return [1, "...", total - 3, total - 2, total - 1, total];
  return [1, "...", current - 1, current, current + 1, "...", total];
}
```

## Cursor-Based Pagination (useInfiniteQuery)

### API response format

```tsx
// Cursor API returns: { items: Product[], nextCursor: string | null }
const CursorPageSchema = z.object({
  items: ProductSchema.array(),
  nextCursor: z.string().nullable(),
});

type CursorPage = z.infer<typeof CursorPageSchema>;
```

### useInfiniteQuery setup

```tsx
import { useInfiniteQuery } from "@tanstack/react-query";

function useProductsInfinite(search: string) {
  return useInfiniteQuery({
    queryKey: ["products-infinite", search],
    queryFn: async ({ pageParam }): Promise<CursorPage> => {
      const params = new URLSearchParams();
      if (search) params.set("q", search);
      if (pageParam) params.set("cursor", pageParam as string);

      const result = await typedFetch(`/api/products?${params}`, CursorPageSchema);
      if (!result.ok) throw new Error(result.error);
      return result.data;
    },
    initialPageParam: null as string | null,
    getNextPageParam: (lastPage) => lastPage.nextCursor,
    staleTime: 60 * 1000,
  });
}
```

### Flattening pages

```tsx
function InfiniteProductList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
    error,
  } = useProductsInfinite("");

  if (isLoading) return <ProductSkeleton />;
  if (error) return <ErrorBanner message={error.message} />;

  // Flatten all pages into a single list
  const products = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <div className="flex flex-col gap-6">
      <div className="grid grid-cols-3 gap-6">
        {products.map((product) => (
          <ProductCard key={product.id} product={product} />
        ))}
      </div>

      {hasNextPage && (
        <button
          onClick={() => fetchNextPage()}
          disabled={isFetchingNextPage}
          className="mx-auto px-4 py-2 rounded-lg border border-gray-200 text-sm hover:bg-gray-50 disabled:opacity-50"
        >
          {isFetchingNextPage ? "Loading..." : "Load More"}
        </button>
      )}
    </div>
  );
}
```

## Infinite Scroll

Auto-fetch next page when the user scrolls near the bottom.

### Using IntersectionObserver

```tsx
import { useInfiniteQuery } from "@tanstack/react-query";
import { useEffect, useRef } from "react";

function InfiniteScrollList() {
  const {
    data,
    fetchNextPage,
    hasNextPage,
    isFetchingNextPage,
    isLoading,
  } = useProductsInfinite("");

  const loadMoreRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!hasNextPage || isFetchingNextPage) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0].isIntersecting) {
          fetchNextPage();
        }
      },
      { rootMargin: "200px" } // trigger 200px before reaching the sentinel
    );

    const el = loadMoreRef.current;
    if (el) observer.observe(el);

    return () => observer.disconnect();
  }, [hasNextPage, isFetchingNextPage, fetchNextPage]);

  const products = data?.pages.flatMap((page) => page.items) ?? [];

  return (
    <div className="flex flex-col gap-4">
      {isLoading ? (
        <ProductSkeleton />
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {products.map((product) => (
            <ProductCard key={product.id} product={product} />
          ))}
        </div>
      )}

      {/* Sentinel element for IntersectionObserver */}
      <div ref={loadMoreRef} className="h-10 flex items-center justify-center">
        {isFetchingNextPage && (
          <div className="animate-pulse text-gray-400 text-sm">Loading more...</div>
        )}
        {!hasNextPage && products.length > 0 && (
          <div className="text-gray-400 text-sm">No more products</div>
        )}
      </div>
    </div>
  );
}
```

### With loading indicator at bottom

```tsx
// Tailwind v4 infinite scroll with smooth fade-in
function InfiniteScrollFeed() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useActivityFeed();
  const items = data?.pages.flatMap((p) => p.items) ?? [];
  const sentinelRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!hasNextPage || isFetchingNextPage) return;
    const observer = new IntersectionObserver(
      ([entry]) => { if (entry.isIntersecting) fetchNextPage(); },
      { rootMargin: "300px" }
    );
    if (sentinelRef.current) observer.observe(sentinelRef.current);
    return () => observer.disconnect();
  }, [hasNextPage, isFetchingNextPage, fetchNextPage]);

  return (
    <div className="space-y-4 max-h-[600px] overflow-y-auto scroll-smooth">
      {items.map((item, i) => (
        <div
          key={item.id}
          className="p-4 bg-white rounded-xl border border-gray-200 animate-in fade-in duration-300"
          style={{ animationDelay: `${i * 50}ms` }}
        >
          <ActivityItem item={item} />
        </div>
      ))}
      <div ref={sentinelRef}>
        {isFetchingNextPage && (
          <div className="flex justify-center py-4">
            <div className="w-6 h-6 rounded-full border-2 border-gray-300 border-t-blue-500 animate-spin" />
          </div>
        )}
      </div>
    </div>
  );
}
```

## Prefetching Next Page

Prefetch the next page when the current page loads, so navigation is instant:

```tsx
function ProductPage({ page }: { page: number }) {
  const queryClient = useQueryClient();

  // Prefetch next page
  useEffect(() => {
    queryClient.prefetchQuery({
      queryKey: ["products", { page: page + 1 }],
      queryFn: () => fetchProductsPage(page + 1),
      staleTime: 60 * 1000,
    });
  }, [page, queryClient]);

  const { data } = useQuery({
    queryKey: ["products", { page }],
    queryFn: () => fetchProductsPage(page),
  });

  return <ProductGrid products={data?.items ?? []} />;
}
```

## Anti-patterns

### Fetching all data and paginating client-side

```tsx
// WRONG: fetching everything, slicing in the client
function ProductList() {
  const { data } = useQuery({
    queryKey: ["all-products"],
    queryFn: () => fetch("/api/products").then((r) => r.json()), // returns ALL products
  });
  const page = 1;
  const paginated = data?.slice((page - 1) * 20, page * 20); // client-side pagination
}

// RIGHT: server-side pagination
function ProductList() {
  const { data } = useQuery({
    queryKey: ["products", { page }],
    queryFn: () => fetch(`/api/products?page=${page}&pageSize=20`).then((r) => r.json()),
  });
}
```

### Not resetting page on filter change

```tsx
// WRONG: page stays stale after filter change
const [page, setPage] = useQueryState("page", parseAsInteger.withDefault(1));
const [search, setSearch] = useQueryState("q", parseAsString.withDefault(""));
// When search changes, page should reset to 1

// RIGHT: reset page when filter changes
const [params, setParams] = useQueryStates({
  page: parseAsInteger.withDefault(1),
  q: parseAsString.withDefault(""),
});
const handleSearch = (q: string) => setParams({ q, page: 1 });
```

### Memory leak in infinite scroll

```tsx
// WRONG: never stops observing, pages keep growing
useEffect(() => {
  const observer = new IntersectionObserver(/* ... */);
  observer.observe(sentinelRef.current);
  // No cleanup!
}, []);

// RIGHT: cleanup observer
useEffect(() => {
  const observer = new IntersectionObserver(/* ... */);
  if (sentinelRef.current) observer.observe(sentinelRef.current);
  return () => observer.disconnect(); // cleanup on unmount or re-render
}, [hasNextPage, isFetchingNextPage]);
```