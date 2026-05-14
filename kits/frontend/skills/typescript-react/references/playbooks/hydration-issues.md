# Hydration Issues Playbook

SSR/CSR mismatch decision tree with detection patterns, code examples, and fixes for each cause.

## Decision Tree

```
START: You see a hydration mismatch warning
  "Text content did not match. Server: 'X' Client: 'Y'"
  or "Hydration failed because the initial UI does not match"
  |
  v
[Step 1] IS IT DATE/TIME RENDERING?
  Server and client render at different times → different timestamps
  |
  YES → Cause 1: Date/Time Mismatch
  |     Detection: time-dependent text in render output
  |     Fix: compute client-only, pass a deterministic server value, or narrowly suppress if unavoidable
  |
  NO → continue
  |
  v
[Step 2] BROWSER-ONLY APIs? (window, document, navigator, localStorage, matchMedia)
  These are undefined on the server
  |
  YES → Cause 2: Browser API Access During Render
  |     Detection: ReferenceError or undefined check on server
  |     Fix: useEffect or dynamic import with ssr:false
  |
  NO → continue
  |
  v
[Step 3] CONDITIONAL RENDERING BASED ON CLIENT STATE?
  useState/useReducer with different initial values on server vs client
  Auth session, localStorage values, cookies visible only on client
  |
  YES → Cause 3: Client-Only Conditional Rendering
  |     Detection: component renders differently based on state that differs SSR vs CSR
  |     Fix: useEffect client flag; use suppressHydrationWarning only as a narrow escape hatch
  |
  NO → continue
  |
  v
[Step 4] THIRD-PARTY SCRIPT MODIFICATIONS?
  Analytics, ads, browser extensions inject DOM before hydration
  |
  YES → Cause 4: Third-Party Script DOM Mutation
  |     Detection: unexpected DOM elements visible before React mounts
  |     Fix: next/script with strategy="afterInteractive"
  |
  NO → continue
  |
  v
[Step 5] CSS-IN-JS PRODUCING DIFFERENT CLASS NAMES?
  Styled-components, Emotion generating different hashes server vs client
  |
  YES → Cause 5: CSS-in-JS Class Name Mismatch
  |     Detection: different class attribute values in server HTML vs client
  |     Fix: Use CSS Modules or Tailwind (our stack uses Tailwind — this shouldn't happen)
  |
  NO → continue
  |
  v
[Step 6] RANDOM VALUES / Math.random() / UUID IN RENDER?
  Different random values generated on server vs client
  |
  YES → Cause 6: Random Value Mismatch
  |     Detection: unique IDs or random content in server output
  |     Fix: Generate random values in useEffect, not during render
  |
  NO → continue
  |
  v
[Step 7] RE-READ THE ERROR MESSAGE
  - Check the exact element and text that differs
  - Use binary search: comment out half the component, see if warning disappears
  - Check React DevTools Profiler Hydration section
```

## Cause 1: Date/Time Mismatch

Server and client render at different times, producing different date/time strings.

### Detection pattern

Look for `new Date()` or `Date.now()` in component render body (not inside useEffect).

### Code example showing the mismatch

```tsx
// MISMATCH: server renders time at build/request time, client at hydration time
function Clock() {
  const now = new Date();
  return <span>{now.toLocaleTimeString()}</span>;
  // Server: "10:30:00 AM" — Client: "10:30:01 AM" (1 second later)
  // React warns: Text content did not match. Server: "10:30:00 AM" Client: "10:30:01 AM"
}
```

### Fix

```tsx
// FIX 1: Render placeholder on server, real time on client
function Clock() {
  const [time, setTime] = useState<string | null>(null);

  useEffect(() => {
    setTime(new Date().toLocaleTimeString());
    const interval = setInterval(() => setTime(new Date().toLocaleTimeString()), 1000);
    return () => clearInterval(interval);
  }, []);

  if (!time) return <span className="text-gray-400">--:--:--</span>; // server placeholder
  return <span>{time}</span>;
}

// ESCAPE HATCH: suppressHydrationWarning on the specific element (when minor mismatch is unavoidable)
function LastUpdated({ date }: { date: string }) {
  return (
    <time suppressHydrationWarning dateTime={date}>
      {new Date(date).toLocaleDateString()}
    </time>
  );
}
```

