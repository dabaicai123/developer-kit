# State Decision Guide

Full decision flowchart with examples for every state type.

## Decision Flowchart

```
START: You have a piece of state to manage
  |
  v
[Q1] Is this data fetched from or synced with a server/API?
  |
  YES → TanStack Query (useQuery / useMutation)
  |     Examples: user profile, products list, search results, order details
  |     NEVER use useState/useReducer/Zustand for server data
  |
  NO → continue
  |
  v
[Q2] Should this state survive page navigation? Should it be shareable via URL?
  |
  YES → URL state (nuqs / searchParams)
  |     Examples: active tab, search query, sort order, filter values, pagination page
  |
  NO → continue
  |
  v
[Q3] Is this state needed by many components across unrelated parts of the app?
  |
  YES → Zustand
  |     Examples: theme preference, sidebar collapsed, feature flags, draft form data,
  |              notification preferences, global loading overlay
  |
  NO → continue
  |
  v
[Q4] Is this state needed by many components within a component subtree?
  |
  YES → React Context
  |     Examples: form state shared across form fields, active tab within Tabs,
  |              dialog open state within Dialog compound component,
  |              current user identity for permission checks within a section
  |
  NO → continue
  |
  v
[Q5] Does this state have many interdependent transitions or many actions?
  |
  YES → useReducer
  |     Examples: multi-step form wizard, complex editor with undo/redo,
  |              game state with many moves, checkout flow with validation at each step
  |
  NO → continue
  |
  v
[Q6] Is this state local to a single component?
  |
  YES → useState
  |     Examples: modal open/close, dropdown expanded, hover state,
  |              input value before submit, local toggle, tooltip visibility
  |
  NO → Re-evaluate. You may have missed a sharing requirement.
```

## Examples Per State Type

### useState - Local UI State

```tsx
function ProductCard({ product }: { product: Product }) {
  const [isExpanded, setIsExpanded] = useState(false);
  const [hoveredVariant, setHoveredVariant] = useState<string | null>(null);

  return (
    <div
      onMouseEnter={() => setHoveredVariant("hover")}
      onMouseLeave={() => setHoveredVariant(null)}
    >
      <h3>{product.name}</h3>
      {isExpanded && <ProductDetails product={product} />}
      <button onClick={() => setIsExpanded(!isExpanded)}>
        {isExpanded ? "Show Less" : "Show More"}
      </button>
    </div>
  );
}
```

**Characteristics**: No other component needs `isExpanded` or `hoveredVariant`. They reset when the component unmounts.

### useReducer - Complex Local State

```tsx
type CheckoutStep = "cart" | "shipping" | "payment" | "confirmation";

type CheckoutState = {
  step: CheckoutStep;
  cart: CartItem[];
  shippingAddress: Address | null;
  paymentMethod: PaymentMethod | null;
  errors: Record<string, string>;
};

type CheckoutAction =
  | { type: "NEXT_STEP" }
  | { type: "PREV_STEP" }
  | { type: "SET_SHIPPING"; address: Address }
  | { type: "SET_PAYMENT"; method: PaymentMethod }
  | { type: "SET_ERROR"; field: string; message: string }
  | { type: "CLEAR_ERRORS" }
  | { type: "RESET" };

function checkoutReducer(state: CheckoutState, action: CheckoutAction): CheckoutState {
  switch (action.type) {
    case "NEXT_STEP":
      return { ...state, step: nextStep(state.step), errors: {} };
    case "PREV_STEP":
      return { ...state, step: prevStep(state.step) };
    case "SET_SHIPPING":
      return { ...state, shippingAddress: action.address };
    case "SET_PAYMENT":
      return { ...state, paymentMethod: action.method };
    case "SET_ERROR":
      return { ...state, errors: { ...state.errors, [action.field]: action.message } };
    case "CLEAR_ERRORS":
      return { ...state, errors: {} };
    case "RESET":
      return initialCheckoutState;
    default:
      return state;
  }
}

function CheckoutWizard() {
  const [state, dispatch] = useReducer(checkoutReducer, initialCheckoutState);

  return (
    <div>
      <StepIndicator step={state.step} />
      {state.step === "cart" && <CartStep items={state.cart} dispatch={dispatch} />}
      {state.step === "shipping" && <ShippingStep dispatch={dispatch} />}
      {state.step === "payment" && <PaymentStep dispatch={dispatch} />}
      {state.step === "confirmation" && <ConfirmationStep state={state} />}
      {Object.keys(state.errors).length > 0 && <ErrorSummary errors={state.errors} />}
    </div>
  );
}
```

