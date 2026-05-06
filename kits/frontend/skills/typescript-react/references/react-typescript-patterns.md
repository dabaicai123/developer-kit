# React TypeScript Patterns

Props typing, hook typing, forwardRef, context typing, and polymorphic components.

## Props Typing

### Interface for props

[HARD RULE] Use `interface` for component props. Supports extending, declaration merging, and is the conventional React pattern.

```tsx
// Basic props interface
interface UserCardProps {
  name: string;
  avatarUrl: string;
  isActive?: boolean; // optional prop
}

function UserCard({ name, avatarUrl, isActive = false }: UserCardProps) {
  return (
    <div className={`flex items-center gap-3 ${isActive ? 'opacity-100' : 'opacity-50'}`}>
      <img src={avatarUrl} alt={name} className="w-10 h-10 rounded-full" />
      <span className="text-sm font-medium">{name}</span>
    </div>
  );
}
```

### Extending native element props

Use `ComponentPropsWithoutRef` to extend native HTML element props without pulling in `ref`.

```tsx
import { type ComponentPropsWithoutRef } from 'react';

// Extend button props
interface ButtonProps extends ComponentPropsWithoutRef<'button'> {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  isLoading?: boolean;
}

function Button({ variant = 'primary', size = 'md', isLoading, children, ...rest }: ButtonProps) {
  const base = 'inline-flex items-center justify-center rounded-md font-medium transition-colors';
  const variants = {
    primary: 'bg-blue-500 text-white hover:bg-blue-600',
    secondary: 'bg-gray-100 text-gray-800 hover:bg-gray-200',
    ghost: 'bg-transparent text-gray-600 hover:bg-gray-50',
  };
  const sizes = {
    sm: 'h-8 px-3 text-xs',
    md: 'h-10 px-4 text-sm',
    lg: 'h-12 px-6 text-base',
  };

  return (
    <button
      className={`${base} ${variants[variant]} ${sizes[size]}`}
      disabled={isLoading || rest.disabled}
      {...rest}
    >
      {isLoading ? 'Loading...' : children}
    </button>
  );
}
```

### Generic props for reusable components

Generic props enable type inference for reusable list, table, and selection components.

```tsx
// Generic list component — T is inferred from items
interface ListProps<T> {
  items: T[];
  renderItem: (item: T) => React.ReactNode;
  keyExtractor: (item: T) => string;
  emptyMessage?: string;
}

function List<T>({ items, renderItem, keyExtractor, emptyMessage = 'No items' }: ListProps<T>) {
  if (items.length === 0) {
    return <p className="text-gray-500 text-sm">{emptyMessage}</p>;
  }

  return (
    <ul className="divide-y divide-gray-100">
      {items.map(item => (
        <li key={keyExtractor(item)} className="py-2">
          {renderItem(item)}
        </li>
      ))}
    </ul>
  );
}

// Usage — T inferred as User from items
<List
  items={users}
  renderItem={(user) => <UserCard name={user.name} avatarUrl={user.avatarUrl} />}
  keyExtractor={(user) => user.id}
/>
```

### Children typing

Use `React.ReactNode` for `children` only when the component actually renders children. `ReactNode` includes strings, numbers, elements, arrays, null, undefined, and booleans.

```tsx
interface LayoutProps {
  children: React.ReactNode;
  sidebar?: React.ReactNode; // slot pattern — separate children areas
}

function Layout({ children, sidebar }: LayoutProps) {
  return (
    <div className="flex gap-6">
      {sidebar && <aside className="w-64 shrink-0">{sidebar}</aside>}
      <main className="flex-1 min-w-0">{children}</main>
    </div>
  );
}

// Render prop pattern — typed callback
interface DataListProps<T> {
  items: T[];
  children: (item: T, index: number) => React.ReactNode;
}

function DataList<T>({ items, children }: DataListProps<T>) {
  return (
    <ul>
      {items.map((item, i) => (
        <li key={i}>{children(item, i)}</li>
      ))}
    </ul>
  );
}

// Usage
<DataList items={users}>
  {(user, index) => <UserCard user={user} rank={index + 1} />}
</DataList>
```

### Event handler props

```tsx
interface SearchInputProps {
  value: string;
  onChange: (e: React.ChangeEvent<HTMLInputElement>) => void;
  onSubmit?: (e: React.FormEvent<HTMLFormElement>) => void;
  onKeyDown?: (e: React.KeyboardEvent<HTMLInputElement>) => void;
  onFocus?: (e: React.FocusEvent<HTMLInputElement>) => void;
}

function SearchInput({ value, onChange, onSubmit, onKeyDown, onFocus }: SearchInputProps) {
  return (
    <form onSubmit={onSubmit}>
      <input
        type="text"
        value={value}
        onChange={onChange}
        onKeyDown={onKeyDown}
        onFocus={onFocus}
        className="w-full rounded-md border border-gray-300 px-3 py-2 text-sm"
      />
    </form>
  );
}
```

## Hook Typing

### useState