## Cause 2: Browser API Access During Render

`window`, `document`, `navigator`, `localStorage`, `matchMedia` are undefined on the server.

### Detection pattern

Look for direct `window`/`document`/`navigator`/`localStorage` access outside of useEffect or event handlers.

### Code example showing the mismatch

```tsx
// MISMATCH: window is undefined on server, defined on client
function ThemeToggle() {
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  // Server: ReferenceError or TypeError — window is undefined
  // If you guard with typeof window !== 'undefined':
  // Server renders "Light Mode", client renders "Dark Mode" → mismatch
  return <button>{prefersDark ? 'Light Mode' : 'Dark Mode'}</button>;
}
```

### Fix

```tsx
// FIX 1: useEffect for client-only detection
function ThemeToggle() {
  const [prefersDark, setPrefersDark] = useState(false); // safe default for server

  useEffect(() => {
    setPrefersDark(window.matchMedia('(prefers-color-scheme: dark)').matches);
  }, []);

  return <button>{prefersDark ? 'Light Mode' : 'Dark Mode'}</button>;
}

// FIX 2: Dynamic import for entirely client-only components
import dynamic from 'next/dynamic';

const Map = dynamic(() => import('./Map'), { ssr: false });

function Page() {
  return (
    <div>
      <h1>Our Location</h1>
      <Map /> {/* never rendered on server — no mismatch possible */}
    </div>
  );
}
```

## Cause 3: Client-Only Conditional Rendering

Components render differently based on state that only exists on the client (auth session, localStorage, cookies).

### Detection pattern

Look for conditional rendering based on `useAuth()`, `localStorage.getItem()`, `cookies()`, or any state initialized differently on server vs client.

### Code example showing the mismatch

```tsx
// MISMATCH: auth state differs — null on server, user on client
function UserMenu() {
  const { user } = useAuth(); // null on server (no cookie sent), user on client
  if (user) return <UserAvatar user={user} />;
  return <LoginButton />;
  // Server renders LoginButton, client renders UserAvatar → mismatch
}
```

### Fix

```tsx
// FIX 1: Loading state pattern — same output on server and client initially
function UserMenu() {
  const { user, isLoading } = useAuth();
  if (isLoading) return <MenuSkeleton />; // same on server and client
  if (user) return <UserAvatar user={user} />;
  return <LoginButton />;
}

// ESCAPE HATCH: suppressHydrationWarning for intentional, unavoidable mismatches
function UserMenu() {
  const { user } = useAuth();
  return (
    <div suppressHydrationWarning>
      {user ? <UserAvatar user={user} /> : <LoginButton />}
    </div>
  );
}
// Use suppressHydrationWarning only on the specific element that mismatches, not the whole page
```

## Cause 4: Third-Party Script DOM Mutation

Scripts that modify the DOM before React hydrates cause mismatches because React expects the DOM to match its render output.

### Detection pattern

Look for `<script>` tags in the HTML that modify DOM structure (injecting elements, changing attributes).

### Code example showing the mismatch

```html
<!-- MISMATCH: analytics script injects a cookie banner before React hydrates -->
<script>
  // Injects <div class="cookie-banner">...</div> into the body
  analytics.init();
</script>
<!-- React tries to hydrate but finds unexpected DOM elements -->
```

### Fix

```tsx
// FIX: Use next/script with afterInteractive strategy
import Script from 'next/script';

function Page() {
  return (
    <>
      <MainContent />
      <Script src="/analytics.js" strategy="afterInteractive" />
    </>
  );
}

// Strategy options:
// beforeInteractive — loaded before page is interactive (critical scripts)
// afterInteractive — loaded immediately after hydration (analytics, tags) ← most common
// lazyOnload — loaded during idle time (low priority scripts)
```

