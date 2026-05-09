# State Lifting

When to lift state up, when to keep it local, and controlled vs uncontrolled patterns.

## When to Lift vs Keep Local

### Keep State Local When

- Only one component needs it (e.g., a modal's open/close state)
- The state is ephemeral UI state (hover, focus, local form dirty)
- No sibling or parent needs to read or write it
- Removing the state would not affect any other component's behavior

```tsx
// Local: only this accordion item needs open/close
function AccordionItem({ title, children }: AccordionItemProps) {
  const [isOpen, setIsOpen] = useState(false);
  return (
    <div>
      <button onClick={() => setIsOpen(!isOpen)}>
        {isOpen ? "▼" : "▶"} {title}
      </button>
      {isOpen && <div className="p-4">{children}</div>}
    </div>
  );
}
```

### Lift State When

- Two sibling components both need the same state
- A parent needs to read the state
- A parent needs to control the state
- The state drives navigation or URL changes
- The state needs to survive component unmount (e.g., draft form data)

```tsx
// Lifted: both SearchBar and ResultsList need the query
function SearchPage() {
  const [query, setQuery] = useState("");
  return (
    <div className="flex flex-col gap-4">
      <SearchBar query={query} onQueryChange={setQuery} />
      <ResultsList query={query} />
      <SearchStats query={query} resultCount={results.length} />
    </div>
  );
}

// Lifted: parent needs to know which tab is active for analytics
function Dashboard({ onTabChange }: DashboardProps) {
  const [activeTab, setActiveTab] = useState("overview");
  const handleTabChange = (tab: string) => {
    setActiveTab(tab);
    onTabChange(tab); // parent callback
  };
  return (
    <>
      <DashboardNav activeTab={activeTab} onTabChange={handleTabChange} />
      <DashboardContent activeTab={activeTab} />
    </>
  );
}
```

### Decision Checklist

1. Does any sibling need this state? **Yes** = lift
2. Does any parent need this state? **Yes** = lift
3. Will the state survive unmount if kept local? **No** and needed = lift
4. Is it purely ephemeral UI state (hover, focus)? **Yes** = keep local
5. Does only one component use it? **Yes** = keep local

## Controlled vs Uncontrolled

### Uncontrolled (component manages its own state)

```tsx
type InputProps = {
  defaultValue?: string;
  className?: string;
};

function Input({ defaultValue, className }: InputProps) {
  // Component owns the state internally
  return <input defaultValue={defaultValue} className={className} />;
}

// Usage: just provide initial value, component handles the rest
<Input defaultValue="hello" />
```

**When to use uncontrolled:**
- Simple form inputs that don't need real-time parent access
- File inputs (cannot be controlled in React)
- Performance-sensitive scenarios where every keystroke event is costly
- When you only need the value on submit

### Controlled (parent manages state, passes it down)

```tsx
type ControlledInputProps = {
  value: string;
  onChange: (value: string) => void;
  className?: string;
};

function ControlledInput({ value, onChange, className }: ControlledInputProps) {
  // Parent owns the state, component is a pure renderer
  return (
    <input
      value={value}
      onChange={(e) => onChange(e.target.value)}
      className={className}
    />
  );
}

// Usage: parent controls the value
const [name, setName] = useState("");
<ControlledInput value={name} onChange={setName} />
```

**When to use controlled:**
- Parent needs to validate, transform, or react to every change
- Two inputs need to stay synchronized (e.g., password confirmation)
- State is derived from other state (e.g., formatted display value)
- You need to reset or programmatically set the value

### Hybrid: Both modes supported

```tsx
type FlexibleInputProps = {
  value?: string;           // controlled mode
  defaultValue?: string;    // uncontrolled mode
  onChange?: (value: string) => void;
  className?: string;
};

function FlexibleInput({ value, defaultValue, onChange, className }: FlexibleInputProps) {
  const [internalValue, setInternalValue] = useState(defaultValue ?? "");
  const currentValue = value ?? internalValue;
  const handleChange = (newValue: string) => {
    if (value === undefined) setInternalValue(newValue);
    onChange?.(newValue);
  };

  return (
    <input
      value={currentValue}
      onChange={(e) => handleChange(e.target.value)}
      className={className}
    />
  );
}
```

**Pattern**: `value ?? internalValue` and `onChange ?? setInternalValue`. This is the standard approach for reusable components that work in both modes.

## State Sharing Across Siblings

### Pattern 1: Lifting to parent (simplest)

```tsx
function FilterPanel() {
  const [status, setStatus] = useState<Status>("all");
  const [sort, setSort] = useState<Sort>("newest");

  return (
    <div>
      <StatusFilter status={status} onChange={setStatus} />
      <SortSelector sort={sort} onChange={setSort} />
      <FilteredResults status={status} sort={sort} />
    </div>
  );
}
```

**Pros**: Simple, explicit, easy to trace. **Cons**: Parent can get bloated with many lifted states.

### Pattern 2: Context (for deeply nested or many consumers)

```tsx
const FilterContext = createContext<FilterState | null>(null);

function FilterProvider({ children }: { children: ReactNode }) {
  const [status, setStatus] = useState<Status>("all");
  const [sort, setSort] = useState<Sort>("newest");

  return (
    <FilterContext.Provider value={{ status, setStatus, sort, setSort }}>
      {children}
    </FilterContext.Provider>
  );
}

function useFilter() {
  const ctx = useContext(FilterContext);
  if (!ctx) throw new Error("useFilter must be inside FilterProvider");
  return ctx;
}

// Any child can consume without prop drilling
function ResultsTable() {
  const { status, sort } = useFilter();
  // ...
}
```

**Pros**: No prop drilling, works at any depth. **Cons**: Context re-renders all consumers on any change.

### Pattern 3: Zustand (for global/cross-cutting state)

```tsx
const useFilterStore = create<FilterState>((set) => ({
  status: "all",
  sort: "newest",
  setStatus: (s) => set({ status: s }),
  setSort: (s) => set({ sort: s }),
}));

// Components subscribe independently to specific slices
function ResultsTable() {
  const status = useFilterStore((s) => s.status); // only re-renders on status change
  const sort = useFilterStore((s) => s.sort);
}
```

**Pros**: Fine-grained subscriptions, no provider needed. **Cons**: Overkill for local component state.

### Which pattern to use?

| Scenario | Pattern |
|---|---|
| 2-3 sibling components sharing state, same parent | Lift to parent |
| Many consumers at various depths | Context |
| Cross-cutting concern (theme, auth, global filter) | Zustand |
| State that should sync with URL | URL state (nuqs) |
| Server data | TanStack Query (never Zustand) |

## Common Mistakes

### Lifting too early

```tsx
// Bad: lifting hover state that only one component needs
function Page() {
  const [isHovered, setIsHovered] = useState(false); // unnecessary lift
  return <Card isHovered={isHovered} onHoverChange={setIsHovered} />;
}

// Good: keep hover local
function Card() {
  const [isHovered, setIsHovered] = useState(false); // stays here
}
```

### Not lifting when needed

```tsx
// Bad: two separate states for the same concept
function Page() {
  return (
    <>
      <SearchBar onSearch={(q) => /* somehow communicate to ResultsList */} />
      <ResultsList /* no access to query */ />
    </>
  );
}

// Good: single lifted state
function Page() {
  const [query, setQuery] = useState("");
  return (
    <>
      <SearchBar query={query} onChange={setQuery} />
      <ResultsList query={query} />
    </>
  );
}
```

### Derived state stored separately

```tsx
// Bad: storing derived state
const [items, setItems] = useState<Item[]>([]);
const [filteredItems, setFilteredItems] = useState<Item[]>([]); // redundant!

// Good: derive it
const [items, setItems] = useState<Item[]>([]);
const filteredItems = items.filter((i) => i.active); // computed during render
```