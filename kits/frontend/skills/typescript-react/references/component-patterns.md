# Component Patterns

Discriminated props, compound components, render props, display names, and generic components.

## Discriminated Props

Use discriminated unions to create variant-based props where each variant has different required fields. This prevents impossible prop combinations.

### Variant-based props with unions

```tsx
// Each variant carries different required data
type AlertProps =
  | { variant: 'info'; message: string }
  | { variant: 'success'; message: string; actionLabel?: string; onAction?: () => void }
  | { variant: 'error'; error: Error; retryLabel?: string; onRetry?: () => void }
  | { variant: 'warning'; message: string; dismissible: true; onDismiss: () => void };

function Alert(props: AlertProps) {
  const base = 'rounded-md p-4 text-sm';

  switch (props.variant) {
    case 'info':
      return (
        <div className={`${base} bg-blue-50 text-blue-800`}>
          {props.message}
        </div>
      );
    case 'success':
      return (
        <div className={`${base} bg-green-50 text-green-800`}>
          {props.message}
          {props.onAction && (
            <button onClick={props.onAction} className="ml-2 underline">
              {props.actionLabel ?? 'View'}
            </button>
          )}
        </div>
      );
    case 'error':
      return (
        <div className={`${base} bg-red-50 text-red-800`}>
          <p>{props.error.message}</p>
          {props.onRetry && (
            <button onClick={props.onRetry} className="ml-2 underline">
              {props.retryLabel ?? 'Retry'}
            </button>
          )}
        </div>
      );
    case 'warning':
      return (
        <div className={`${base} bg-yellow-50 text-yellow-800`}>
          {props.message}
          <button onClick={props.onDismiss} className="ml-2 underline">
            Dismiss
          </button>
        </div>
      );
  }
}

// Usage — TypeScript enforces the right props for each variant
<Alert variant="info" message="New update available" />
<Alert variant="success" message="Order confirmed" actionLabel="Track" onAction={() => navigate('/tracking')} />
<Alert variant="error" error={new Error('Network failed')} onRetry={() => refetch()} />
<Alert variant="warning" message="Low stock" dismissible={true} onDismiss={() => setVisible(false)} />

// Invalid combinations caught at compile time:
<Alert variant="warning" message="Low stock" /> // Error: dismissible and onDismiss required for warning
<Alert variant="error" error={new Error('fail')} retryLabel="Try again" /> // OK: retryLabel optional for error
```

### Size + variant matrix

```tsx
// Map variant to its allowed sizes
type ButtonSize = 'sm' | 'md' | 'lg';

type ButtonProps =
  | { variant: 'primary'; size?: ButtonSize; children: React.ReactNode }
  | { variant: 'secondary'; size?: ButtonSize; children: React.ReactNode }
  | { variant: 'icon'; icon: React.ReactNode; label: string; size?: 'sm' | 'md' };

function Button(props: ButtonProps) {
  if (props.variant === 'icon') {
    return (
      <button aria-label={props.label} className="p-2 rounded-md">
        {props.icon}
      </button>
    );
  }

  const sizes = { sm: 'h-8 px-3 text-xs', md: 'h-10 px-4 text-sm', lg: 'h-12 px-6 text-base' };
  const variants = {
    primary: 'bg-blue-500 text-white',
    secondary: 'bg-gray-100 text-gray-800',
  };

  return (
    <button className={`rounded-md ${sizes[props.size ?? 'md']} ${variants[props.variant]}`}>
      {props.children}
    </button>
  );
}
```

## Compound Component Typing

Compound components use a shared context and expose sub-components. TypeScript ensures the sub-components receive the right types from context.

