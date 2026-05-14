# Review Heuristics

Full risk-vs-preference framework with examples, architecture smell catalog with detection patterns, and review comment templates for frontend code review.

## Risk vs Preference Framework

Every review finding must be classified before writing a comment. Misclassifying a risk as preference lets defects through; misclassifying a preference as risk creates unnecessary friction.

### Classification decision flowchart

```
Finding discovered
  -> Can this cause a user-facing defect?
     -> Yes: Can it cause data loss, security breach, accessibility violation, or performance degradation?
        -> Yes: RISK (must fix, blocks merge)
        -> No: RISK (must fix, but lower urgency)
     -> No: Does it violate an agreed team standard?
        -> Yes: PREFERENCE (discuss, align with standard)
        -> No: PREFERENCE (discuss, author decides)
```

### Risk category details with examples

#### Security vulnerability

Defects that allow attackers to exploit the application or expose sensitive data.

| Pattern | Example | Impact |
|---|---|---|
| XSS via unescaped input | Rendering `{userInput}` in a context that interprets HTML | Script injection, cookie theft |
| Exposed secrets in client bundles | `const API_KEY = "sk-..."` in a `'use client'` component | Key stolen from bundle, unauthorized API access |
| Missing CSRF on state-mutating requests | POST form without CSRF token | Cross-site request forgery |
| Client-side auth token storage | `localStorage.setItem('token', jwt)` | Token accessible to any script on the page |

#### Data loss potential

Defects that can cause users to lose data they entered or created.

| Pattern | Example | Impact |
|---|---|---|
| Unvalidated form submissions | Form data sent to API without Zod validation | Invalid data persisted, corrupts state |
| Optimistic updates without rollback | UI updates before API confirms, no error rollback | User sees changes that did not persist |
| Missing error handling on mutations | `await fetch(...)` without try/catch or error state | Silent failure, user unaware their action failed |
| Race conditions on concurrent updates | Two tabs editing the same resource without conflict detection | Last-write-wins, earlier changes lost |

#### Performance bottleneck

Defects that degrade application performance for end users.

| Pattern | Example | Impact |
|---|---|---|
| Unbounded client-side fetching | `useEffect` that fetches on every render without deduplication | Duplicate requests, wasted bandwidth |
| Missing Suspense boundaries | Async server component without `loading.tsx` | Whole page blocks until all data loads |
| Large client bundles | Entire page marked `'use client'` | Increased JS payload, slower TTI |
| Unnecessary re-renders from state misuse | Storing server data in `useState` triggers re-fetch cascades | Network congestion, UI jank |

#### Accessibility violation

Defects that prevent users with disabilities from using the application.

| Pattern | Example | Impact |
|---|---|---|
| Missing accessible names on icon-only/custom controls | Icon button with no `aria-label` | Screen reader users cannot identify the button's purpose |
| No keyboard navigation | Custom dropdown that requires mouse to operate | Keyboard-only users cannot access the feature |
| Focus trap absent in modals | Modal opens but focus escapes to background | Screen reader users lose context |
| Color-only indicators | Error state shown only with red border | Color-blind users miss the error |

#### Hydration mismatch risk

Defects that cause React to warn about server/client content divergence or crash during hydration.

| Pattern | Example | Impact |
|---|---|---|
| Server/client content divergence | `new Date()` rendered in server component, differs on client | React hydration warning, potential crash |
| Random values in server components | `Math.random()` in server component | Mismatch on every hydration |
| Browser-only APIs in server components | `window.innerWidth` in server component | Undefined on server, mismatch on client |

### Preference category details with examples

#### Naming convention

Style choices that affect readability but cannot cause defects.

```tsx
// Preference: variable naming style
const isExpanded = false;   // Team prefers isX for booleans
const hasPermission = true; // hasX for possession checks
const shouldRender = true;  // shouldX for conditional logic

// Preference: function naming style
async function fetchUser() { }  // fetchX for async data access
async function createUser() { } // createX for mutations
function formatDate() { }       // formatX for transformations
```

#### Component organization

