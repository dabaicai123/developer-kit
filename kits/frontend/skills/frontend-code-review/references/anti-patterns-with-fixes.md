# Anti-Patterns with Fixes

12 common anti-patterns in React/Next.js/TypeScript/Tailwind projects, each expanded with root cause analysis, before/after code examples, step-by-step fix instructions, and explanation of why the pattern emerges.

---

## 1. Storing server data in client state

### Root cause analysis

Developers default to `useState` + `useEffect` for all data because SPA habits treat every data source as client-side. In the Pages Router era, all components were client components, so this pattern was the only option. With App Router, server components can fetch directly, and TanStack Query provides a superior client-side caching layer. But the old pattern persists through copy-paste and habit.

**Why this happens**: The mental model for data fetching in SPAs is "fetch in effect, store in state." Developers carry this model into Next.js App Router without updating it. The pattern also feels simple at first — just two hooks — but it quickly grows into loading/error/refetch state management that duplicates what TanStack Query handles automatically.

### Before

```tsx
'use client';
import { useState, useEffect } from 'react';

function UserProfile({ userId }: { userId: string }) {
  const [user, setUser] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    setIsLoading(true);
    setError(null);
    fetch(`/api/users/${userId}`)
      .then(res => {
        if (!res.ok) throw new Error('Failed to fetch user');
        return res.json();
      })
      .then(data => {
        setUser(data);
        setIsLoading(false);
      })
      .catch(err => {
        setError(err.message);
        setIsLoading(false);
      });
  }, [userId]);

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage message={error} />;
  return <div>{user.name}</div>;
}
```

Problems: no caching (refetches on every navigation back to this page), no deduplication (concurrent mounts make duplicate requests), manual loading/error/refetch state, stale data persists in state after userId changes.

### After

```tsx
'use client';
import { useQuery } from '@tanstack/react-query';

function UserProfile({ userId }: { userId: string }) {
  const { data: user, isLoading, error } = useQuery({
    queryKey: ['user', userId],
    queryFn: async () => {
      const res = await fetch(`/api/users/${userId}`);
      if (!res.ok) throw new Error('Failed to fetch user');
      return res.json();
    },
  });

  if (isLoading) return <Spinner />;
  if (error) return <ErrorMessage message={error.message} />;
  return <div>{user.name}</div>;
}
```

Or, if the data does not depend on client interaction, use a server component:

```tsx
// Server component — no hooks needed
async function UserProfile({ userId }: { userId: string }) {
  const user = await db.user.findUnique({ where: { id: userId } });
  return <div>{user.name}</div>;
}
```

### Step-by-step fix

1. Identify all `useState` + `useEffect` fetch patterns in the component
2. Check if the fetch depends on client interaction (user click, filter change). If not, move to a server component
3. If it does depend on client interaction, install TanStack Query and replace the pattern
4. Define a `queryKey` that uniquely identifies the data (include all parameters)
5. Move the fetch logic into `queryFn`
6. Remove `useState` for loading, error, and data — TanStack Query provides these
7. Add `staleTime` configuration if the data should not refetch on every window focus
8. Consider adding `loading.tsx` and `error.tsx` for the route segment as fallbacks

---

## 2. Boolean flags for state

### Root cause analysis

Developers model component state as separate boolean variables because it mirrors how they think about state verbally: "is it loading? is there an error? did it succeed?" Each question maps to a boolean. The problem is that booleans are independent — they can all be true or false simultaneously, creating impossible states the code must guard against.

**Why this happens**: Boolean flags are the simplest mental model. They feel natural when describing UI states conversationally. Developers do not realize that the flags are independent until they encounter a bug where `isLoading` and `isError` are both true, or all flags are false after an unexpected condition.

### Before

```tsx
'use client';
import { useState } from 'react';

function DataFetcher() {
  const [isLoading, setIsLoading] = useState(false);
  const [isError, setIsError] = useState(false);
  const [isSuccess, setIsSuccess] = useState(false);
  const [data, setData] = useState(null);
  const [error, setError] = useState(null);

  async function fetchData() {
    setIsLoading(true);
    setIsError(false);
    setIsSuccess(false);
    try {
      const result = await fetch('/api/data');
      setData(result);
      setIsSuccess(true);
    } catch (err) {
      setError(err);
      setIsError(true);
    } finally {
      setIsLoading(false);
    }
  }

  // Problem: isLoading && isError can both be true during transition
  // Problem: data exists even when isError is true (stale data)
  // Problem: what state is it in when all flags are false? (idle, not yet fetched)

  if (isLoading) return <Spinner />;
  if (isError) return <ErrorMessage error={error} />;
  if (isSuccess) return <DataDisplay data={data} />;
  return <button onClick={fetchData}>Load data</button>;
}
```

