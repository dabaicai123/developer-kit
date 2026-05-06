# Hooks and Events

useState, useReducer, useEffect, custom hooks, event handler types, and async handlers.

## useState Typing

### Primitive state — type inferred from initial value

```tsx
const [count, setCount] = useState(0);        // number
const [name, setName] = useState('');         // string
const [isOpen, setIsOpen] = useState(false);  // boolean
const [tags, setTags] = useState<string[]>([]); // string[] — explicit when initial is empty
```

### Nullable state — explicit type required

```tsx
// Without explicit type, useState(null) infers type as null — can never set a real value
const [user, setUser] = useState<User | null>(null);
const [error, setError] = useState<Error | undefined>(undefined);

// Null check before accessing properties
if (user) {
  // TypeScript knows user is User, not null
  console.log(user.name);
}
```

### Object state — explicit type + partial updates

```tsx
interface FilterState {
  category: string;
  sortBy: 'name' | 'date' | 'price';
  page: number;
}

const defaultFilters: FilterState = {
  category: 'all',
  sortBy: 'date',
  page: 1,
};

const [filters, setFilters] = useState<FilterState>(defaultFilters);

// Partial update — spread previous state
setFilters(prev => ({ ...prev, category: 'electronics' }));
setFilters(prev => ({ ...prev, page: prev.page + 1 }));

// Reset to default
setFilters(defaultFilters);
```

### Toggle state

```tsx
// Boolean toggle
const [isOpen, setIsOpen] = useState(false);
setIsOpen(prev => !prev); // toggle without referencing current value

// Set from event
<button onClick={() => setIsOpen(prev => !prev)}>Toggle</button>
```

## useReducer with Discriminated Action Types

useReducer handles complex state transitions better than multiple useState calls. Use discriminated action unions for exhaustive type checking.

```tsx
// State shape
interface FormState {
  values: Record<string, string>;
  errors: Record<string, string>;
  isSubmitting: boolean;
  submitResult: { success: boolean; message: string } | null;
}

// Discriminated actions
type FormAction =
  | { type: 'set_value'; field: string; value: string }
  | { type: 'set_error'; field: string; error: string }
  | { type: 'clear_error'; field: string }
  | { type: 'start_submit' }
  | { type: 'submit_success'; message: string }
  | { type: 'submit_failure'; message: string }
  | { type: 'reset' };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (action.type) {
    case 'set_value':
      return { ...state, values: { ...state.values, [action.field]: action.value } };

    case 'set_error':
      return { ...state, errors: { ...state.errors, [action.field]: action.error } };

    case 'clear_error':
      return { ...state, errors: { ...state.errors, [action.field]: '' } };

    case 'start_submit':
      return { ...state, isSubmitting: true, submitResult: null, errors: {} };

    case 'submit_success':
      return { ...state, isSubmitting: false, submitResult: { success: true, message: action.message } };

    case 'submit_failure':
      return { ...state, isSubmitting: false, submitResult: { success: false, message: action.message } };

    case 'reset':
      return { values: {}, errors: {}, isSubmitting: false, submitResult: null };

    default:
      const _exhaustive: never = action;
      return _exhaustive;
  }
}

// Usage
const [state, dispatch] = useReducer(formReducer, {
  values: {},
  errors: {},
  isSubmitting: false,
  submitResult: null,
});

dispatch({ type: 'set_value', field: 'email', value: 'user@example.com' });
dispatch({ type: 'start_submit' });
```

## useEffect Cleanup Typing

```tsx
// Cleanup function returns void (or undefined)
useEffect(() => {
  const controller = new AbortController();

  fetch('/api/data', { signal: controller.signal })
    .then(res => res.json())
    .then(setData)
    .catch(err => { if (err.name !== 'AbortError') setError(err); });

  return () => controller.abort(); // cleanup: void return
}, [url]);

// Subscription cleanup
useEffect(() => {
  const subscription = eventBus.subscribe('data-update', handleUpdate);
  return () => subscription.unsubscribe(); // void return
}, []);

// Timer cleanup
useEffect(() => {
  const id = setInterval(() => tick(), 1000);
  return () => clearInterval(id); // void return
}, []);

// Multiple cleanups — combine in one return
useEffect(() => {
  window.addEventListener('resize', handleResize);
  const id = setInterval(pollData, 5000);
  const ws = new WebSocket(url);
  ws.onmessage = handleMessage;

  return () => {
    window.removeEventListener('resize', handleResize);
    clearInterval(id);
    ws.close();
  }; // single cleanup handles all three
}, []);
```

## Custom Hook Patterns

### Return type: tuple vs object

Choose based on how many values the hook returns and whether positional access makes sense.