**Characteristics**: Steps depend on each other (can't go to payment without shipping). Many actions that affect different fields simultaneously. `useReducer` centralizes all transitions.

### React Context - Subtree-Shared State

```tsx
type FormContextValue = {
  values: Record<string, unknown>;
  errors: Record<string, string>;
  setValue: (field: string, value: unknown) => void;
  isSubmitting: boolean;
};

const FormContext = createContext<FormContextValue | null>(null);

function FormProvider({ children, onSubmit }: { children: ReactNode; onSubmit: (values: Record<string, unknown>) => void }) {
  const [values, setValues] = useState<Record<string, unknown>>({});
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [isSubmitting, setIsSubmitting] = useState(false);

  const setValue = (field: string, value: unknown) => {
    setValues((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => {
      const next = { ...prev };
      delete next[field];
      return next;
    });
  };

  return (
    <FormContext.Provider value={{ values, errors, setValue, isSubmitting }}>
      {children}
    </FormContext.Provider>
  );
}

// Any field inside the form can access context
function FormField({ name, label, type }: FormFieldProps) {
  const ctx = useContext(FormContext);
  return (
    <div>
      <label>{label}</label>
      <input
        type={type}
        value={ctx?.values[name] ?? ""}
        onChange={(e) => ctx?.setValue(name, e.target.value)}
      />
      {ctx?.errors[name] && <span className="text-red-500 text-sm">{ctx.errors[name]}</span>}
    </div>
  );
}
```

**Characteristics**: State is shared within the `FormProvider` subtree only. Not global across the app.

### Zustand - Global Client State

```tsx
type UIState = {
  sidebarCollapsed: boolean;
  theme: "light" | "dark" | "system";
  fontSize: "sm" | "md" | "lg";
  recentSearches: string[];
  toggleSidebar: () => void;
  setTheme: (theme: UIState["theme"]) => void;
  setFontSize: (size: UIState["fontSize"]) => void;
  addRecentSearch: (query: string) => void;
};

const useUIStore = create<UIState>()(
  persist(
    (set) => ({
      sidebarCollapsed: false,
      theme: "system",
      fontSize: "md",
      recentSearches: [],
      toggleSidebar: () => set((s) => ({ sidebarCollapsed: !s.sidebarCollapsed })),
      setTheme: (theme) => set({ theme }),
      setFontSize: (size) => set({ fontSize: size }),
      addRecentSearch: (query) =>
        set((s) => ({
          recentSearches: [query, ...s.recentSearches.filter((q) => q !== query)].slice(0, 5),
        })),
    }),
    { name: "ui-preferences", partialize: (s) => ({ theme: s.theme, fontSize: s.fontSize }) }
  )
);

// Sidebar component in a completely different part of the tree
function Sidebar() {
  const collapsed = useUIStore((s) => s.sidebarCollapsed);
  const toggle = useUIStore((s) => s.toggleSidebar);
  return <aside className={collapsed ? "w-0" : "w-64"}>{/* ... */}</aside>;
}

// Settings page also accesses the same store
function ThemeSettings() {
  const theme = useUIStore((s) => s.theme);
  const setTheme = useUIStore((s) => s.setTheme);
  return <select value={theme} onChange={(e) => setTheme(e.target.value)}>{/* ... */}</select>;
}
```

**Characteristics**: Unrelated components in different parts of the tree need the same state. No server data involved. Persists across page loads.

### TanStack Query - Server State

```tsx
function useProducts(filters: ProductFilters) {
  return useQuery({
    queryKey: ["products", filters],
    queryFn: async () => {
      const res = await fetch(`/api/products?${toSearchParams(filters)}`);
      if (!res.ok) throw new Error(`Failed to fetch products: ${res.status}`);
      const data = await res.json();
      return ProductSchema.array().parse(data); // Zod validation
    },
    staleTime: 5 * 60 * 1000, // 5 minutes
  });
}

function ProductList() {
  const { data: products, isLoading, error } = useProducts(currentFilters);
  if (isLoading) return <ProductSkeleton />;
  if (error) return <ErrorBanner message={error.message} />;
  return <ul>{products.map((p) => <ProductCard key={p.id} product={p} />)}</ul>;
}
```

**Characteristics**: Data comes from an API. Needs caching, refetching, background updates. Never put this in useState or Zustand.

### URL State - Shareable, Persistent

```tsx
import { useQueryState, parseAsString, parseAsInteger } from "nuqs";

function ProductSearch() {
  const [search, setSearch] = useQueryState("q", parseAsString.withDefault(""));
  const [page, setPage] = useQueryState("page", parseAsInteger.withDefault(1));
  const [sort, setSort] = useQueryState("sort", parseAsString.withDefault("relevance"));

  return (
    <div>
      <SearchInput value={search} onChange={setSearch} />
      <SortSelector value={sort} onChange={setSort} />
      <PaginatedResults page={page} onPageChange={setPage} />
    </div>
  );
}
```

**Characteristics**: Survives navigation. Can be shared via URL. Persists across page reloads.

## Overlapping Scenarios

Some state could live in multiple places. Pick the simplest:

| State | Could be | Should be | Reason |
|---|---|---|---|
| Active tab | useState, Context, URL | URL | Shareable, survives refresh |
| Search query | useState, URL | URL | Shareable, drives server fetch |
| Modal open | useState, Zustand | useState | Local, ephemeral |
| Theme | Context, Zustand | Zustand | Global, persists, many consumers |
| Form draft | useState, Zustand | Zustand | Survives unmount, many fields |
| User data | Zustand, TanStack Query | TanStack Query | Server data |