```tsx
// Primitive — type inferred from initial value
const [count, setCount] = useState(0);           // number
const [name, setName] = useState('');            // string
const [isOpen, setIsOpen] = useState(false);     // boolean

// Nullable — explicit type needed when initial is null/undefined
const [user, setUser] = useState<User | null>(null);
const [error, setError] = useState<Error | undefined>(undefined);

// Complex state — explicit type for object shapes
interface FilterState {
  category: string;
  sortBy: 'name' | 'date' | 'price';
  page: number;
}
const [filters, setFilters] = useState<FilterState>({
  category: 'all',
  sortBy: 'date',
  page: 1,
});

// Partial update pattern for object state
const [filters, setFilters] = useState<FilterState>(defaultFilters);
setFilters(prev => ({ ...prev, category: 'electronics' })); // partial update
```

### useRef

```tsx
// DOM element ref — specific element type
const inputRef = useRef<HTMLInputElement>(null);
const dialogRef = useRef<HTMLDialogElement>(null);
const divRef = useRef<HTMLDivElement>(null);

// Mutable value ref — type matches stored value
const prevValueRef = useRef<string>('');         // stores previous value
const timerRef = useRef<ReturnType<typeof setInterval>>(undefined); // stores timer ID
const controllerRef = useRef<AbortController | null>(null); // stores AbortController

// DOM ref access — null check required
function focusInput() {
  inputRef.current?.focus();            // null check with optional chaining
  inputRef.current?.setCustomValidity('Required'); // element-specific methods
}
```

### useReducer with discriminated actions

```tsx
interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

// State
interface CartState {
  items: CartItem[];
  total: number;
}

// Discriminated action types
type CartAction =
  | { type: 'add'; item: Omit<CartItem, 'quantity'> }
  | { type: 'remove'; id: string }
  | { type: 'update_quantity'; id: string; quantity: number }
  | { type: 'clear' };

// Reducer — exhaustive switch
function cartReducer(state: CartState, action: CartAction): CartState {
  switch (action.type) {
    case 'add':
      const existing = state.items.find(i => i.id === action.item.id);
      if (existing) {
        return {
          ...state,
          items: state.items.map(i =>
            i.id === action.item.id ? { ...i, quantity: i.quantity + 1 } : i
          ),
          total: state.total + action.item.price,
        };
      }
      return {
        ...state,
        items: [...state.items, { ...action.item, quantity: 1 }],
        total: state.total + action.item.price,
      };

    case 'remove':
      const removed = state.items.find(i => i.id === action.id);
      return {
        ...state,
        items: state.items.filter(i => i.id !== action.id),
        total: state.total - (removed ? removed.price * removed.quantity : 0),
      };

    case 'update_quantity':
      return {
        ...state,
        items: state.items.map(i =>
          i.id === action.id ? { ...i, quantity: action.quantity } : i
        ),
        total: state.items.reduce((sum, i) =>
          i.id === action.id ? sum + action.quantity * i.price : sum + i.quantity * i.price, 0
        ),
      };

    case 'clear':
      return { items: [], total: 0 };

    default:
      const _exhaustive: never = action;
      return _exhaustive;
  }
}

// Usage
const [cart, dispatch] = useReducer(cartReducer, { items: [], total: 0 });
dispatch({ type: 'add', item: { id: '1', name: 'Widget', price: 9.99 } });
dispatch({ type: 'remove', id: '1' });
```

### useContext

```tsx
// Create context with explicit type
interface ThemeContextValue {
  theme: 'light' | 'dark';
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

// Provider with type safety
function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setTheme] = useState<'light' | 'dark'>('light');

  const toggleTheme = () => setTheme(prev => prev === 'light' ? 'dark' : 'light');

  const value: ThemeContextValue = { theme, toggleTheme };

  return (
    <ThemeContext.Provider value={value}>
      {children}
    </ThemeContext.Provider>
  );
}

// Consumer hook with null check
function useTheme(): ThemeContextValue {
  const context = useContext(ThemeContext);
  if (!context) {
    throw new Error('useTheme must be used within a ThemeProvider');
  }
  return context;
}

// Usage
function ThemeToggle() {
  const { theme, toggleTheme } = useTheme();
  return (
    <button
      onClick={toggleTheme}
      className={`p-2 rounded ${theme === 'dark' ? 'bg-gray-800 text-white' : 'bg-white text-gray-800'}`}
    >
      Switch to {theme === 'light' ? 'dark' : 'light'} mode
    </button>
  );
}
```

## forwardRef Patterns

```tsx
// Basic forwardRef — ref targets the underlying element
interface InputProps extends ComponentPropsWithoutRef<'input'> {
  label?: string;
  error?: string;
}

const Input = forwardRef<HTMLInputElement, InputProps>(
  ({ label, error, className, ...rest }, ref) => {
    return (
      <div className="space-y-1">
        {label && <label className="text-sm font-medium text-gray-700">{label}</label>}
        <input
          ref={ref}
          className={`w-full rounded-md border px-3 py-2 text-sm ${
            error ? 'border-red-500' : 'border-gray-300'
          } ${className ?? ''}`}
          {...rest}
        />
        {error && <p className="text-xs text-red-600">{error}</p>}
      </div>
    );
  }
);

Input.displayName = 'Input'; // required for DevTools

// Usage — parent controls focus
function Form() {
  const emailRef = useRef<HTMLInputElement>(null);

  function handleFocusEmail() {
    emailRef.current?.focus();
  }

  return (
    <form>
      <Input ref={emailRef} label="Email" type="email" />
      <button type="button" onClick={handleFocusEmail}>Focus email</button>
    </form>
  );
}
```

