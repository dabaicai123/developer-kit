# Re-Render Optimization

Rules for minimizing unnecessary React re-renders. Re-renders are the most common React performance issue, but over-memoizing creates complexity. Profile first, then apply targeted fixes.

If your project uses React Compiler, most manual memoization is handled automatically. Only manually memoize when React DevTools Profiler confirms wasted renders.

---

## Rule 1: Memoize Only When Profiling Shows Need

Do not wrap everything in `memo()` / `useMemo()` / `useCallback()` by default. Unnecessary memoization adds complexity and can be slower than the computation it guards against.

**Bad (memoizing a simple addition):**

```tsx
function PriceDisplay({ price, tax }: { price: number; tax: number }) {
  const total = useMemo(() => price + tax, [price, tax]) // More expensive than the computation
  return <div>{total}</div>
}
```

The memoization overhead (dependency comparison + closure creation) costs more than `price + tax`.

**Good (compute inline for cheap operations):**

```tsx
function PriceDisplay({ price, tax }: { price: number; tax: number }) {
  const total = price + tax // Cheaper than useMemo overhead
  return <div>{total}</div>
}
```

When to memoize:
- React DevTools Profiler shows a component re-renders with identical props and the re-render is expensive
- Expensive computations (filtering large arrays, complex transforms, heavy math)
- Objects/arrays passed as props to memoized children

When NOT to memoize:
- Simple primitive computations
- Components that rarely re-render anyway
- Values derived from state that the component itself owns

---

## Rule 2: Use Functional setState for Stable Callbacks

When updating state based on the current value, use the functional update form. This eliminates state from dependency arrays, creating stable callbacks that never need recreation.

**Bad (requires state as dependency, stale closure risk):**

```tsx
function TodoList() {
  const [items, setItems] = useState(initialItems)

  // Recreated on every items change
  const addItem = useCallback((newItem: Item) => {
    setItems([...items, newItem])
  }, [items]) // items dependency causes recreations

  // Stale closure bug — missing items dependency
  const removeItem = useCallback((id: string) => {
    setItems(items.filter(item => item.id !== id))
  }, []) // Always references initial items!
}
```

**Good (stable callbacks, no stale closures):**

```tsx
function TodoList() {
  const [items, setItems] = useState(initialItems)

  // Stable callback, never recreated
  const addItem = useCallback((newItem: Item) => {
    setItems(curr => [...curr, newItem])
  }, []) // No dependencies needed

  // Always uses latest state
  const removeItem = useCallback((id: string) => {
    setItems(curr => curr.filter(item => item.id !== id))
  }, []) // Safe and stable
}
```

Benefits: stable callback references (no unnecessary child re-renders), no stale closures (always latest state), fewer dependencies (simpler code), eliminates the most common React closure bug.

---

## Rule 3: Never Define Components Inside Components

Defining a component inside another component creates a new component type on every render. React sees a different type and fully remounts it, destroying all state and DOM.

**Bad (remounts on every render):**

```tsx
function UserProfile({ user, theme }: { user: User; theme: string }) {
  // Defined inside to access theme — creates new type every render
  const Avatar = () => (
    <img
      src={user.avatarUrl}
      className={theme === 'dark' ? 'avatar-dark' : 'avatar-light'}
    />
  )

  return <div><Avatar /></div>
}
```

Every render creates a new `Avatar` type. React unmounts old instances and mounts new ones, losing internal state.

**Good (pass props instead):**

```tsx
function Avatar({ src, theme }: { src: string; theme: string }) {
  return (
    <img
      src={src}
      className={theme === 'dark' ? 'avatar-dark' : 'avatar-light'}
    />
  )
}

function UserProfile({ user, theme }: { user: User; theme: string }) {
  return <div><Avatar src={user.avatarUrl} theme={theme} /></div>
}
```

Symptoms of inline components: input fields lose focus on keystroke, animations restart unexpectedly, `useEffect` cleanup/setup runs on every parent render, scroll position resets.

---

## Rule 4: Derive State During Render, Not via Effects

If a value can be computed from current props/state, compute it during render. Never sync it via `useEffect + setState`.

**Bad (redundant state and effect, extra render cycle):**

```tsx
function Form() {
  const [firstName, setFirstName] = useState('First')
  const [lastName, setLastName] = useState('Last')
  const [fullName, setFullName] = useState('')

  useEffect(() => {
    setFullName(firstName + ' ' + lastName)
  }, [firstName, lastName])

  return <p>{fullName}</p>
}
```