### After

```tsx
'use client';
import { useState } from 'react';

type FetchState<T> =
  | { status: 'idle' }
  | { status: 'loading' }
  | { status: 'error'; error: Error }
  | { status: 'success'; data: T };

function DataFetcher() {
  const [state, setState] = useState<FetchState<Data>>({ status: 'idle' });

  async function fetchData() {
    setState({ status: 'loading' });
    try {
      const result = await fetch('/api/data');
      setState({ status: 'success', data: result });
    } catch (err) {
      setState({ status: 'error', error: err as Error });
    }
  }

  switch (state.status) {
    case 'idle': return <button onClick={fetchData}>Load data</button>;
    case 'loading': return <Spinner />;
    case 'error': return <ErrorMessage error={state.error} />;
    case 'success': return <DataDisplay data={state.data} />;
  }
}
```

Impossible states are now impossible: the component can only be in one status at a time, and each status carries exactly the data it needs (error with Error, success with Data).

### Step-by-step fix

1. List all boolean state variables that represent mutually exclusive phases of the same lifecycle
2. Define a discriminated union type that covers each phase with its associated data
3. Replace all individual `useState` calls with a single `useState` using the union type
4. Update all state transitions to set the full state object (not individual flags)
5. Replace conditional rendering with a `switch` on the discriminant field (`status`)
6. Verify that TypeScript rejects impossible state combinations at compile time

---

## 3. Effect for derived state

### Root cause analysis

Developers use `useEffect` to compute values from other values because they treat it as a "watcher" or "observer" pattern. This pattern is common in Vue (watch/computed) and Angular (subscriptions). In React, derived values should be computed during render — effects run after render and cause an extra render cycle.

**Why this happens**: The watcher pattern feels intuitive — "when X changes, update Y." But in React, the render itself is the reactive mechanism. Computing Y from X during render means Y is always up-to-date without an extra effect cycle. Effects are for side effects (subscriptions, network requests), not for synchronizing state.

### Before

```tsx
'use client';
import { useState, useEffect } from 'react';

function SearchPage() {
  const [items, setItems] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');
  const [filteredItems, setFilteredItems] = useState([]);

  // Problem: filteredItems is computed in an effect, causing an extra render
  // Problem: filteredItems is stale for one render cycle after searchTerm changes
  useEffect(() => {
    setFilteredItems(
      items.filter(item => item.name.toLowerCase().includes(searchTerm.toLowerCase()))
    );
  }, [items, searchTerm]);

  return (
    <div>
      <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)} />
      {filteredItems.map(item => <ItemCard key={item.id} item={item} />)}
    </div>
  );
}
```

### After

```tsx
'use client';
import { useState } from 'react';

function SearchPage() {
  const [items, setItems] = useState([]);
  const [searchTerm, setSearchTerm] = useState('');

  // Compute during render — always up-to-date, no extra render cycle
  const filteredItems = items.filter(item =>
    item.name.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div>
      <input value={searchTerm} onChange={e => setSearchTerm(e.target.value)} />
      {filteredItems.map(item => <ItemCard key={item.id} item={item} />)}
    </div>
  );
}
```

If the computation is expensive and the inputs change frequently, wrap it with `useMemo`:

```tsx
const filteredItems = useMemo(
  () => items.filter(item => item.name.toLowerCase().includes(searchTerm.toLowerCase())),
  [items, searchTerm]
);
```

But only add `useMemo` when profiling shows a measurable performance problem. Most filter/map operations on reasonable data sizes are fast enough to compute directly.

### Step-by-step fix

1. Find all `useEffect` calls that set state based on other state or props (the "derived state" pattern)
2. Remove the `useState` for the derived value
3. Compute the derived value directly in the render body
4. Delete the `useEffect` that was synchronizing it
5. If the computation is expensive, add `useMemo` with appropriate dependencies
6. Verify the derived value updates correctly on every render