```tsx
// TUPLE return — for 2-3 related values where order is conventional
// Like useState: [value, setter]
function useToggle(initial = false): [boolean, () => void] {
  const [value, setValue] = useState(initial);
  const toggle = useCallback(() => setValue(prev => !prev), []);
  return [value, toggle];
}

const [isOpen, toggle] = useToggle(); // positional destructuring, like useState

// OBJECT return — for 3+ values or when names matter more than order
interface UseFormResult {
  values: Record<string, string>;
  errors: Record<string, string>;
  handleChange: (e: ChangeEvent<HTMLInputElement>) => void;
  handleSubmit: (e: FormEvent<HTMLFormElement>) => void;
  isSubmitting: boolean;
  reset: () => void;
}

function useForm(initialValues: Record<string, string>): UseFormResult {
  // ... implementation
  return { values, errors, handleChange, handleSubmit, isSubmitting, reset };
}

const { values, handleChange, handleSubmit } = useForm({ email: '', password: '' });
// Named destructuring — caller chooses what to use
```

**Rule**: Use tuple when the hook mirrors useState convention (value + setter). Use object for anything with 3+ named return values.

### Generic custom hook

```tsx
function useFetch<T>(url: string): {
  data: T | null;
  isLoading: boolean;
  error: Error | null;
  refetch: () => void;
} {
  const [data, setData] = useState<T | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const fetchData = useCallback(async () => {
    setIsLoading(true);
    setError(null);
    try {
      const res = await fetch(url);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json: T = await res.json();
      setData(json);
    } catch (err) {
      setError(err instanceof Error ? err : new Error(String(err)));
    } finally {
      setIsLoading(false);
    }
  }, [url]);

  useEffect(() => {
    fetchData();
  }, [fetchData]);

  return { data, isLoading, error, refetch: fetchData };
}

// T inferred from url usage
const { data: users, isLoading } = useFetch<User[]>('/api/users');
```

### Hook with context dependency

```tsx
function useAuth(): {
  user: User | null;
  isAuthenticated: boolean;
  login: (credentials: LoginInput) => Promise<void>;
  logout: () => void;
} {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');

  return {
    user: context.user,
    isAuthenticated: context.user !== null,
    login: context.login,
    logout: context.logout,
  };
}
```

## Event Handler Types

### Input element events

```tsx
// ChangeEvent — for input, textarea, select value changes
function handleTextChange(e: React.ChangeEvent<HTMLInputElement>) {
  setInputValue(e.target.value); // e.target is HTMLInputElement
}

function handleSelectChange(e: React.ChangeEvent<HTMLSelectElement>) {
  setSelected(e.target.value); // e.target is HTMLSelectElement
}

// KeyboardEvent — for key presses
function handleKeyDown(e: React.KeyboardEvent<HTMLInputElement>) {
  if (e.key === 'Enter') {
    e.preventDefault();
    submitSearch();
  }
  if (e.key === 'Escape') {
    clearSearch();
  }
}

// FocusEvent — for focus/blur
function handleFocus(e: React.FocusEvent<HTMLInputElement>) {
  setIsFocused(true);
  // e.target is HTMLInputElement, e.relatedTarget is Element (the element losing/gaining focus)
}

function handleBlur(e: React.FocusEvent<HTMLInputElement>) {
  setIsFocused(false);
  validateInput(e.target.value);
}
```

### Form events

```tsx
// FormEvent — for form submission
function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
  e.preventDefault();
  const formData = new FormData(e.currentTarget); // e.currentTarget is HTMLFormElement
  const email = formData.get('email') as string;
  const password = formData.get('password') as string;
  submitLogin({ email, password });
}

// Usage in JSX
<form onSubmit={handleSubmit}>
  <input name="email" type="email" required />
  <input name="password" type="password" required />
  <button type="submit">Login</button>
</form>
```

### Click events

```tsx
// MouseEvent — for click, double-click, context menu
function handleClick(e: React.MouseEvent<HTMLButtonElement>) {
  // e.currentTarget is HTMLButtonElement
  // e.clientX, e.clientY for click coordinates
  setIsOpen(prev => !prev);
}

function handleContextMenu(e: React.MouseEvent<HTMLDivElement>) {
  e.preventDefault();
  setContextMenuPosition({ x: e.clientX, y: e.clientY });
}
```

### Drag events

```tsx
function handleDragStart(e: React.DragEvent<HTMLDivElement>) {
  e.dataTransfer.setData('text/plain', itemId);
  e.dataTransfer.effectAllowed = 'move';
}

function handleDrop(e: React.DragEvent<HTMLDivElement>) {
  e.preventDefault();
  const id = e.dataTransfer.getData('text/plain');
  moveItem(id, targetPosition);
}
```