```tsx
// Tabs compound component
interface TabsContextValue {
  activeTab: string;
  setActiveTab: (id: string) => void;
  registerTab: (id: string, label: string) => void;
}

const TabsContext = createContext<TabsContextValue | null>(null);

function useTabs(): TabsContextValue {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error('Tabs sub-components must be used within <Tabs>');
  return ctx;
}

// Root component
interface TabsProps {
  defaultTab?: string;
  children: React.ReactNode;
  onChange?: (tabId: string) => void;
}

function Tabs({ defaultTab, children, onChange }: TabsProps) {
  const [activeTab, setActiveTab] = useState(defaultTab ?? '');
  const [tabs, setTabs] = useState<Map<string, string>>(new Map());

  const registerTab = useCallback((id: string, label: string) => {
    setTabs(prev => {
      const next = new Map(prev);
      next.set(id, label);
      return next;
    });
  }, []);

  const handleSetTab = useCallback((id: string) => {
    setActiveTab(id);
    onChange?.(id);
  }, [onChange]);

  // Auto-select first tab if no defaultTab
  useEffect(() => {
    if (!activeTab && tabs.size > 0) {
      handleSetTab(tabs.keys().next().value!);
    }
  }, [activeTab, tabs, handleSetTab]);

  return (
    <TabsContext.Provider value={{ activeTab, setActiveTab: handleSetTab, registerTab }}>
      <div className="w-full">{children}</div>
    </TabsContext.Provider>
  );
}

// Tab List
interface TabListProps {
  children: React.ReactNode;
  className?: string;
}

function TabList({ children, className }: TabListProps) {
  return <div className={`flex border-b border-gray-200 ${className ?? ''}`}>{children}</div>;
}

// Tab Trigger
interface TabTriggerProps {
  id: string;
  label: string;
  className?: string;
}

function TabTrigger({ id, label, className }: TabTriggerProps) {
  const { activeTab, setActiveTab, registerTab } = useTabs();

  useEffect(() => { registerTab(id, label); }, [id, label, registerTab]);

  const isActive = activeTab === id;
  return (
    <button
      onClick={() => setActiveTab(id)}
      className={`px-4 py-2 text-sm font-medium transition-colors ${
        isActive
          ? 'text-blue-600 border-b-2 border-blue-600'
          : 'text-gray-500 hover:text-gray-700'
      } ${className ?? ''}`}
    >
      {label}
    </button>
  );
}

// Tab Content
interface TabContentProps {
  id: string;
  children: React.ReactNode;
  className?: string;
}

function TabContent({ id, children, className }: TabContentProps) {
  const { activeTab } = useTabs();
  if (activeTab !== id) return null;
  return <div className={`py-4 ${className ?? ''}`}>{children}</div>;
}

// Usage
<Tabs defaultTab="overview">
  <TabList>
    <TabTrigger id="overview" label="Overview" />
    <TabTrigger id="details" label="Details" />
    <TabTrigger id="reviews" label="Reviews" />
  </TabList>
  <TabContent id="overview"><OverviewPanel /></TabContent>
  <TabContent id="details"><DetailsPanel /></TabContent>
  <TabContent id="reviews"><ReviewsPanel /></TabContent>
</Tabs>
```

## Render Props and Delegation Typing

### Render props

```tsx
// DataProvider renders children with fetched data
interface DataProviderProps<T> {
  query: () => Promise<T>;
  children: (data: T, isLoading: boolean, error: Error | null) => React.ReactNode;
}

function DataProvider<T>({ query, children }: DataProviderProps<T>) {
  const [state, setState] = useState<{ data: T | null; isLoading: boolean; error: Error | null }>({
    data: null,
    isLoading: true,
    error: null,
  });

  useEffect(() => {
    query()
      .then(data => setState({ data, isLoading: false, error: null }))
      .catch(err => setState({ data: null, isLoading: false, error: err instanceof Error ? err : new Error(String(err)) }));
  }, [query]);

  if (state.data) {
    return children(state.data, state.isLoading, state.error);
  }
  return children(null as T, state.isLoading, state.error);
}

// Usage
<DataProvider query={() => fetchUser('123')}>
  {(user, isLoading, error) => {
    if (isLoading) return <Spinner />;
    if (error) return <ErrorMessage error={error} />;
    return <UserCard user={user!} />;
  }}
</DataProvider>
```

### Props delegation with ...rest

```tsx
// Delegate unknown props to underlying element
interface CardProps extends Omit<ComponentPropsWithoutRef<'div'>, 'title'> {
  variant?: 'default' | 'highlighted';
  title?: React.ReactNode; // override string title with ReactNode
}

function Card({ variant = 'default', title, children, className, ...rest }: CardProps) {
  const variants = {
    default: 'bg-white border border-gray-200',
    highlighted: 'bg-blue-50 border border-blue-200',
  };

  return (
    <div className={`rounded-lg p-4 ${variants[variant]} ${className ?? ''}`} {...rest}>
      {title && <h3 className="text-lg font-semibold mb-2">{title}</h3>}
      {children}
    </div>
  );
}

// Usage — all div props available
<Card variant="highlighted" title="Stats" id="stats-card" role="region" aria-label="Statistics">
  <StatsContent />
</Card>
```

## Display Name Patterns

`displayName` is required for React DevTools to show meaningful component names. Set it on every component that uses `forwardRef`, `memo`, or is exported from a library.