---

## 4. Missing Suspense boundary

### Root cause analysis

Developers skip `loading.tsx` because pages render fast in development (data is local, latency is zero), or they treat loading states as a polish item added "when we have time." When the app reaches production with real network latency and real database queries, pages that previously rendered instantly now hang without feedback.

**Why this happens**: Loading states are invisible in development. The developer sees the page appear immediately because dev data sources have no latency. When deploying to production, the same pages take 500ms-2s to load, but there is no loading UI to signal progress. The user sees a blank screen and assumes the app is broken.

### Before

```tsx
// app/dashboard/page.tsx — no loading.tsx, no Suspense
async function DashboardPage() {
  const stats = await fetchDashboardStats();     // 1-2s in production
  const recentOrders = await fetchRecentOrders(); // 500ms in production
  const notifications = await fetchNotifications(); // 200ms in production

  // User stares at a blank screen for 2-3s
  return (
    <div>
      <StatsPanel stats={stats} />
      <RecentOrders orders={recentOrders} />
      <NotificationPanel notifications={notifications} />
    </div>
  );
}
```

### After

```tsx
// app/dashboard/loading.tsx
export default function DashboardLoading() {
  return (
    <div className="flex flex-col gap-[--spacing-4]">
      <Skeleton className="h-[--spacing-16] w-full rounded-[--radius-md]" />
      <Skeleton className="h-[--spacing-32] w-full rounded-[--radius-md]" />
      <Skeleton className="h-[--spacing-8] w-full rounded-[--radius-md]" />
    </div>
  );
}

// app/dashboard/page.tsx — streaming with Suspense
import { Suspense } from 'react';

async function DashboardPage() {
  return (
    <div>
      <Suspense fallback={<StatsSkeleton />}>
        <StatsPanel />
      </Suspense>
      <Suspense fallback={<OrdersSkeleton />}>
        <RecentOrders />
      </Suspense>
      <Suspense fallback={<NotificationsSkeleton />}>
        <NotificationPanel />
      </Suspense>
    </div>
  );
}
// Each section streams in independently; the user sees skeletons that fill in progressively
```

### Step-by-step fix

1. Add `loading.tsx` alongside every page that fetches data asynchronously
2. Use skeleton placeholders that match the layout of the real content (same grid, same spacing)
3. For pages with multiple async sections, wrap each in `<Suspense>` with a targeted fallback
4. Test in development with throttled network (Chrome DevTools → Network → Slow 3G) to verify loading UI appears
5. Verify streaming works: each section should fill in independently, not wait for all sections to complete

---

## 5. Unnecessary 'use client'

### Root cause analysis

Developers add `'use client'` to every component file because the Pages Router required it for all components with hooks or interactivity, and the habit carries into App Router. Some developers add it preemptively because they are unsure which components need it, treating it as a safe default. This inflates the client JavaScript bundle and prevents server-side rendering optimizations.

**Why this happens**: The Pages Router model was "everything is client." Switching to App Router requires reversing the default: components are server unless they need client features. This mental model shift is not intuitive, and developers fall back to the familiar pattern of marking everything as client. Team codebases with many `'use client'` directives normalize the pattern.

### Before

```tsx
// 'use client' — unnecessary, this component is static
'use client';
import { User } from './types';

function UserAvatar({ user }: { user: User }) {
  return (
    <img
      src={user.avatarUrl}
      alt={user.name}
      className="w-[--spacing-10] h-[--spacing-10] rounded-[--radius-full]"
    />
  );
}
```

### After

```tsx
// Server component — no directive needed
import { User } from './types';

function UserAvatar({ user }: { user: User }) {
  return (
    <img
      src={user.avatarUrl}
      alt={user.name}
      className="w-[--spacing-10] h-[--spacing-10] rounded-[--radius-full]"
    />
  );
}
```

Only add `'use client'` when the component genuinely needs client features:

```tsx
// Legitimate 'use client' — has onClick handler and useState
'use client';
import { useState } from 'react';

function ExpandableSection({ title, children }: { title: string; children: React.ReactNode }) {
  const [isExpanded, setIsExpanded] = useState(false);

  return (
    <div>
      <button onClick={() => setIsExpanded(!isExpanded)} aria-expanded={isExpanded}>
        {title}
      </button>
      {isExpanded && <div>{children}</div>}
    </div>
  );
}
```