Structural choices that affect navigation but not correctness.

```tsx
// Preference: grouping related components
// Option A: Flat structure
components/
  button.tsx
  button-group.tsx

// Option B: Nested structure
components/
  button/
    button.tsx
    button-group.tsx

// Both are valid; the team picks one and stays consistent
```

#### CSS class ordering

Order of Tailwind utilities within a `className` string.

```tsx
// Preference: class ordering
// Option A: Logical grouping (layout -> spacing -> visual -> responsive)
<div className="flex items-center p-4 bg-surface text-text md:flex-col md:p-6">

// Option B: Alphabetical
<div className="bg-surface flex items-center md:flex-col md:p-6 p-4 text-text">

// Neither affects functionality; the team picks one for consistency
```

#### Variable naming style

Consistency in naming patterns across the codebase.

```tsx
// Preference: boolean naming
// Team might prefer isX consistently, or distinguish isX/hasX/shouldX
const isLoading = true;
const hasError = false;

// Preference: async function naming
// Team might prefer fetchX vs getX vs loadX
async function fetchUsers() { }
```

## Architecture Smell Catalog

### Props drilling beyond 2 levels

**Detection pattern**: Trace a prop from its origin to its final consumer. Count the number of intermediate components that receive the prop but only forward it without using it.

```
ParentComponent (origin: defines state)
  -> IntermediateA (receives prop, passes down, does not use it)
    -> IntermediateB (receives prop, passes down, does not use it)
      -> LeafComponent (consumes the prop)

// Depth = 2 intermediate levels = props drilling
```

**Example**:

```tsx
// SMELL: Props drilled through 3 levels
function App() {
  const [user, setUser] = useState(null);
  return <Dashboard user={user} setUser={setUser} />;
}

function Dashboard({ user, setUser }) {
  // Dashboard does not use user or setUser directly
  return <Sidebar user={user} setUser={setUser} />;
}

function Sidebar({ user, setUser }) {
  // Sidebar does not use user or setUser directly
  return <UserPanel user={user} onLogout={() => setUser(null)} />;
}

function UserPanel({ user, onLogout }) {
  // UserPanel actually uses both
  return <div>{user.name} <button onClick={onLogout}>Logout</button></div>;
}
```

**Fix options**:
1. Lift state to `App` and pass `onLogout` callback directly (skip intermediates)
2. Use composition: `<Dashboard><Sidebar><UserPanel /></Sidebar></Dashboard>` with context
3. Create a `UserContext` with clear ownership at `App` level

### God component (100+ lines or 7+ props)

**Detection pattern**: Count lines in the component body (excluding imports and type definitions). Count props in the interface. Either threshold exceeded triggers the smell.

**Example**:

```tsx
// SMELL: God component - 150 lines, 9 props
interface DashboardProps {
  user: User;
  notifications: Notification[];
  tasks: Task[];
  settings: Settings;
  onTaskUpdate: (task: Task) => void;
  onSettingsChange: (settings: Settings) => void;
  onNotificationRead: (id: string) => void;
  isLoading: boolean;
  error: string | null;
}

function Dashboard({ user, notifications, tasks, settings, onTaskUpdate, onSettingsChange, onNotificationRead, isLoading, error }: DashboardProps) {
  // 150+ lines: renders header, sidebar, task list, notification panel, settings modal
  ...
}
```

**Fix**: Split into focused sub-components with clear responsibilities.

```tsx
// FIXED: Focused components
function Dashboard({ user }: { user: User }) {
  return (
    <div>
      <DashboardHeader user={user} />
      <DashboardSidebar />
      <main>
        <TaskList />
        <NotificationPanel />
      </main>
    </div>
  );
}
// Each sub-component handles its own data fetching and state
```

### Shared state without clear ownership

**Detection pattern**: Search for multiple components that dispatch actions to the same state slice. If no single component is the authoritative owner, the state lacks clear ownership.

**Example**:

