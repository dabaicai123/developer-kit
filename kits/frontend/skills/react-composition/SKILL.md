---
name: react-composition
description: Compound components, state lifting, render delegation, and composition-vs-configuration decision guide. Build flexible, maintainable React components through composition patterns.
version: "1.0.0"
type: skill
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# React Composition Patterns

Build flexible, maintainable components through composition instead of configuration.

## When to Use This Skill

- Building reusable UI components with flexible APIs
- Deciding between props vs composition for component flexibility
- Avoiding prop drilling or over-abstracting
- Creating compound components (Tabs, Select, Card, Dialog)
- Delegating rendering to consumers via render props

## Core Patterns

### 1. Compound Components

Parent provides context, children consume it. No prop drilling needed.

```tsx
// Tabs.tsx - Parent creates context
const TabsContext = createContext<TabsContextValue | null>(null);

function Tabs({ children, defaultValue }: TabsProps) {
  const [activeTab, setActiveTab] = useState(defaultValue);
  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab }}>
      <div className="flex flex-col">{children}</div>
    </TabsContext.Provider>
  );
}

// Tab.tsx - Child consumes context
function Tab({ value, children }: TabProps) {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error("Tab must be inside Tabs");
  return (
    <button
      className={ctx.activeTab === value ? "border-b-2 border-blue-500" : ""}
      onClick={() => ctx.setActiveTab(value)}
    >
      {children}
    </button>
  );
}
```

### 2. State Lifting

Lift state when siblings need it. Keep local when only one component needs it.

```tsx
// Lifting: SearchFilter and ResultsList both need the query
function SearchPage() {
  const [query, setQuery] = useState("");
  return (
    <>
      <SearchFilter query={query} onChange={setQuery} />
      <ResultsList query={query} />
    </>
  );
}

// Local: Only the accordion item needs open/close state
function AccordionItem({ title, children }) {
  const [isOpen, setIsOpen] = useState(false); // stays local
  return (
    <div>
      <button onClick={() => setIsOpen(!isOpen)}>{title}</button>
      {isOpen && children}
    </div>
  );
}
```

### 3. Render Delegation

Let consumers control rendering via `renderItem` / `renderHeader` props.

```tsx
function List<T>({ items, renderItem, keyExtractor }: ListProps<T>) {
  return (
    <ul className="divide-y divide-gray-200">
      {items.map((item) => (
        <li key={keyExtractor(item)}>{renderItem(item)}</li>
      ))}
    </ul>
  );
}

// Consumer controls the rendering
<List
  items={users}
  renderItem={(user) => <UserCard user={user} />}
  keyExtractor={(user) => user.id}
/>
```

### 4. Internal Composition

Expose sub-components instead of overloading props.

```tsx
// Bad: too many props, hard to extend
<Card title="X" subtitle="Y" avatar="Z" footer="W" actions={['a','b']} />

// Good: compositional API
<Card>
  <CardHeader>
    <Avatar src="Z" />
    <div>
      <CardTitle>X</CardTitle>
      <CardSubtitle>Y</CardSubtitle>
    </div>
  </CardHeader>
  <CardBody>Content here</CardBody>
  <CardFooter>
    <Button>Action A</Button>
    <Button>Action B</Button>
  </CardFooter>
</Card>
```

## Composition vs Configuration Decision Guide

| Scenario | Use Composition | Use Configuration |
|---|---|---|
| Variable child structure | Yes | No |
| 2-3 fixed optional sections | No | Yes |
| Consumer needs custom rendering | Yes | No |
| Simple toggle (show/hide) | No | Yes |
| More than 5 boolean props | Yes | No |
| API needs to evolve often | Yes | No |
| Performance-critical, known structure | No | Yes |

**Decision rule**: Start with configuration (simple props). Switch to composition when the prop count grows or consumers need flexibility.

## Anti-patterns

### Prop Drilling Beyond 2 Levels

```tsx
// Bad: drilling through 3+ levels
<App theme={theme} onThemeChange={setTheme}>
  <Layout theme={theme} onThemeChange={setTheme}>
    <Sidebar theme={theme} onThemeChange={setTheme}>
      <ThemeToggle theme={theme} onChange={setTheme} />
    </Sidebar>
  </Layout>
</App>

// Good: context or Zustand for cross-cutting concerns
const useTheme = create<ThemeState>((set) => ({
  theme: "light",
  setTheme: (t) => set({ theme: t }),
}));
```

### Over-Abstracting

```tsx
// Bad: generic everything
function SuperComponent<T>({ data, renderer, validator, transformer }) {}

// Good: specific, composable components
function UserList({ users }: { users: User[] }) {}
function ProductGrid({ products }: { products: Product[] }) {}
```

### Putting Everything in One Component

```tsx
// Bad: monolith
function Dashboard({ showSidebar, showHeader, showFooter, sidebarItems, headerTitle, ... }) {}

// Good: compose
<Dashboard>
  <DashboardHeader />
  <DashboardSidebar />
  <DashboardContent />
</Dashboard>
```

## Related Skills

- **react-best-practices**: General React patterns and conventions
- **tailwind-v4**: Styling composition patterns
- **design-to-code**: Translating designs to compositional components
- **forms-and-validation**: Form composition patterns

## References

- [compound-components](references/compound-components.md) - Tabs, Select, Card, Dialog with TypeScript
- [state-lifting](references/state-lifting.md) - When to lift vs keep local, controlled vs uncontrolled
- [component-api-design](references/component-api-design.md) - Composition vs configuration framework