Push the client boundary down: keep the parent as a server component and make only the interactive leaf a client component.

```tsx
// Server parent, client leaf
function ProductPage({ product }: { product: Product }) {
  return (
    <div>
      <ProductHeader product={product} />          {/* Server — static */}
      <ProductGallery images={product.images} />   {/* Server — static */}
      <AddToCartButton productId={product.id} />    {/* Client — has onClick */}
    </div>
  );
}
```

### Step-by-step fix

1. List all files with `'use client'` directive
2. For each file, check if it uses client-only features: event handlers, hooks, browser APIs
3. Remove `'use client'` from files that do not need it
4. For files that need `'use client'`, check if the client boundary can be pushed further down — extract the interactive part into a separate client component and keep the parent as a server component
5. Verify the app still works after removing unnecessary directives (hydration should succeed)

---

## 6. Hardcoded theme values

### Root cause analysis

Developers copy colors and spacing from design specs as literal Tailwind utility values (`bg-blue-500`, `text-gray-700`) because the design system tokens are not set up yet, or they are unfamiliar with Tailwind v4 `@theme` syntax. Hardcoded values drift from the design system over time — one component uses `blue-500` while another uses `blue-600` for the same semantic concept (primary color).

**Why this happens**: In Tailwind v3, the color palette was predefined (blue-100 through blue-900). Developers learned to pick a shade from this palette. Tailwind v4 shifts to `@theme` tokens with OKLCH colors and semantic naming. Developers who have not adopted the v4 token system continue using the old palette-style approach.

### Before

```tsx
function CallToAction() {
  return (
    <div className="bg-blue-500 text-white p-4 rounded-lg">
      {/* Hardcoded: blue-500 is the "primary" color, white is the "on-primary" text */}
      <h2 className="text-2xl font-bold">Sign up now</h2>
      <p className="text-sm text-gray-200 mt-2">Get started in minutes</p>
      <button className="bg-blue-700 hover:bg-blue-800 text-white px-6 py-2 rounded-md mt-4">
        Create account
      </button>
    </div>
  );
}
```

Problems: changing the primary color requires updating every component individually; color values have no semantic meaning; inconsistent shades accumulate over time.

### After

```tsx
// globals.css — define tokens
@import "tailwindcss";

@theme {
  --color-primary: oklch(0.55 0.18 250);
  --color-primary-hover: oklch(0.48 0.18 250);
  --color-on-primary: oklch(1.0 0 0);
  --color-text-secondary: oklch(0.75 0.02 250);
  --spacing-4: 1rem;
  --spacing-6: 1.5rem;
  --spacing-2: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-md: 0.5rem;
}

// Component — uses tokens
function CallToAction() {
  return (
    <div className="bg-[--color-primary] text-[--color-on-primary] p-[--spacing-4] rounded-[--radius-lg]">
      <h2 className="text-[--font-size-heading-2] font-[--font-weight-heading]">Sign up now</h2>
      <p className="text-[--font-size-body] text-[--color-text-secondary] mt-[--spacing-2]">Get started in minutes</p>
      <button className="bg-[--color-primary-hover] hover:bg-[--color-primary-hover] text-[--color-on-primary] px-[--spacing-6] py-[--spacing-2] rounded-[--radius-md] mt-[--spacing-4]">
        Create account
      </button>
    </div>
  );
}
```

Changing the primary color now requires updating one token, not dozens of components.

### Step-by-step fix

1. Identify all hardcoded utility classes in the codebase: `bg-blue-*`, `text-gray-*`, `p-[Npx]`, `mt-[Npx]`
2. Map each hardcoded value to a semantic concept (primary color, secondary text, default spacing)
3. Define semantic tokens in `globals.css` `@theme` block
4. Replace hardcoded classes with token references: `bg-blue-500` → `bg-[--color-primary]`
5. Verify visual fidelity: token values should match the original hardcoded values
6. Delete any unused hardcoded values from the `@theme` block

---

## 7. Prop drilling

### Root cause analysis

Developers pass data through intermediate components because adding context or restructuring feels like over-engineering for a "simple" data flow. Each new feature adds another prop to the chain, and the drilling grows organically. By the time it exceeds 2 levels, the refactoring cost is high enough that developers tolerate it rather than fix it.