### Clipboard events

```tsx
function handleCopy(e: React.ClipboardEvent<HTMLInputElement>) {
  e.preventDefault(); // prevent default copy
  navigator.clipboard.writeText(customText); // copy custom text
}
```

### Event type reference table

| Event | React type | Element types | Key properties |
|---|---|---|---|
| Input change | `ChangeEvent<T>` | HTMLInputElement, HTMLTextAreaElement, HTMLSelectElement | `target.value` |
| Key press | `KeyboardEvent<T>` | HTMLInputElement, HTMLTextAreaElement | `key`, `code`, `shiftKey`, `metaKey` |
| Focus/blur | `FocusEvent<T>` | HTMLInputElement, HTMLTextAreaElement | `relatedTarget` |
| Form submit | `FormEvent<T>` | HTMLFormElement | `preventDefault()`, `currentTarget` |
| Click | `MouseEvent<T>` | HTMLButtonElement, HTMLDivElement, HTMLAnchorElement | `clientX`, `clientY`, `button` |
| Drag | `DragEvent<T>` | HTMLDivElement | `dataTransfer` |
| Clipboard | `ClipboardEvent<T>` | HTMLInputElement | `clipboardData` |
| Scroll | `UIEvent<T>` | HTMLDivElement | `target.scrollTop` |
| Animation | `AnimationEvent<T>` | HTMLDivElement | `animationName`, `elapsedTime` |

## Async Event Handlers

React event handlers must return `void`. Async functions return `Promise<void>`. Wrap async logic in a void-returning handler.

```tsx
// CORRECT — void wrapper for async logic
function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
  e.preventDefault();
  void submitOrder(); // explicitly fire-and-forget
}

async function submitOrder() {
  try {
    const result = await api.createOrder(formData);
    router.push(`/orders/${result.id}`);
  } catch (err) {
    if (err instanceof Error) {
      setError(err.message);
    }
  }
}

// WRONG — async handler returns Promise<void>
async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
  e.preventDefault();
  await submitOrder(); // unhandled rejection if submitOrder throws
}
```

### Async handler with loading state

```tsx
function DeleteButton({ id }: { id: string }) {
  const [isDeleting, setIsDeleting] = useState(false);

  function handleClick() {
    void deleteItem(id);
  }

  async function deleteItem(id: string) {
    setIsDeleting(true);
    try {
      await api.deleteItem(id);
      router.refresh();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : 'Delete failed');
    } finally {
      setIsDeleting(false);
    }
  }

  return (
    <button onClick={handleClick} disabled={isDeleting} className="text-red-600 hover:text-red-800">
      {isDeleting ? 'Deleting...' : 'Delete'}
    </button>
  );
}
```

### Promise tracking for multiple async operations

```tsx
function BatchActions({ items }: { items: Item[] }) {
  const [pendingOps, setPendingOps] = useState<Set<string>>(new Set());

  function handleDelete(id: string) {
    setPendingOps(prev => new Set(prev).add(id));
    void deleteItem(id).finally(() => {
      setPendingOps(prev => {
        const next = new Set(prev);
        next.delete(id);
        return next;
      });
    });
  }

  return (
    <ul>
      {items.map(item => (
        <li key={item.id}>
          {item.name}
          <button
            onClick={() => handleDelete(item.id)}
            disabled={pendingOps.has(item.id)}
          >
            {pendingOps.has(item.id) ? 'Deleting...' : 'Delete'}
          </button>
        </li>
      ))}
    </ul>
  );
}
```

## Quick Reference Table

| Pattern | Key type | Notes |
|---|---|---|
| useState primitive | Inferred from initial | `useState(0)` is number |
| useState nullable | `useState<T \| null>(null)` | Explicit type required |
| useState object | `useState<FilterState>(default)` | Partial updates with spread |
| useReducer | Discriminated action union | Exhaustive switch, never default |
| useEffect cleanup | Return `() => void` | AbortController for fetch |
| Custom hook tuple | `[boolean, () => void]` | Like useState convention |
| Custom hook object | `{ data, isLoading, error }` | 3+ named return values |
| Input change | `ChangeEvent<HTMLInputElement>` | `e.target.value` |
| Key press | `KeyboardEvent<HTMLInputElement>` | `e.key`, `e.preventDefault()` |
| Form submit | `FormEvent<HTMLFormElement>` | `e.currentTarget`, `FormData` |
| Click | `MouseEvent<HTMLButtonElement>` | `e.clientX`, `e.clientY` |
| Async handler | Void wrapper + separate async fn | Never async handler directly |