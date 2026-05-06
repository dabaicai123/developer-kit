# URL State Patterns

Search params for filters, pagination, sort, and other shareable state. Using nuqs for typed URL state in Next.js.

## Why URL State

State stored in the URL (search params) has unique properties:
- **Survives navigation**: Going to another page and back restores the state
- **Shareable**: Users can copy the URL and share exact state (filters, sort, page)
- **Persist across reloads**: Refreshing the page keeps the state
- **Server-accessible**: RSC can read searchParams without client JS
- **Bookmarks**: Users can bookmark a specific view

Use URL state for anything a user would want to share, bookmark, or see restored after navigation.

## When to Use URL State

| Use URL state for | Use other state for |
|---|---|
| Active tab (if shareable) | Active tab (if ephemeral, local only) |
| Search query | Modal open/close |
| Filter values | Hover state |
| Sort order | Form draft (before submit) |
| Pagination page | Local toggle |
| Selected item in a list (if shareable) | Local UI transient state |

## nuqs Library

nuqs is the recommended library for typed URL state in Next.js. It handles parsing, serialization, and hydration correctly.

### Basic Usage

```tsx
import { useQueryState, parseAsString, parseAsInteger, parseAsBoolean } from "nuqs";

function ProductSearch() {
  // Each param is typed and has a default
  const [search, setSearch] = useQueryState("q", parseAsString.withDefault(""));
  const [page, setPage] = useQueryState("page", parseAsInteger.withDefault(1));
  const [showArchived, setShowArchived] = useQueryState("archived", parseAsBoolean.withDefault(false));

  return (
    <div className="flex flex-col gap-4">
      <input
        value={search}
        onChange={(e) => setSearch(e.target.value)}
        placeholder="Search products..."
      />
      <button onClick={() => setShowArchived(!showArchived)}>
        {showArchived ? "Hide Archived" : "Show Archived"}
      </button>
      <ProductList search={search} page={page} showArchived={showArchived} />
    </div>
  );
}
```

### Parsers

nuqs provides parsers for common types:

```tsx
import {
  parseAsString,
  parseAsInteger,
  parseAsFloat,
  parseAsBoolean,
  parseAsIsoDateTime,
  parseAsJson,
  parseAsStringEnum,
  parseAsArrayOf,
} from "nuqs";

// Enum: restrict to specific values
const [sort, setSort] = useQueryState(
  "sort",
  parseAsStringEnum(["name", "date", "price"]).withDefault("name")
);

// Array: comma-separated values
const [tags, setTags] = useQueryState(
  "tags",
  parseAsArrayOf(parseAsString).withDefault([])
);

// JSON object: serialized as JSON string
const [filters, setFilters] = useQueryState(
  "filters",
  parseAsJson<ProductFilters>((v) => ProductFiltersSchema.safeParse(v).success)
);
```

### Custom Parser

```tsx
import { createParser } from "nuqs";

// Custom parser for a specific type
const parseAsSortDirection = createParser({
  parse: (value) => {
    if (value === "asc" || value === "desc") return value as SortDirection;
    return null;
  },
  serialize: (value: SortDirection) => value,
});

const [direction, setDirection] = useQueryState("dir", parseAsSortDirection.withDefault("asc"));
```

### SuspenseWrapper Provider

nuqs requires a `NuqsAdapter` provider in Next.js App Router for correct hydration:

```tsx
// app/layout.tsx or app/providers.tsx
import { NuqsAdapter } from "nuqs/adapters/next";

export function Providers({ children }: { children: ReactNode }) {
  return <NuqsAdapter>{children}</NuqsAdapter>;
}
```

### Multiple params with useQueryStates

```tsx
import { useQueryStates, parseAsString, parseAsInteger, parseAsStringEnum } from "nuqs";

function ProductFilters() {
  const [params, setParams] = useQueryStates({
    q: parseAsString.withDefault(""),
    page: parseAsInteger.withDefault(1),
    sort: parseAsStringEnum(["name", "date", "price"]).withDefault("name"),
  });

  // Update individual params
  const handleSearch = (value: string) => setParams({ q: value });

  // Update multiple params at once
  const handleSortChange = (sort: string) => setParams({ sort, page: 1 }); // reset page on sort change

  return (
    <div>
      <input value={params.q} onChange={(e) => handleSearch(e.target.value)} />
      <SortSelector value={params.sort} onChange={handleSortChange} />
      <Pagination page={params.page} onPageChange={(p) => setParams({ page: p })} />
    </div>
  );
}
```

## Synchronization

### URL state drives server fetch

The URL params should be the source of truth for server data queries:

```tsx
function ProductPage() {
  const [params] = useQueryStates({
    q: parseAsString.withDefault(""),
    page: parseAsInteger.withDefault(1),
    sort: parseAsStringEnum(["name", "date"]).withDefault("name"),
  });

  // TanStack Query reads from URL state
  const { data, isLoading } = useQuery({
    queryKey: ["products", params],
    queryFn: () => fetchProducts(params),
  });

  return <ProductList data={data} isLoading={isLoading} />;
}
```