**Why this happens**: The initial implementation is genuinely simple — just pass a prop down. The drilling grows incrementally as requirements change. Developers do not notice the threshold (2 levels) because each addition is small. Context feels heavy for a single prop, and restructuring the component tree feels like a bigger change than adding one more prop.

### Before

```tsx
function App() {
  const [theme, setTheme] = useState('light');
  return <Layout theme={theme} setTheme={setTheme} />;
}

function Layout({ theme, setTheme }) {
  // Layout does not use theme or setTheme
  return (
    <div>
      <Header theme={theme} setTheme={setTheme} />
      <Main />
    </div>
  );
}

function Header({ theme, setTheme }) {
  // Header does not use theme or setTheme
  return (
    <nav>
      <Logo />
      <ThemeToggle theme={theme} onToggle={() => setTheme(theme === 'light' ? 'dark' : 'light')} />
    </nav>
  );
}

function ThemeToggle({ theme, onToggle }) {
  // ThemeToggle actually uses both
  return <button onClick={onToggle}>{theme === 'light' ? 'Dark mode' : 'Light mode'}</button>;
}
```

Three intermediate levels (App → Layout → Header → ThemeToggle) pass props they do not use.

### After — Option A: Context

```tsx
const ThemeContext = createContext<{
  theme: string;
  toggleTheme: () => void;
}>(null);

function App() {
  const [theme, setTheme] = useState('light');
  return (
    <ThemeContext.Provider value={{
      theme,
      toggleTheme: () => setTheme(theme === 'light' ? 'dark' : 'light'),
    }}>
      <Layout />
    </ThemeContext.Provider>
  );
}

function Layout() {
  return <div><Header /><Main /></div>;
}

function Header() {
  return <nav><Logo /><ThemeToggle /></nav>;
}

function ThemeToggle() {
  const { theme, toggleTheme } = useContext(ThemeContext);
  return <button onClick={toggleTheme}>{theme === 'light' ? 'Dark mode' : 'Light mode'}</button>;
}
```

### After — Option B: Composition (children)

```tsx
function App() {
  const [theme, setTheme] = useState('light');
  return (
    <Layout>
      <Header>
        <Logo />
        <ThemeToggle theme={theme} onToggle={() => setTheme(theme === 'light' ? 'dark' : 'light')} />
      </Header>
      <Main />
    </Layout>
  );
}

function Layout({ children }) {
  return <div>{children}</div>;
}

function Header({ children }) {
  return <nav>{children}</nav>;
}
```

### Step-by-step fix

1. Trace the prop chain from origin to consumer. Count intermediate components that forward without using
2. If drilling exceeds 2 levels, choose a fix strategy:
   - **Context**: Create a context at the origin level, consumer reads directly
   - **Composition**: Pass the consumer as `children` through intermediates, skip forwarding props
   - **Lift**: Move state to the consumer's parent, pass callbacks instead of state
3. Remove the forwarded props from all intermediate components
4. Verify that the consumer still receives the data it needs
5. Keep the context API small and well-defined — do not expose the full state slice; expose specific getters and setters

---

## 8. Inline styles

### Root cause analysis

Developers use `style={{ }}` for values that do not map to existing Tailwind utilities, or when prototyping quickly. Inline styles bypass the design system, create inconsistency, and make it harder to change values globally. The pattern starts as a shortcut and becomes entrenched because refactoring inline styles to tokens feels tedious.

**Why this happens**: Tailwind's predefined utilities do not cover every value. When a developer needs a specific color, shadow, or spacing that is not in the palette, writing `style={{ backgroundColor: '#3366CC' }}` is faster than adding a new `@theme` token. But each inline style is a one-off decision that drifts from the system.

### Before

```tsx
function StatusBadge({ status }: { status: string }) {
  const colorMap = {
    active: '#22c55e',
    pending: '#f59e0b',
    error: '#ef4444',
  };

  return (
    <span
      style={{
        backgroundColor: colorMap[status],
        color: '#ffffff',
        padding: '4px 12px',
        borderRadius: '8px',
        fontSize: '0.75rem',
        fontWeight: 600,
      }}
    >
      {status}
    </span>
  );
}
```

### After