### forwardRef with generic component

```tsx
// Generic forwardRef — type parameters go on the outer function
interface SelectProps<T> extends ComponentPropsWithoutRef<'select'> {
  options: T[];
  valueExtractor: (option: T) => string;
  labelExtractor: (option: T) => string;
}

const Select = forwardRef<HTMLSelectElement, SelectProps<any>>(
  ({ options, valueExtractor, labelExtractor, ...rest }, ref) => {
    return (
      <select ref={ref} {...rest}>
        {options.map(opt => (
          <option key={valueExtractor(opt)} value={valueExtractor(opt)}>
            {labelExtractor(opt)}
          </option>
        ))}
      </select>
    );
  }
);

Select.displayName = 'Select';
```

Note: `forwardRef` with generics requires some type gymnastics. For most cases, use the pattern above with `SelectProps<any>` and narrow in usage. TypeScript 5.x with React 19 may simplify this with ref as a regular prop.

## Polymorphic Components

The "as" prop pattern lets a component render as different HTML elements while preserving type safety.

```tsx
// Polymorphic component with "as" prop
interface TextProps<C extends React.ElementType = 'span'> {
  as?: C;
  size?: 'sm' | 'md' | 'lg';
  children: React.ReactNode;
  className?: string;
}

function Text<C extends React.ElementType = 'span'>({
  as,
  size = 'md',
  children,
  className,
  ...rest
}: TextProps<C> & Omit<ComponentPropsWithoutRef<C>, keyof TextProps<C>>) {
  const Component = as || 'span';

  const sizes = {
    sm: 'text-sm',
    md: 'text-base',
    lg: 'text-lg',
  };

  return (
    <Component className={`${sizes[size]} ${className ?? ''}`} {...rest}>
      {children}
    </Component>
  );
}

// Usage — type inference adapts to "as" prop
<Text size="lg">Default span</Text>
<Text as="h1" size="lg">Heading — gets heading-specific props</Text>
<Text as="p" size="sm">Paragraph text</Text>
<Text as="a" href="/about" size="sm">Link — gets anchor props like href</Text>
<Text as="button" onClick={() => {}} size="md">Button text — gets button props</Text>
```

### Strict polymorphic with disabled invalid props

```tsx
// Prevent invalid prop combinations
type PolymorphicProps<C extends React.ElementType, Props = object> =
  Props & Omit<ComponentPropsWithoutRef<C>, keyof Props | 'as'> & {
    as?: C;
  };

// Example: Card renders as div or article
interface CardBaseProps {
  variant?: 'default' | 'highlighted' | 'bordered';
  padding?: 'none' | 'sm' | 'md' | 'lg';
}

type CardProps<C extends React.ElementType> = PolymorphicProps<C, CardBaseProps>;

function Card<C extends React.ElementType = 'div'>({
  as,
  variant = 'default',
  padding = 'md',
  className,
  children,
  ...rest
}: CardProps<C>) {
  const Component = as || 'div';

  const variants = {
    default: 'bg-white shadow-sm',
    highlighted: 'bg-blue-50 shadow-md',
    bordered: 'border border-gray-200',
  };

  const paddings = {
    none: '',
    sm: 'p-2',
    md: 'p-4',
    lg: 'p-6',
  };

  return (
    <Component className={`rounded-lg ${variants[variant]} ${paddings[padding]} ${className ?? ''}`} {...rest}>
      {children}
    </Component>
  );
}

// Usage
<Card variant="bordered" padding="lg">Regular div card</Card>
<Card as="article" variant="highlighted">Article card</Card>
<Card as="section" padding="none">Section card</Card>
```

## Quick Reference Table

| Pattern | Use case | Key type |
|---|---|---|
| Props interface | Component props | `interface XProps { ... }` |
| Extending native props | Button, Input, Link | `extends ComponentPropsWithoutRef<'element'>` |
| Generic props | List, Table, Select | `interface ListProps<T> { items: T[]; ... }` |
| Children | Layout, Wrapper | `children: React.ReactNode` |
| Render prop children | Data-driven rendering | `children: (item: T) => ReactNode` |
| Event handlers | Form, Input, Button | `React.ChangeEvent<HTMLInputElement>` etc |
| useState | State with nullable initial | `useState<T | null>(null)` |
| useRef DOM | DOM access | `useRef<HTMLXElement>(null)` |
| useRef value | Mutable value | `useRef<T>(initial)` |
| useReducer | Complex state | Discriminated action union + switch |
| useContext | Shared state | `createContext<T | null>(null)` + null guard hook |
| forwardRef | Ref forwarding | `forwardRef<HTMLElement, Props>` |
| Polymorphic "as" | Flexible element type | `as?: C extends ElementType` + `Omit<ComponentPropsWithoutRef<C>, ...>` |