**Why this is correct**: URL state is the single source of truth. TanStack Query derives its cache key from URL params. No duplication.

### Reset dependent params

When changing a filter, reset dependent params (like page number):

```tsx
// Changing sort resets page to 1
const handleSortChange = (newSort: string) => {
  setParams({ sort: newSort, page: 1 });
};

// Changing search resets both sort and page
const handleSearch = (newQuery: string) => {
  setParams({ q: newQuery, sort: "relevance", page: 1 });
};
```

### Clear all filters

```tsx
function clearAllFilters() {
  setParams({ q: null, page: null, sort: null, tags: null }); // null removes the param from URL
}
```

## Server-Side Reading

In RSC, read searchParams directly without client JS:

```tsx
// app/products/page.tsx (Server Component)
export default async function ProductsPage({
  searchParams,
}: {
  searchParams: Promise<{ q?: string; page?: string; sort?: string }>;
}) {
  const params = await searchParams;
  const products = await db.products.findMany({
    where: { name: { contains: params.q ?? "" } },
    orderBy: { [params.sort ?? "name"]: "asc" },
    skip: ((Number(params.page ?? 1) - 1) * 20),
    take: 20,
  });

  return (
    <Suspense fallback={<ProductSkeleton />}>
      <ProductClientFilters initialParams={params} />
      <ProductGrid products={products} />
    </Suspense>
  );
}
```

## Common Patterns

### Filter bar with URL state

```tsx
function FilterBar() {
  const [params, setParams] = useQueryStates({
    status: parseAsStringEnum(["all", "active", "archived"]).withDefault("all"),
    priority: parseAsStringEnum(["all", "low", "medium", "high"]).withDefault("all"),
    assignee: parseAsString.withDefault(""),
  });

  return (
    <div className="flex gap-3 p-4 bg-gray-50 rounded-lg">
      <select
        value={params.status}
        onChange={(e) => setParams({ status: e.target.value })}
        className="border border-gray-200 rounded-md px-3 py-2"
      >
        <option value="all">All Status</option>
        <option value="active">Active</option>
        <option value="archived">Archived</option>
      </select>
      <select
        value={params.priority}
        onChange={(e) => setParams({ priority: e.target.value })}
        className="border border-gray-200 rounded-md px-3 py-2"
      >
        <option value="all">All Priority</option>
        <option value="low">Low</option>
        <option value="medium">Medium</option>
        <option value="high">High</option>
      </select>
      <button
        onClick={() => setParams({ status: null, priority: null, assignee: null })}
        className="text-sm text-gray-500 hover:text-gray-700"
      >
        Clear Filters
      </button>
    </div>
  );
}
```

### Pagination with URL state

```tsx
function Pagination({ totalItems }: { totalItems: number }) {
  const [page, setPage] = useQueryState("page", parseAsInteger.withDefault(1));
  const totalPages = Math.ceil(totalItems / PAGE_SIZE);

  return (
    <nav className="flex gap-2 justify-center mt-8">
      <button
        disabled={page <= 1}
        onClick={() => setPage(page - 1)}
        className="px-3 py-1 border border-gray-200 rounded-md disabled:opacity-50"
      >
        Previous
      </button>
      {Array.from({ length: totalPages }, (_, i) => (
        <button
          key={i + 1}
          onClick={() => setPage(i + 1)}
          className={[
            "px-3 py-1 border rounded-md",
            page === i + 1 ? "border-blue-500 bg-blue-50 text-blue-600" : "border-gray-200",
          ].join(" ")}
        >
          {i + 1}
        </button>
      ))}
      <button
        disabled={page >= totalPages}
        onClick={() => setPage(page + 1)}
        className="px-3 py-1 border border-gray-200 rounded-md disabled:opacity-50"
      >
        Next
      </button>
    </nav>
  );
}
```

## Anti-patterns

### Storing URL state AND local state for the same thing

```tsx
// WRONG: two sources of truth
const [search, setSearch] = useState("");      // local
const [urlSearch, setUrlSearch] = useQueryState("q"); // URL
// Which one is the real search value?

// RIGHT: URL state is the single source
const [search, setSearch] = useQueryState("q", parseAsString.withDefault(""));
```

### Not resetting dependent params

```tsx
// WRONG: page stays at 5 after changing search, but results are different now
const handleSearch = (q: string) => {
  setParams({ q }); // page not reset!

// RIGHT: reset page when search changes
const handleSearch = (q: string) => {
  setParams({ q, page: 1 });
};
```

### Using raw searchParams without parsing

```tsx
// WRONG: no type safety, no defaults
const page = Number(searchParams.page); // could be NaN

// RIGHT: use nuqs parser with default
const [page, setPage] = useQueryState("page", parseAsInteger.withDefault(1));
```