```tsx
// globals.css — add semantic tokens for status colors
@theme {
  --color-status-active: oklch(0.55 0.17 145);
  --color-status-pending: oklch(0.75 0.15 80);
  --color-status-error: oklch(0.55 0.22 25);
  --color-on-status: oklch(1.0 0 0);
}

// Component — use Tailwind with token references
function StatusBadge({ status }: { status: string }) {
  const variantClass = {
    active: 'bg-[--color-status-active]',
    pending: 'bg-[--color-status-pending]',
    error: 'bg-[--color-status-error]',
  };

  return (
    <span className={`${variantClass[status]} text-[--color-on-status] px-[--spacing-3] py-[--spacing-1] rounded-[--radius-lg] text-[--font-size-caption] font-[--font-weight-heading]`}>
      {status}
    </span>
  );
}
```

For truly one-off values that will not be reused, use Tailwind arbitrary properties instead of inline styles:

```tsx
// Better than inline style, still tracked by Tailwind
<div className="[background-color:oklch(0.55_0.18_250)]">
```

### Step-by-step fix

1. Find all `style={{ }}` usage in the codebase
2. For each inline style, determine if the value should be a reusable token (used in multiple places) or a one-off
3. For reusable values: add a token to `@theme` in `globals.css`, reference it with `bg-[--token-name]`
4. For one-off values: replace `style={{ }}` with Tailwind arbitrary properties `[property:value]`
5. Delete all `style={{ }}` usage
6. Verify visual fidelity matches the original inline style values

---

## 9. Missing Zod validation

### Root cause analysis

Developers skip runtime validation on form inputs and API responses because TypeScript provides static type checking. They trust that the types they defined match the actual data shape. But TypeScript types exist only at compile time — at runtime, data from user input or external APIs can have any shape. Without runtime validation, malformed data passes through the application silently, causing runtime errors in unrelated components.

**Why this happens**: TypeScript's type system is powerful enough that developers feel "covered" by it. The compiler guarantees that the code uses data according to the type definition. But the compiler cannot guarantee that external data conforms to the type definition. This gap is invisible in development because test data is usually well-formed.

### Before

```tsx
'use client';
import { useState } from 'react';

// No validation — trust that the API returns the expected shape
interface User {
  id: string;
  name: string;
  email: string;
}

async function createUser(formData: FormData): Promise<User> {
  const response = await fetch('/api/users', {
    method: 'POST',
    body: JSON.stringify({
      name: formData.get('name'),
      email: formData.get('email'),
    }),
  });
  return response.json() as User; // Cast — no runtime validation
}
```

Problems: `formData.get('name')` could be null; the API response could have a different shape; the `as User` cast lies to TypeScript without verifying at runtime.

### After

```tsx
'use client';
import { useState } from 'react';
import { z } from 'zod';

// Define schema at the boundary — form input
const createUserSchema = z.object({
  name: z.string().min(1, 'Name is required').max(100),
  email: z.string().email('Invalid email format'),
});

// Define schema at the boundary — API response
const userResponseSchema = z.object({
  id: z.string().uuid(),
  name: z.string(),
  email: z.string().email(),
});

// Derive TypeScript type from Zod schema
type User = z.infer<typeof userResponseSchema>;

async function createUser(formData: FormData): Promise<User> {
  // Validate form input before sending
  const input = createUserSchema.parse({
    name: formData.get('name'),
    email: formData.get('email'),
  });

  const response = await fetch('/api/users', {
    method: 'POST',
    body: JSON.stringify(input),
  });

  // Validate API response before using
  return userResponseSchema.parse(await response.json());
}
```

### Step-by-step fix

1. Identify all data boundaries in the component: form inputs, API responses, URL parameters, cookie values
2. For each boundary, define a Zod schema that describes the expected data shape
3. Add `.parse()` calls at each boundary to validate data before it enters the app
4. Derive TypeScript types from Zod schemas with `z.infer<typeof schema>` instead of defining them manually
5. Remove any `as Type` casts that were bypassing runtime validation
6. Add error handling for validation failures (ZodError) at each boundary

---

## 10. Missing error boundary

### Root cause analysis

Developers skip `error.tsx` because they handle errors within components using try/catch or conditional rendering. But runtime errors from failed renders (type errors, undefined property access, null references) crash the entire page without a boundary. The user sees a blank screen or a React error overlay in development, and a broken page in production.