Three state variables, one effect, and an extra render cycle for every name change. The effect sets state that triggers another render.

**Good (derive during render):**

```tsx
function Form() {
  const [firstName, setFirstName] = useState('First')
  const [lastName, setLastName] = useState('Last')
  const fullName = firstName + ' ' + lastName // Derived inline

  return <p>{fullName}</p>
}
```

One render per name change. No effect, no extra state, no extra render cycle.

---

## Rule 5: Narrow Effect Dependencies

Use primitive dependencies instead of objects to minimize effect re-runs.

**Bad (re-runs on any user field change):**

```tsx
useEffect(() => {
  logUserAction(user.id)
}, [user]) // Re-runs when user.name, user.email, any field changes
```

**Good (re-runs only when id changes):**

```tsx
useEffect(() => {
  logUserAction(user.id)
}, [user.id]) // Re-runs only when id changes
```

### Subscribe to Derived Booleans, Not Continuous Values

**Bad (re-renders on every pixel change):**

```tsx
function Sidebar() {
  const width = useWindowWidth() // Updates continuously
  const isMobile = width < 768
  return <nav className={isMobile ? 'mobile' : 'desktop'} />
}
```

**Good (re-renders only on boolean transition):**

```tsx
function Sidebar() {
  const isMobile = useMediaQuery('(max-width: 767px)')
  return <nav className={isMobile ? 'mobile' : 'desktop'} />
}
```

---

## Rule 6: Extract Default Non-Primitive Props to Constants

When a memoized component has default values for non-primitive props (arrays, functions, objects), inline defaults break memoization because each render creates new references.

**Bad (onClick breaks memoization):**

```tsx
const UserAvatar = memo(function UserAvatar({
  onClick = () => {},
}: { onClick?: () => void }) {
  // onClick is a new function every render
})

// Called without onClick — default breaks memo
<UserAvatar />
```

**Good (stable default value):**

```tsx
const NOOP = () => {}

const UserAvatar = memo(function UserAvatar({
  onClick = NOOP,
}: { onClick?: () => void }) {
  // onClick is the same reference every render
})

// Called without onClick — memo works correctly
<UserAvatar />
```

---

## Rule 7: Lazy State Initialization

Pass a function to `useState` for expensive initial values. Without the function form, the initializer runs on every render even though the result is only used once.

**Bad (runs on every render):**

```tsx
function FilteredList({ items }: { items: Item[] }) {
  const [searchIndex, setSearchIndex] = useState(buildSearchIndex(items))
  // buildSearchIndex() runs on EVERY render

  const [settings, setSettings] = useState(
    JSON.parse(localStorage.getItem('settings') || '{}')
  )
  // JSON.parse runs on every render
}
```

**Good (runs only once):**

```tsx
function FilteredList({ items }: { items: Item[] }) {
  const [searchIndex, setSearchIndex] = useState(() => buildSearchIndex(items))
  // buildSearchIndex() runs ONLY on initial render

  const [settings, setSettings] = useState(() => {
    const stored = localStorage.getItem('settings')
    return stored ? JSON.parse(stored) : {}
  })
  // JSON.parse runs only on initial render
}
```

Use lazy initialization when: computing from localStorage/sessionStorage, building data structures (indexes, maps), reading from DOM, heavy transformations. Not needed for simple primitives like `useState(0)`.

---

## Rule 8: Split Combined Hook Computations

When a `useMemo` contains independent sub-computations with different deps, split them into separate `useMemo` calls. A combined hook reruns everything when any dependency changes.

**Bad (changing sortOrder recomputes filtering):**

```tsx
const sortedProducts = useMemo(() => {
  const filtered = products.filter(p => p.category === category)
  const sorted = filtered.toSorted((a, b) =>
    sortOrder === 'asc' ? a.price - b.price : b.price - a.price
  )
  return sorted
}, [products, category, sortOrder]) // sortOrder change reruns filter
```

**Good (filtering only recomputes when products or category change):**

```tsx
const filteredProducts = useMemo(
  () => products.filter(p => p.category === category),
  [products, category],
)

const sortedProducts = useMemo(
  () => filteredProducts.toSorted((a, b) =>
    sortOrder === 'asc' ? a.price - b.price : b.price - a.price
  ),
  [filteredProducts, sortOrder],
)
```

---

## Rule 9: Defer State Reads to Usage Point

Don't subscribe to dynamic state if you only read it inside callbacks.

**Bad (subscribes to all searchParams changes):**

