---
name: state-management
description: "Chooses React state management across useState, useReducer, context, Zustand, TanStack Query, and URL state. Use when deciding where state belongs, designing stores, or avoiding server-state duplication."
version: "1.0.0"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# State Management

Choose the right state mechanism for every piece of state in your React app.

## When to Use This Skill

- Deciding where a piece of state should live
- Setting up Zustand stores for client-side global state
- Handling URL state for filters, pagination, and sort
- Avoiding common state management mistakes (storing server data, derived state)

## Decision Framework

| Mechanism | When to Use | Examples |
|---|---|---|
| `useState` | Local UI state used by one component | Modal open/close, hover, local toggle |
| `useReducer` | Local state with complex transitions, many actions | Multi-step form, game state, complex editor |
| React Context | State shared across many components at various depths | Theme, locale, auth identity (not auth data) |
| Zustand | Global client-only state needed by unrelated components | UI preferences, draft form data, feature flags |
| Server Components / route loaders | Server data needed before render in Next.js App Router | Product detail, dashboard summary, SEO content |
| TanStack Query | Server state owned by Client Components that needs caching, refetching, or background sync | Client-side search results, live filters, optimistic mutations |
| URL state (nuqs) | State that should survive navigation, be shareable, or persist across page loads | Filters, sort, pagination, selected tab, search query |

### Decision Flow

Use this order for Next.js App Router projects:

1. **Server data needed before render** - fetch in a Server Component or route handler.
2. **Server state owned by a Client Component** - use TanStack Query.
3. **Shareable navigation state** - use URL state (nuqs).
4. **Global client-only state** - use Zustand.
5. **Subtree state** - use React Context.
6. **Complex local transitions** - use useReducer.
7. **Simple local UI state** - use useState.

Legacy shorthand below should be read through the server/client boundary rule above.

1. **Is it server data?** → Server Component fetch for initial render; TanStack Query for Client Component server state.
2. **Should it survive page navigation or be shareable via URL?** → URL state (nuqs).
3. **Is it needed by many unrelated components across the app?** → Zustand.
4. **Is it needed by many components within a subtree?** → React Context.
5. **Is it complex state with many interdependent transitions?** → useReducer.
6. **Is it local to one component?** → useState.

## [HARD RULE] Never Store Server Data in Zustand

Do NOT put server data in Zustand or plain `useState` caches. In Next.js App Router, fetch server data in Server Components when it is needed for initial render. Use TanStack Query when a Client Component owns server state that needs caching, refetching, optimistic updates, or background synchronization.

```tsx
// WRONG: storing server data in Zustand
const useProductStore = create((set) => ({
  products: [],
  loading: false,
  error: null,
  fetchProducts: async () => {
    set({ loading: true });
    try {
      const res = await fetch("/api/products");
      set({ products: await res.json(), loading: false });
    } catch (e) {
      set({ error: e, loading: false });
    }
  },
}));

// RIGHT: TanStack Query handles all server state
function useProducts() {
  return useQuery({
    queryKey: ["products"],
    queryFn: () => fetch("/api/products").then((r) => r.json()),
  });
}
```

**Why**: TanStack Query handles caching, refetching, stale-while-revalidate, background updates, and deduplication automatically. Storing this in Zustand means you have to reimplement all of that manually.

## [HARD RULE] Never Derive Computable State

Do not store values that can be computed from existing state. Compute them during render.

```tsx
// WRONG: storing derived state
const useCartStore = create((set) => ({
  items: [],
  total: 0,            // derived from items
  itemCount: 0,        // derived from items
  addItem: (item) => set((s) => ({
    items: [...s.items, item],
    total: s.total + item.price,     // redundant computation
    itemCount: s.itemCount + 1,      // redundant computation
  })),
}));

// RIGHT: compute during render
const useCartStore = create((set) => ({
  items: [],
  addItem: (item) => set((s) => ({ items: [...s.items, item] })),
}));

// In component:
function CartSummary() {
  const items = useCartStore((s) => s.items);
  const total = items.reduce((sum, i) => sum + i.price, 0);
  const itemCount = items.length;
  return <div>Total: {total} ({itemCount} items)</div>;
}
```

**Why**: Derived state creates sync bugs. If you forget to update `total` in one action, it becomes stale. Computing it during render is always correct.

## Zustand Patterns Overview

### Store Creation

```tsx
import { create } from "zustand";

type FilterState = {
  status: "all" | "active" | "archived";
  sortBy: "name" | "date";
  setStatus: (status: FilterState["status"]) => void;
  setSortBy: (sortBy: FilterState["sortBy"]) => void;
};

const useFilterStore = create<FilterState>()((set) => ({
  status: "all",
  sortBy: "name",
  setStatus: (status) => set({ status }),
  setSortBy: (sortBy) => set({ sortBy }),
}));
```

### Slice Pattern (for large stores)

```tsx
const createFilterSlice = (set) => ({
  status: "all" as const,
  sortBy: "name" as const,
  setStatus: (status: string) => set({ status }),
  setSortBy: (sortBy: string) => set({ sortBy }),
});

const createUISlice = (set) => ({
  sidebarOpen: false,
  theme: "light" as const,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
  setTheme: (theme: string) => set({ theme }),
});

const useAppStore = create<FilterSlice & UISlice>()((...a) => ({
  ...createFilterSlice(...a),
  ...createUISlice(...a),
}));
```

### Middleware

```tsx
import { create } from "zustand";
import { persist, devtools, immer } from "zustand/middleware";

// Middleware order: immer -> subscribeWithSelector -> devtools -> persist
const useCartStore = create<CartState>()(
  immer(
    devtools(
      persist(
        (set) => ({
          items: [],
          addItem: (item) =>
            set((state) => {
              state.items.push(item); // immer: mutate directly
            }),
        }),
        { name: "cart-storage" }
      )
    )
  )
);
```

### useShallow (fine-grained subscriptions)

```tsx
import { useShallow } from "zustand/shallow";

// Bad: subscribes to entire store, re-renders on any change
const { status, sortBy } = useFilterStore();

// Good: subscribes only to specific fields
const { status, sortBy } = useFilterStore(
  useShallow((s) => ({ status: s.status, sortBy: s.sortBy }))
);
```

### Next.js Hydration

Zustand with `persist` middleware can cause hydration mismatches in Next.js. Use the `onRehydrateStorage` pattern or dynamic import:

```tsx
// Option 1: Skip hydration mismatch
const useHydrated = create<boolean>(() => false);
useCartStore.onRehydrateStorage = () => () => useHydrated.setState(true);

// Option 2: Use client-only wrapper
function ClientOnly({ children }) {
  const hydrated = useHydrated();
  if (!hydrated) return <Skeleton />;
  return children;
}
```

## Related Skills

- **data-fetching**: TanStack Query for all server state
- **react-composition**: Context vs Zustand for component state
- **typescript-react**: Typing Zustand stores and React state

## References

- [zustand-patterns](references/zustand-patterns.md) - Store creation, slices, middleware, useShallow, hydration
- [state-decision-guide](references/state-decision-guide.md) - Full decision flowchart with examples
- [url-state-patterns](references/url-state-patterns.md) - nuqs, typed URL state, synchronization