**Why this happens**: Component-level error handling feels sufficient during development because most errors are caught by try/catch in async operations. Render errors are less common and harder to anticipate. Developers do not add `error.tsx` until they encounter a production crash that could have been contained.

### Before

```tsx
// app/settings/page.tsx — no error.tsx
async function SettingsPage() {
  // If this throws (database timeout, malformed data), the entire page crashes
  const settings = await fetchSettings();
  return <SettingsForm settings={settings} />;
}
```

### After

```tsx
// app/settings/error.tsx
'use client';
export default function SettingsError({ error, reset }: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  return (
    <div className="flex flex-col items-center gap-[--spacing-4] p-[--spacing-8]">
      <h2 className="text-[--font-size-heading-2] text-[--color-error]">Something went wrong</h2>
      <p className="text-[--font-size-body] text-[--color-text-secondary]">{error.message}</p>
      <button
        onClick={reset}
        className="bg-[--color-primary] text-[--color-on-primary] px-[--spacing-4] py-[--spacing-2] rounded-[--radius-md]"
      >
        Try again
      </button>
    </div>
  );
}

// app/settings/page.tsx — unchanged, error.tsx catches render failures
async function SettingsPage() {
  const settings = await fetchSettings();
  return <SettingsForm settings={settings} />;
}
```

### Step-by-step fix

1. List all route segments in the app (`app/*/page.tsx`, `app/*/*/page.tsx`)
2. Add `error.tsx` alongside every `page.tsx` that performs async operations or renders dynamic data
3. The `error.tsx` component must be a client component (`'use client'`) because it uses the `reset` callback
4. Include a `reset` button that calls `reset()` to re-attempt the render
5. Display a clear error message from `error.message`
6. For nested route segments, add `error.tsx` at each level — errors are caught at the nearest boundary

---

## 11. Untyped fetch responses

### Root cause analysis

Developers call `fetch()` and cast the response with `as SomeType` or annotate the generic type, trusting that the API returns the expected shape. This provides no runtime verification. If the API returns a different structure (missing fields, wrong types, extra fields), the cast hides the mismatch and the malformed data flows through the app causing errors in unrelated places.

**Why this happens**: The `as Type` cast feels like type safety because the compiler accepts it. But casts override the type system without verifying the data. The developer sees no type error, assumes the data is correct, and moves on. The mismatch is discovered only when a runtime error occurs downstream, far from the fetch call.

### Before

```tsx
async function getProducts(): Promise<Product[]> {
  const response = await fetch('/api/products');
  // Cast — no runtime validation, any shape passes
  return response.json() as Product[];
}

// Consumer trusts the type
function ProductList() {
  const products = await getProducts();
  // If API returns { data: [...], meta: {... } } instead of [...],
  // products is actually an object, not an array.
  // .map() throws at runtime, but TypeScript thinks it is fine.
  return products.map(p => <ProductCard key={p.id} product={p} />);
}
```

### After

```tsx
import { z } from 'zod';

// Schema validates the actual API response shape
const productArraySchema = z.array(z.object({
  id: z.string(),
  name: z.string(),
  price: z.number(),
  inStock: z.boolean(),
}));

type Product = z.infer<typeof productArraySchema>;

// Result type forces error handling at the call site
type Result<T, E = Error> =
  | { ok: true; value: T }
  | { ok: false; error: E };

async function getProducts(): Promise<Result<Product[]>> {
  try {
    const response = await fetch('/api/products');
    if (!response.ok) {
      return { ok: false, error: new Error(`HTTP ${response.status}`) };
    }
    const raw = await response.json();
    const parsed = productArraySchema.parse(raw); // Runtime validation
    return { ok: true, value: parsed };
  } catch (err) {
    return { ok: false, error: err as Error };
  }
}

// Consumer must handle both outcomes
async function ProductList() {
  const result = await getProducts();
  if (!result.ok) {
    return <ErrorMessage error={result.error} />;
  }
  const products = result.value; // TypeScript guarantees this is Product[]
  return products.map(p => <ProductCard key={p.id} product={p} />);
}
```

### Step-by-step fix

