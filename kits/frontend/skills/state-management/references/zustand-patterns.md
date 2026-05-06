# Zustand Patterns

Store creation, slice pattern, middleware, useShallow, Next.js hydration, computed values, async actions, and store reset.

## Store Creation

### Basic store

```tsx
import { create } from "zustand";

type CounterState = {
  count: number;
  increment: () => void;
  decrement: () => void;
  reset: () => void;
};

const useCounterStore = create<CounterState>()((set) => ({
  count: 0,
  increment: () => set((state) => ({ count: state.count + 1 })),
  decrement: () => set((state) => ({ count: state.count - 1 })),
  reset: () => set({ count: 0 }),
}));
```

**Important**: Always type the store explicitly with `create<State>()()`. The double parentheses ensure TypeScript infers the setter type correctly.

### Usage patterns

```tsx
// Subscribe to a single value (most efficient)
const count = useCounterStore((s) => s.count);

// Subscribe to multiple values with useShallow
const { count, increment } = useCounterStore(
  useShallow((s) => ({ count: s.count, increment: s.increment }))
);

// Subscribe to entire store (use sparingly)
const store = useCounterStore();

// Access state outside React (no re-render subscription)
const currentCount = useCounterStore.getState().count;
useCounterStore.setState({ count: 5 });
```

## Slice Pattern

For stores that grow beyond 5-8 fields, split into slices to keep maintainable.

```tsx
type FilterSlice = {
  status: "all" | "active" | "archived";
  sortBy: "name" | "date";
  search: string;
  setStatus: (status: FilterSlice["status"]) => void;
  setSortBy: (sortBy: FilterSlice["sortBy"]) => void;
  setSearch: (search: string) => void;
};

type UISlice = {
  sidebarOpen: boolean;
  theme: "light" | "dark";
  toggleSidebar: () => void;
  setTheme: (theme: UISlice["theme"]) => void;
};

type AppState = FilterSlice & UISlice;

const createFilterSlice: StateCreator<AppState, [], [], FilterSlice> = (set) => ({
  status: "all",
  sortBy: "name",
  search: "",
  setStatus: (status) => set({ status }),
  setSortBy: (sortBy) => set({ sortBy }),
  setSearch: (search) => set({ search }),
});

const createUISlice: StateCreator<AppState, [], [], UISlice> = (set) => ({
  sidebarOpen: false,
  theme: "light",
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),
  setTheme: (theme) => set({ theme }),
});

const useAppStore = create<AppState>()((...a) => ({
  ...createFilterSlice(...a),
  ...createUISlice(...a),
}));
```

**Naming convention**: Slice files named `*-slice.ts`, co-located with the store file.

## Middleware

### immer

Allows mutating state directly instead of returning new objects.

```tsx
import { immer } from "zustand/middleware/immer";

const useCartStore = create<CartState>()(
  immer((set) => ({
    items: [],
    addItem: (item) =>
      set((state) => {
        state.items.push(item); // direct mutation with immer
      }),
    removeItem: (id) =>
      set((state) => {
        const index = state.items.findIndex((i) => i.id === id);
        if (index !== -1) state.items.splice(index, 1);
      }),
    updateQuantity: (id, qty) =>
      set((state) => {
        const item = state.items.find((i) => i.id === id);
        if (item) item.quantity = qty;
      }),
  }))
);
```

### persist

Persists store to storage (localStorage by default).

```tsx
import { persist } from "zustand/middleware";

const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      items: [],
      addItem: (item) => set((s) => ({ items: [...s.items, item] })),
    }),
    {
      name: "cart-storage",                // localStorage key
      partialize: (state) => ({ items: state.items }), // only persist items, not actions
      version: 1,                           // migration support
      migrate: (persisted, version) => {
        if (version === 0) {
          // migrate from v0 to v1 schema
          return { ...persisted, items: persisted.products ?? [] };
        }
        return persisted;
      },
    }
  )
);
```

### devtools

Enables Redux DevTools integration for debugging.

```tsx
import { devtools } from "zustand/middleware";

const useCounterStore = create<CounterState>()(
  devtools(
    (set) => ({
      count: 0,
      increment: () => set((s) => ({ count: s.count + 1 }), false, "increment"),
      decrement: () => set((s) => ({ count: s.count - 1 }), false, "decrement"),
    }),
    { name: "CounterStore", enabled: process.env.NODE_ENV === "development" }
  )
);
```

**Note**: The second argument to `set()` is `replace` (boolean), the third is the action name for devtools.

### Middleware Order

Order matters. Apply from innermost to outermost: **immer -> subscribeWithSelector -> devtools -> persist**.

