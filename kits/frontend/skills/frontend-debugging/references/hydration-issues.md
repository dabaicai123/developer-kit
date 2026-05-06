# Hydration Issues

SSR/CSR mismatch diagnosis and fixes for Next.js App Router.

## What is Hyration Mismatch?

React renders the component tree on the server (SSR), then attaches event handlers on the client (hydration). If the server HTML and the initial client render produce different output, React warns:

```
Warning: Text content did not match. Server: "X" Client: "Y"
```

Or:

```
Unhandled Runtime Error: Hydration failed because the initial UI does not match what was rendered on the server.
```

## Diagnosis Decision Tree

```
START: You see a hydration mismatch warning
  |
  v
[Q1] Is date/time rendered differently on server vs client?
  |
  YES → Fix: Use useEffect to render client-side time
  |      Or: pass time from server, don't compute client time during first render
  |
  NO → continue
  |
  v
[Q2] Are you using browser-only APIs during render?
  |    (window, document, navigator, localStorage, matchMedia)
  |
  YES → Fix: Move browser API calls to useEffect
  |      Or: use dynamic import with ssr: false
  |
  NO → continue
  |
  v
[Q3] Is there conditional rendering based on client-only state?
  |    (useState/useReducer with different initial value than server)
  |
  YES → Fix: Use suppressHydrationWarning on the mismatched element
  |      Or: render placeholder on server, real content in useEffect
  |
  NO → continue
  |
  v
[Q4] Are third-party scripts modifying the DOM before hydration?
  |    (analytics, ads, browser extensions)
  |
  YES → Fix: Move script to afterHydration
  |      Or: Use next/script with strategy="afterInteractive"
  |
  NO → continue
  |
  v
[Q5] Is Zustand persist rehydration causing mismatch?
  |
  YES → Fix: Use hydration guard pattern
  |      Or: dynamic import with ssr: false
  |
  NO → continue
  |
  v
[Q6] Is there a random value (Math.random, UUID) in render?
  |
  YES → Fix: Generate random values in useEffect, not during render
  |      Or: Pass deterministic value from server
  |
  NO → Re-read the error carefully. Check the exact element mentioned.
```

## Fixes for Each Cause

### 1. Date/Time Mismatch

Server and client produce different timestamps because they run at different times.

```tsx
// PROBLEM: server renders "10:30 AM", client renders "10:31 AM"
function Clock() {
  const now = new Date(); // different on server vs client
  return <span>{now.toLocaleTimeString()}</span>;
}

// FIX 1: Render time only on client via useEffect
function Clock() {
  const [time, setTime] = useState<string | null>(null);

  useEffect(() => {
    setTime(new Date().toLocaleTimeString());
    const interval = setInterval(() => setTime(new Date().toLocaleTimeString()), 1000);
    return () => clearInterval(interval);
  }, []);

  if (!time) return <span className="text-gray-400">Loading time...</span>; // server placeholder
  return <span>{time}</span>;
}

// FIX 2: Render server time initially, update on client
function Clock({ serverTime }: { serverTime: string }) {
  const [time, setTime] = useState(serverTime); // matches server

  useEffect(() => {
    setTime(new Date().toLocaleTimeString()); // update to client time
  }, []);

  return <span>{time}</span>;
}
```

### 2. Browser-Only APIs

`window`, `document`, `navigator`, `localStorage` are undefined on the server.

```tsx
// PROBLEM: accessing window during render
function ThemeToggle() {
  const prefersDark = window.matchMedia("(prefers-color-scheme: dark)").matches; // undefined on server
  return <button>{prefersDark ? "Light Mode" : "Dark Mode"}</button>;
}

// FIX 1: useEffect for client-only detection
function ThemeToggle() {
  const [prefersDark, setPrefersDark] = useState(false); // safe default for server

  useEffect(() => {
    setPrefersDark(window.matchMedia("(prefers-color-scheme: dark)").matches);
  }, []);

  return <button>{prefersDark ? "Light Mode" : "Dark Mode"}</button>;
}

// FIX 2: Dynamic import for entirely client-only components
import dynamic from "next/dynamic";

const ClientOnlyMap = dynamic(() => import("./Map"), { ssr: false });

function Page() {
  return (
    <div>
      <h1>Our Location</h1>
      <ClientOnlyMap /> {/* never rendered on server */}
    </div>
  );
}
```

### 3. Conditional Rendering Based on Client State

Components that render differently based on client-only state (cookies, localStorage, auth session).