```tsx
// forwardRef — displayName is REQUIRED
const Input = forwardRef<HTMLInputElement, InputProps>((props, ref) => {
  return <input ref={ref} {...props} />;
});
Input.displayName = 'Input';

// memo — displayName for DevTools
const ExpensiveList = memo(function ExpensiveList({ items }: ListProps) {
  return <ul>{items.map(i => <li key={i.id}>{i.name}</li>)}</ul>;
});
ExpensiveList.displayName = 'ExpensiveList';

// Regular function components — displayName set automatically from function name
function UserCard({ name }: UserCardProps) {
  return <div>{name}</div>;
}
// DevTools shows "UserCard" — no need to set displayName

// Arrow function components — need explicit displayName
const UserAvatar = ({ src, alt }: UserAvatarProps) => <img src={src} alt={alt} />;
UserAvatar.displayName = 'UserAvatar';
// Without this, DevTools shows "Anonymous" or "_default"
```

### Compound component display names

```tsx
Tabs.displayName = 'Tabs';
TabList.displayName = 'Tabs.List';
TabTrigger.displayName = 'Tabs.Trigger';
TabContent.displayName = 'Tabs.Content';

// DevTools shows hierarchy:
// Tabs
//   Tabs.List
//     Tabs.Trigger
//     Tabs.Trigger
//   Tabs.Content
```

## Generic Component Patterns

### Generic list with type inference

```tsx
interface SelectableListProps<T> {
  items: T[];
  selected: T[];
  onSelect: (item: T) => void;
  onDeselect: (item: T) => void;
  renderItem: (item: T, isSelected: boolean) => React.ReactNode;
  keyExtractor: (item: T) => string;
}

function SelectableList<T>({
  items,
  selected,
  onSelect,
  onDeselect,
  renderItem,
  keyExtractor,
}: SelectableListProps<T>) {
  const isSelected = (item: T) => selected.some(s => keyExtractor(s) === keyExtractor(item));

  return (
    <ul className="divide-y divide-gray-100">
      {items.map(item => (
        <li
          key={keyExtractor(item)}
          onClick={() => isSelected(item) ? onDeselect(item) : onSelect(item)}
          className="cursor-pointer p-2 hover:bg-gray-50"
        >
          {renderItem(item, isSelected(item))}
        </li>
      ))}
    </ul>
  );
}

// T inferred as Product from items
<SelectableList
  items={products}
  selected={selectedProducts}
  onSelect={(p) => addProduct(p)}
  onDeselect={(p) => removeProduct(p)}
  renderItem={(product, isSel) => (
    <div className={isSel ? 'bg-blue-50' : ''}>{product.name} - ${product.price}</div>
  )}
  keyExtractor={(p) => p.id}
/>
```

### Generic form field with type-safe name

```tsx
interface FormFieldProps<T> {
  name: keyof T & string;
  label: string;
  value: T[keyof T & string];
  onChange: (name: keyof T & string, value: string) => void;
  type?: 'text' | 'number' | 'email' | 'password';
  error?: string;
}

function FormField<T>({
  name,
  label,
  value,
  onChange,
  type = 'text',
  error,
}: FormFieldProps<T>) {
  return (
    <div className="space-y-1">
      <label htmlFor={name} className="text-sm font-medium text-gray-700">{label}</label>
      <input
        id={name}
        name={name}
        type={type}
        value={String(value)}
        onChange={(e) => onChange(name, e.target.value)}
        className={`w-full rounded-md border px-3 py-2 text-sm ${error ? 'border-red-500' : 'border-gray-300'}`}
      />
      {error && <p className="text-xs text-red-600">{error}</p>}
    </div>
  );
}

// Usage — name must be a key of FormData
interface FormData {
  email: string;
  password: string;
  remember: boolean;
}

<FormField<FormData>
  name="email"       // TypeScript ensures this is a key of FormData
  label="Email"
  value={formValues.email}
  onChange={(name, value) => setFormValues(prev => ({ ...prev, [name]: value }))}
  type="email"
/>
```

## Quick Reference Table

| Pattern | Use case | Key technique |
|---|---|---|
| Discriminated props | Variant with different required fields | Union of `{ variant: X; ... }` types |
| Compound component | Tabs, Accordion, Menu | Context + sub-components + display names |
| Render props | Data-driven rendering | `children: (data: T) => ReactNode` |
| Props delegation | Extending native elements | `extends ComponentPropsWithoutRef<'div'>` + Omit |
| Display name | DevTools visibility | `.displayName = 'Name'` on forwardRef/memo/arrow |
| Generic list | Type-safe reusable lists | `interface ListProps<T>` — T inferred from items |
| Generic form field | Type-safe field names | `name: keyof T & string` — key must exist on form type |