```tsx
function ShareButton({ chatId }: { chatId: string }) {
  const searchParams = useSearchParams() // Re-renders on any param change

  const handleShare = () => {
    const ref = searchParams.get('ref')
    shareChat(chatId, { ref })
  }

  return <button onClick={handleShare}>Share</button>
}
```

**Good (reads on demand, no subscription):**

```tsx
function ShareButton({ chatId }: { chatId: string }) {
  const handleShare = () => {
    const params = new URLSearchParams(window.location.search)
    const ref = params.get('ref')
    shareChat(chatId, { ref })
  }

  return <button onClick={handleShare}>Share</button>
}
```

The button never re-renders from param changes since it doesn't subscribe to them.

---

## Rule 10: Put Interaction Logic in Event Handlers

If a side effect is triggered by a specific user action (click, submit), run it in the event handler. Modeling it as state + effect causes re-runs on unrelated changes and duplicates the action.

**Bad (event modeled as state + effect):**

```tsx
function Form() {
  const [submitted, setSubmitted] = useState(false)
  const theme = useContext(ThemeContext)

  useEffect(() => {
    if (submitted) {
      post('/api/register')
      showToast('Registered', theme)
    }
  }, [submitted, theme]) // Re-runs when theme changes too

  return <button onClick={() => setSubmitted(true)}>Submit</button>
}
```

**Good (do it in the handler):**

```tsx
function Form() {
  const theme = useContext(ThemeContext)

  function handleSubmit() {
    post('/api/register')
    showToast('Registered', theme)
  }

  return <button onClick={handleSubmit}>Submit</button>
}
```

No effect, no extra state, no risk of re-running.

---

## Rule 11: Use startTransition for Non-Urgent Updates

Mark frequent, non-urgent state updates as transitions to keep the UI responsive for urgent updates (typing, clicking).

**Good (non-blocking updates):**

```tsx
import { startTransition } from 'react'

function SearchResults({ query }: { query: string }) {
  const [results, setResults] = useState<Item[]>([])

  useEffect(() => {
    // Urgent: update input immediately
    // Non-urgent: update results as transition
    startTransition(() => {
      setResults(filterItems(query))
    })
  }, [query])

  return <ResultsList results={results} />
}
```

---

## Rule 12: useDeferredValue for Expensive Renders

When user input triggers expensive renders, use `useDeferredValue` to keep the input responsive.

**Bad (input feels laggy during filtering):**

```tsx
function Search({ items }: { items: Item[] }) {
  const [query, setQuery] = useState('')
  const filtered = items.filter(item => fuzzyMatch(item, query))

  return (
    <>
      <input value={query} onChange={e => setQuery(e.target.value)} />
      <ResultsList results={filtered} />
    </>
  )
}
```

**Good (input stays snappy, results render when ready):**

```tsx
function Search({ items }: { items: Item[] }) {
  const [query, setQuery] = useState('')
  const deferredQuery = useDeferredValue(query)
  const filtered = useMemo(
    () => items.filter(item => fuzzyMatch(item, deferredQuery)),
    [items, deferredQuery],
  )
  const isStale = query !== deferredQuery

  return (
    <>
      <input value={query} onChange={e => setQuery(e.target.value)} />
      <div className={isStale ? 'opacity-70' : ''}>
        <ResultsList results={filtered} />
      </div>
    </>
  )
}
```

The input updates immediately. The filtered results lag behind and render when the browser is idle. Wrap the expensive computation in `useMemo` with the deferred value as a dependency.

---

## Rule 13: Use useRef for Transient Frequent Values

Values that change frequently but don't affect rendering (scroll positions, animation counters, timer IDs) should use `useRef` instead of state to avoid re-renders.

**Bad (re-renders on every scroll pixel):**

```tsx
function ScrollTracker() {
  const [scrollY, setScrollY] = useState(0)
  useEffect(() => {
    const handler = () => setScrollY(window.scrollY)
    window.addEventListener('scroll', handler, { passive: true })
    return () => window.removeEventListener('scroll', handler)
  }, [])
  // Re-renders on every pixel change
}
```

**Good (no re-renders for transient values):**

```tsx
function ScrollTracker() {
  const scrollYRef = useRef(0)
  useEffect(() => {
    const handler = () => {
      scrollYRef.current = window.scrollY // No re-render
    }
    window.addEventListener('scroll', handler, { passive: true })
    return () => window.removeEventListener('scroll', handler)
  }, [])
}
```

Only update state from a ref when the value actually needs to affect rendering (e.g., `isMobile` boolean transition, not `scrollY` pixel value).