1. Identify all `fetch()` calls that cast responses with `as Type` or use generic type annotations
2. Define a Zod schema for each API response shape (matching the actual response, not the desired shape)
3. Replace the cast with `schema.parse(await response.json())`
4. Wrap the fetch function to return `Result<T, E>` instead of `Promise<T>`
5. Update all consumers to handle both `ok` and `error` outcomes
6. Derive TypeScript types from Zod schemas with `z.infer<typeof schema>`
7. Remove all `as Type` casts on fetch responses

---

## 12. Missing accessibility

### Root cause analysis

Developers focus on visual design and functionality first, treating accessibility as a compliance step added at the end. By the time they "add accessibility," the component architecture is locked in — adding keyboard handlers to a mouse-only dropdown or ARIA labels to a div-based button requires significant restructuring. The cost of retrofitting is higher than building accessibility in from the start.

**Why this happens**: Visual design is visible and testable immediately. Accessibility is invisible to developers who do not use assistive technologies. Testing accessibility requires different tools (screen readers, keyboard-only navigation) that most developers do not use daily. The delay creates a gap where accessibility is "known important" but "practically deferred."

### Before

```tsx
'use client';
function DropdownMenu({ items }: { items: MenuItem[] }) {
  const [isOpen, setIsOpen] = useState(false);

  return (
    <div>
      {/* No aria-expanded, no aria-haspopup, no keyboard handlers */}
      <div onClick={() => setIsOpen(!isOpen)}>
        Menu
      </div>
      {isOpen && (
        <div>
          {items.map(item => (
            <div onClick={() => { item.action(); setIsOpen(false); }}>
              {item.label}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
```

Problems: div has no semantic role; no keyboard navigation (Enter/Space to open, Escape to close, Arrow keys to navigate items); no ARIA attributes; screen readers cannot identify this as a menu.

### After

```tsx
'use client';
import { useState, useRef, useEffect } from 'react';

function DropdownMenu({ items }: { items: MenuItem[] }) {
  const [isOpen, setIsOpen] = useState(false);
  const [activeIndex, setActiveIndex] = useState(-1);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const menuRef = useRef<HTMLDivElement>(null);

  // Focus management: trap focus in menu when open
  useEffect(() => {
    if (isOpen && menuRef.current) {
      menuRef.current.focus();
    }
  }, [isOpen]);

  function handleKeyDown(e: React.KeyboardEvent) {
    switch (e.key) {
      case 'Enter':
      case ' ':
        e.preventDefault();
        setIsOpen(!isOpen);
        break;
      case 'Escape':
        setIsOpen(false);
        triggerRef.current?.focus(); // Return focus to trigger
        break;
      case 'ArrowDown':
        e.preventDefault();
        setActiveIndex(prev => Math.min(prev + 1, items.length - 1));
        break;
      case 'ArrowUp':
        e.preventDefault();
        setActiveIndex(prev => Math.max(prev - 1, 0));
        break;
    }
  }

  return (
    <div onKeyDown={handleKeyDown}>
      <button
        ref={triggerRef}
        onClick={() => setIsOpen(!isOpen)}
        aria-expanded={isOpen}
        aria-haspopup="menu"
        aria-label="Menu"
      >
        Menu
      </button>
      {isOpen && (
        <div
          ref={menuRef}
          role="menu"
          tabIndex={-1}
          aria-label="Menu options"
        >
          {items.map((item, index) => (
            <div
              key={item.id}
              role="menuitem"
              tabIndex={activeIndex === index ? 0 : -1}
              onClick={() => { item.action(); setIsOpen(false); triggerRef.current?.focus(); }}
              aria-label={item.label}
            >
              {item.label}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
```

### Step-by-step fix

1. For every interactive element, verify it uses a semantic HTML element (`<button>`, `<a>`, `<input>`) or has a `role` attribute
2. Add `aria-label` to elements whose visual label is insufficient (icon-only buttons, custom widgets)
3. Add keyboard handlers: Enter/Space for activation, Escape for dismissal, Arrow keys for navigation within lists
4. Manage focus: trap in modals/dialogs, return focus to trigger when closing, maintain visible focus indicator
5. Add `aria-expanded`, `aria-haspopup`, `aria-selected` for interactive state indicators
6. Test with keyboard-only navigation: every feature must be accessible without a mouse
7. Test with a screen reader (VoiceOver, NVDA) to verify ARIA attributes are announced correctly
8. Use semantic HTML first; add ARIA only when HTML semantics are insufficient