```tsx
import { create } from "zustand";
import { immer } from "zustand/middleware/immer";
import { subscribeWithSelector } from "zustand/middleware/subscribeWithSelector";
import { devtools } from "zustand/middleware";
import { persist } from "zustand/middleware";

const useAppStore = create<AppState>()(
  immer(
    subscribeWithSelector(
      devtools(
        persist(
          (set) => ({
            // ... state and actions
          }),
          { name: "app-storage" }
        ),
        { name: "AppStore" }
      )
    )
  )
);
```

**Why this order**:
- `immer` innermost: wraps `set` so you can mutate directly, then other middleware see the immutable result
- `subscribeWithSelector`: needed before devtools if you want selective subscription with devtools
- `devtools`: action naming and debugging
- `persist` outermost: handles serialization and rehydration last

## useShallow

Prevents unnecessary re-renders when subscribing to multiple primitive values.

```tsx
import { useShallow } from "zustand/shallow";

// Without useShallow: object reference changes every render even if values are the same
const { status, sortBy } = useFilterStore((s) => ({
  status: s.status,
  sortBy: s.sortBy,
}));

// With useShallow: only re-renders when actual values change
const { status, sortBy } = useFilterStore(
  useShallow((s) => ({ status: s.status, sortBy: s.sortBy }))
);

// For arrays/objects in state
const selectedItems = useCartStore(useShallow((s) => s.items.filter((i) => i.selected)));
```

**When to use**: Always when subscribing to more than one primitive field. Always when deriving a computed array or object from store state.

## Next.js Hydration

Zustand `persist` middleware reads from localStorage on mount, which can cause SSR/client mismatch.

### Solution 1: Skip hydration until client

```tsx
"use client";
import { useEffect, useState } from "react";
import { useCartStore } from "./cart-store";

function HydrationGuard({ children }: { children: ReactNode }) {
  const [hydrated, setHydrated] = useState(false);
  useEffect(() => {
    setHydrated(true);
  }, []);
  if (!hydrated) return <CartSkeleton />;
  return children;
}
```

### Solution 2: onRehydrateStorage callback

```tsx
const useCartStore = create<CartState>()(
  persist(
    (set) => ({
      items: [],
      _hasHydrated: false,
      addItem: (item) => set((s) => ({ items: [...s.items, item] })),
      setHasHydrated: (state) => set({ _hasHydrated: state }),
    }),
    {
      name: "cart-storage",
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true);
      },
    }
  )
);

function CartContent() {
  const hasHydrated = useCartStore((s) => s._hasHydrated);
  if (!hasHydrated) return <CartSkeleton />;
  return <CartDisplay />;
}
```

### Solution 3: Dynamic import

```tsx
const CartContent = dynamic(() => import("./CartContent"), { ssr: false });
```

## Computed Values

Never store computed values in Zustand. Compute them at the component level.

```tsx
// Store: only raw data
const useCartStore = create<CartState>()((set) => ({
  items: [],
  addItem: (item) => set((s) => ({ items: [...s.items, item] })),
}));

// Component: compute derived values
function CartTotal() {
  const items = useCartStore((s) => s.items);
  const total = useMemo(() => items.reduce((sum, i) => sum + i.price * i.qty, 0), [items]);
  return <span>${total.toFixed(2)}</span>;
}
```

If you need computed values frequently, create a custom hook:

```tsx
function useCartComputed() {
  const items = useCartStore(useShallow((s) => s.items));
  const total = useMemo(() => items.reduce((sum, i) => sum + i.price * i.qty, 0), [items]);
  const count = useMemo(() => items.reduce((sum, i) => sum + i.qty, 0), [items]);
  return { items, total, count };
}
```

## Async Actions

```tsx
const useProductStore = create<ProductState>()((set) => ({
  // DO NOT store loading/error here - that's server data
  // Use TanStack Query instead
  localDrafts: {},
  saveDraft: async (productId: string, draft: DraftData) => {
    // Async action for client-side operations only
    set((state) => ({
      localDrafts: { ...state.localDrafts, [productId]: draft },
    }));
    // Server mutation should be done via TanStack Query mutation
  },
}));
```

**Rule**: Async actions in Zustand are only for client-side side effects (e.g., saving to localStorage, dispatching to another store). Server data fetching and mutations belong in TanStack Query.

## Store Reset

```tsx
const useAppStore = create<AppState>()((set, get) => ({
  // ... initial state
  reset: () => {
    set({
      // Explicitly reset each field to initial value
      status: "all",
      sortBy: "name",
      search: "",
      sidebarOpen: false,
      theme: "light",
    });
  },
}));

// Alternative: store initial state separately
const initialState: AppState = {
  status: "all",
  sortBy: "name",
  search: "",
  sidebarOpen: false,
  theme: "light",
};

const useAppStore = create<AppState>()((set) => ({
  ...initialState,
  reset: () => set(initialState),
  // ... actions
}));
```

For `persist` middleware, clear storage on reset:

```tsx
reset: () => {
  set(initialState);
  localStorage.removeItem("app-storage");
},
```