```tsx
// PROBLEM: auth state differs between server and client
function UserMenu() {
  const { user } = useAuth(); // null on server (no cookie), user object on client
  if (user) return <UserAvatar user={user} />;
  return <LoginButton />;
}
// Server renders LoginButton, client renders UserAvatar → mismatch

// FIX 1: suppressHydrationWarning on the specific element
function UserMenu() {
  const { user } = useAuth();
  return (
    <div suppressHydrationWarning>
      {user ? <UserAvatar user={user} /> : <LoginButton />}
    </div>
  );
}

// FIX 2: Render placeholder on server, real content after hydration
function UserMenu() {
  const { user, isLoading } = useAuth();
  if (isLoading) return <MenuSkeleton />;
  if (user) return <UserAvatar user={user} />;
  return <LoginButton />;
}
```

**When to use `suppressHydrationWarning`**: Only when the mismatch is intentional and expected (e.g., auth state, theme preference). Do not use it to hide real bugs.

### 4. Third-Party Scripts

Scripts that modify the DOM before React hydrates cause mismatches.

```tsx
// PROBLEM: analytics script injects elements before hydration
<script>
  // Adds a banner div to the page body
  analytics.init();
</script>

// FIX: Use next/script with afterInteractive strategy
import Script from "next/script";

function Page() {
  return (
    <>
      <MainContent />
      <Script src="/analytics.js" strategy="afterInteractive" />
    </>
  );
}
```

**Strategy options**:
- `beforeInteractive`: Load before page is interactive (critical scripts)
- `afterInteractive`: Load immediately after hydration (analytics, tags)
- `lazyOnload`: Load during idle time (low priority scripts)

### 5. Zustand Persist Rehydration

Zustand stores with `persist` middleware read from localStorage on mount, causing mismatch with the server's initial state.

```tsx
// PROBLEM: Zustand persist changes state after mount
const useThemeStore = create<ThemeState>()(
  persist(
    (set) => ({
      theme: "light", // server default
      setTheme: (t) => set({ theme: t }),
    }),
    { name: "theme" } // localStorage may have "dark"
  )
);

function ThemedPage() {
  const theme = useThemeStore((s) => s.theme); // "light" on server, "dark" on client
  return <div className={theme === "dark" ? "bg-gray-900" : "bg-white"}>...</div>;
}

// FIX 1: Hydration guard
function ThemedPage() {
  const [hydrated, setHydrated] = useState(false);
  useEffect(() => { setHydrated(true); }, []);

  if (!hydrated) return <PageSkeleton />; // same on server and client
  return <ThemedContent />;
}

// FIX 2: onRehydrateStorage
const useThemeStore = create<ThemeState>()(
  persist(
    (set) => ({
      theme: "light",
      _hasHydrated: false,
      setTheme: (t) => set({ theme: t }),
      setHasHydrated: (v) => set({ _hasHydrated: v }),
    }),
    {
      name: "theme",
      onRehydrateStorage: () => (state) => {
        state?.setHasHydrated(true);
      },
    }
  )
);

function ThemedPage() {
  const hydrated = useThemeStore((s) => s._hasHydrated);
  if (!hydrated) return <PageSkeleton />;
  return <ThemedContent />;
}
```

### 6. Random Values

Random values differ between server and client renders.

```tsx
// PROBLEM: UUID or random ID in render
function ListItem() {
  const id = Math.random().toString(36); // different on server vs client
  return <div id={id}>Item</div>;
}

// FIX: Generate random values in useEffect, use deterministic ID during SSR
function ListItem() {
  const [id, setId] = useState(`item-ssr`); // deterministic for SSR
  useEffect(() => {
    setId(Math.random().toString(36)); // random on client
  }, []);
  return <div id={id}>Item</div>;
}
```

## Debugging Tips

### Find the exact mismatch element

The hydration warning includes the element path. Look for the exact text that differs:

```
Text content did not match. Server: "10:30 AM" Client: "10:31 AM"
  at span
  at Clock
  at div
```

Start from the innermost element (span in Clock) and trace upward.

### Binary search for the mismatch

Comment out half the component. If the warning disappears, the mismatch is in the commented half. Repeat until you find the exact element.

```tsx
function Page() {
  return (
    <div>
      <Header />       {/* comment this out first */}
      <MainContent />  {/* then this */}
      <Footer />       {/* if warning gone, mismatch is in commented section */}
    </div>
  );
}
```

### Use React DevTools Profiler

In DevTools, check the "Hydration" section. It shows which components had mismatches.

### Check for CSS-in-JS mismatches

Some CSS-in-JS libraries generate different styles on server vs client. Ensure your SSR setup extracts CSS correctly.