## Cause 5: CSS-in-JS Class Name Mismatch

CSS-in-JS libraries may generate different class names on the server vs client (different hash algorithms, different order).

### Detection pattern

Check the `class` attribute on mismatched elements. If server HTML has `class="sc-abc123"` but client generates `class="sc-def456"`.

### Code example showing the mismatch

```tsx
// MISMATCH: styled-components generates different hashes SSR vs CSR
const Button = styled.button`
  background: blue;
  color: white;
`;
// Server: class="sc-a1b2c3" — Client: class="sc-d4e5f6"
```

### Fix

Since our stack uses Tailwind v4, this cause should not occur. If you encounter it in a migration:

```tsx
// FIX 1: Use Tailwind classes instead of CSS-in-JS (our standard)
<button className="bg-blue-500 text-white px-4 py-2 rounded-md">Click</button>

// FIX 2: If you must use CSS-in-JS, configure SSR extraction
// styled-components: enable ServerStyleSheet rendering
// Emotion: enable extractCritical CSS extraction
```

## Cause 6: Random Value Mismatch

`Math.random()`, `crypto.randomUUID()`, or any random value generator produces different values on server and client.

### Detection pattern

Look for `Math.random()`, `uuid()`, `nanoid()`, or any call that produces non-deterministic values during render (not inside useEffect).

### Code example showing the mismatch

```tsx
// MISMATCH: random ID differs on server vs client
function ListItem() {
  const id = Math.random().toString(36); // different value each render
  return <div id={id}>Item</div>;
  // Server: id="x7k9m2" — Client: id="p3j5n8" → mismatch
}
```

### Fix

```tsx
// FIX 1: Generate random values in useEffect only
function ListItem() {
  const [id, setId] = useState('list-item-ssr'); // deterministic for SSR
  useEffect(() => {
    setId(`list-item-${Math.random().toString(36)}`);
  }, []);
  return <div id={id}>Item</div>;
}

// FIX 2: Use useId() for unique IDs (React 18+ built-in)
function ListItem() {
  const id = useId(); // deterministic — same on server and client
  return <div id={id}>Item</div>;
}
```

## Debugging Techniques

### Binary search for the mismatch element

Comment out half the component. If the warning disappears, the mismatch is in the commented half. Narrow down until you find the exact element.

```tsx
function Page() {
  return (
    <div>
      <Header />        {/* comment this out — warning gone? then mismatch is here */}
      <MainContent />   {/* then try this */}
      <Footer />        {/* and this */}
    </div>
  );
}
```

### React DevTools Profiler

Open DevTools, select the Profiler tab, record a hydration. The "Hydration" section shows which components had mismatches.

### Error message analysis

The hydration warning includes the exact element path:

```
Text content did not match. Server: "10:30 AM" Client: "10:31 AM"
  at span
  at Clock
  at div
```

Start from the innermost element (span in Clock) and trace upward.

### Node.js SSR debugging

For server-side debugging, add a temporary log in your server component:

```tsx
// Temporary debug log — remove after fixing
export default async function Page() {
  console.log('Server rendering:', typeof window); // should be undefined
  return <ClientComponent />;
}
```

## Quick Reference Table

| Cause | Detection | Fix |
|---|---|---|
| Date/time mismatch | `new Date()` in render body | useEffect for client-only time, deterministic server value, or narrow suppression |
| Browser API access | `window`/`document` outside useEffect | useEffect, or dynamic import with ssr:false |
| Client-only conditional | Different state on server vs client | Loading state pattern; suppress only unavoidable mismatches |
| Third-party script | DOM modified before hydration | next/script with strategy="afterInteractive" |
| CSS-in-JS mismatch | Different class names SSR vs CSR | Use Tailwind (our standard), configure SSR extraction |
| Random value mismatch | `Math.random()` or `uuid()` in render | useEffect, or React.useId() |