```tsx
// SMELL: Both components dispatch to the same state
function TaskList() {
  const dispatch = useAppDispatch();
  dispatch(updateTask(task)); // TaskList updates tasks
}

function NotificationPanel() {
  const dispatch = useAppDispatch();
  dispatch(updateTask(task)); // NotificationPanel also updates tasks
}
// Who owns the task state? Neither component is the clear owner.
```

**Fix**: Designate one component as the owner. Other components request changes through a well-defined API.

```tsx
// FIXED: Dashboard owns task state, provides API via context
const TaskContext = createContext<{
  tasks: Task[];
  updateTask: (task: Task) => void;
}>(null);

function Dashboard({ user }: { user: User }) {
  const [tasks, setTasks] = useState<Task[]>([]);
  // Dashboard is the single owner of task state
  return (
    <TaskContext.Provider value={{ tasks, updateTask: setTasks }}>
      <TaskList />
      <NotificationPanel />
    </TaskContext.Provider>
  );
}
```

### Fetch in wrong boundary

**Detection pattern**: Find `useEffect` with `fetch` or `useQuery` in client components. Check if the fetched data depends on user interaction. If not, the fetch belongs in a server component.

**Example**:

```tsx
// SMELL: Client component fetching data that could be fetched on the server
'use client';
function ProductList() {
  const [products, setProducts] = useState([]);
  useEffect(() => {
    fetch('/api/products').then(r => r.json()).then(setProducts);
  }, []);
  return products.map(p => <ProductCard key={p.id} product={p} />);
}
```

**Fix**: Move to server component for static data, or use TanStack Query for interactive data.

```tsx
// FIXED: Server component fetches directly
async function ProductList() {
  const products = await db.products.findMany();
  return products.map(p => <ProductCard key={p.id} product={p} />);
}
```

### Over-abstracted hooks

**Detection pattern**: Count parameters and return values of a custom hook. If it has 5+ parameters or 4+ return values, it wraps too much logic.

**Example**:

```tsx
// SMELL: Hook with 6 parameters and 5 return values
function useDashboard(userId, projectId, filters, sort, page, pageSize) {
  return { tasks, notifications, settings, stats, isLoading, error, refetch, updateTask, markRead };
}
```

**Fix**: Split into focused hooks that each handle one concern.

```tsx
// FIXED: Focused hooks
function useTasks(projectId: string, filters: Filters) {
  return { tasks, isLoading, error, refetch, updateTask };
}

function useNotifications(userId: string) {
  return { notifications, markRead };
}

function useProjectSettings(projectId: string) {
  return { settings, updateSettings };
}
```

## Review Comment Templates

Use these templates when writing review comments. The template signals whether the finding blocks the merge or is a suggestion.

### Risk comment template

```
[RISK] <category>: <description>

<explanation of impact>

<specific fix with code example or reference>
```

Example:

```
[RISK] Security: XSS via unescaped user input

Rendering {comment.content} directly in this context allows script injection
if the comment contains HTML. A malicious user could inject a script tag that
steals session cookies.

Use a sanitization library before rendering:

import { sanitize } from 'isomorphic-dompurify';
<div>{sanitize(comment.content)}</div>
```

### Preference comment template

```
[PREFERENCE] <category>: <description>

<suggestion and reasoning>

<optional: reference to team standard>
```

Example:

```
[PREFERENCE] Naming: Boolean variable naming style

This variable is named `loading` which is ambiguous - is it a boolean or
a loading state object? The team convention uses `isX` for boolean flags.

Consider: `isLoading` to clarify it is a boolean.
```

### Architecture smell comment template

```
[SMELL] <smell name>: <description>

<explanation of why this degrades maintainability>

<fix options with brief examples>
```

Example:

```
[SMELL] Props drilling: user prop forwarded through 3 levels

Dashboard and Sidebar receive the user prop but only forward it to UserPanel.
This creates a fragile coupling - any change to the user data shape requires
updates to all intermediate components.

Fix options:
1. Lift state: App passes onLogout callback directly to UserPanel
2. Context: Create UserContext at App level, UserPanel consumes it
3. Composition: Pass UserPanel as children through intermediates
```
