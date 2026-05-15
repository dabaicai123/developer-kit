# Component Decomposition Guide

How to analyze a static prototype page and break it into a React component tree. Covers identifying visual boundaries, defining component hierarchy, props interfaces, server/client boundaries, and extracting shared patterns.

## Decomposition Process

1. **Identify visual boundaries** - find distinct sections in the prototype
2. **Define component hierarchy** - organize sections into parent-child tree
3. **Decide props interface** - determine what data flows in and out
4. **Choose server/client boundary** - mark where interactivity begins
5. **Extract shared patterns** - pull repeated structures into composition components

## Identifying Visual Boundaries

Scan the prototype for these boundary signals:

| Signal | Meaning | Example |
|---|---|---|
| Horizontal separator (border, shadow, bg change) | Distinct section | Navbar vs Hero vs Features |
| Repeated card/element structure | Reusable component | FeatureCard repeats 3x |
| Independent interactive area | Client component boundary | Search input with live results |
| Content that varies per page | Slot/props pattern | Hero text changes per page |
| Content that varies per user | Dynamic data | User name in header |

**Rule: If a section has its own background, border, or spacing rhythm, it is a component boundary.**

## Example: Decomposing a Dashboard Page

### Prototype (Stage 2 output)

A single monolithic page with: sidebar navigation, top bar with search and user avatar, metric cards grid, recent activity list, and chart section.

### Step 1: Mark Visual Boundaries

```
+------------------------------------------------------+
| SIDEBAR          | TOPBAR (search + avatar)          | -> boundary: sidebar vs main area
|                  +-----------------------------------+ -> boundary: topbar vs content
| Nav links        | METRIC CARDS (4 cards in grid)   | -> boundary: metrics grid
|                  +-----------------------------------+ -> boundary: between sections
|                  | RECENT ACTIVITY (5 items)        | -> boundary: activity list
|                  +-----------------------------------+
|                  | CHART SECTION                    | -> boundary: chart area
+------------------------------------------------------+
```

### Step 2: Define Component Hierarchy

```
DashboardPage (Server Component)
|- Sidebar (Client - has active state toggle)
|  |- SidebarBrand (Client - imported by Sidebar)
|  `- SidebarNav (Client - active link highlighting)
|      `- SidebarNavItem (Client - imported by SidebarNav)
`- MainContent (Server - layout wrapper)
   |- TopBar (Server - static search form + avatar)
   |  |- SearchInput (Client - live search interaction)
   |  `- UserAvatar (Server - displays user info)
   |- MetricsGrid (Server - maps over data)
   |  `- MetricCard (Server - receives metric data)
   |- ActivityList (Server - maps over data)
   |  `- ActivityItem (Server - receives item data)
   `- ChartSection (Client - interactive chart)
```

### Step 3: Define Props Interfaces

```tsx
// MetricCard - receives data, no interaction
interface MetricCardProps {
  title: string
  value: string
  change: string           // "+12%" or "-3%"
  changeType: "positive" | "negative"
  icon: React.ReactNode
}

// SidebarNavItem - receives active state from parent
interface SidebarNavItemProps {
  label: string
  href: string
  icon: React.ReactNode
  active?: boolean
}

// ActivityItem - receives data, links out
interface ActivityItemProps {
  user: string
  action: string
  target: string
  timestamp: string
  href: string
}

// DashboardPage - fetches data at server level
interface DashboardPageProps {
  userId: string           // used for data fetching
}
```

### Step 4: Mark Server/Client Boundaries

```
Server Components (no "use client"):
  DashboardPage, SidebarBrand, SidebarNavItem, TopBar,
  UserAvatar, MetricsGrid, MetricCard, ActivityList, ActivityItem, MainContent

Client Components ("use client"):
  Sidebar (toggles collapsed state), SidebarNav (active state management),
  SearchInput (live search, debounced input), ChartSection (interactive chart)
```

**Boundary rule:** The client boundary is at the smallest interactive unit. `Sidebar` needs state for collapsed toggle, so it is client. `SidebarNavItem` just receives `active` as a prop, so it stays server. `MetricsGrid` maps over server-fetched data, stays server.

### Step 5: Extract Shared Patterns

**MetricCard and ActivityItem share a "card" pattern:**

```tsx
// Composition component - provides card chrome, content via slot
// Server Component (no interactivity)
interface CardProps {
  children: React.ReactNode
  className?: string
}

export default function Card({ children, className }: CardProps) {
  return (
    <div className={cn(
      "bg-surface-elevated border border-border",
      "rounded-lg p-6 shadow-sm",
      className
    )}>
      {children}
    </div>
  )
}
```

Both `MetricCard` and `ActivityItem` compose with `Card` rather than repeating border/radius/shadow tokens:

```tsx
// MetricCard - composes with Card
export default function MetricCard({ title, value, change, changeType, icon }: MetricCardProps) {
  return (
    <Card>
      <div className="flex items-center gap-3">
        <div className="w-12 h-12 bg-primary-light rounded-md
          flex items-center justify-center">{icon}</div>
        <div>
          <p className="text-caption text-text-muted">{title}</p>
          <p className="text-heading-2 font-heading text-text">{value}</p>
        </div>
      </div>
      <p className={cn(
        "text-caption mt-2",
        changeType === "positive" ? "text-success" : "text-error"
      )}>{change}</p>
    </Card>
  )
}
```

## File Organization

After decomposition, organize files following Next.js App Router conventions:

```
app/
|- dashboard/
|  |- page.tsx                    # DashboardPage (Server)
|  `- layout.tsx                  # DashboardLayout - sidebar + main wrapper
`- globals.css                    # @theme tokens
components/
|- layout/
|  |- sidebar.tsx                 # Sidebar (Client)
|  |- sidebar-brand.tsx           # SidebarBrand (Client)
|  |- sidebar-nav.tsx             # SidebarNav (Client)
|  |- sidebar-nav-item.tsx        # SidebarNavItem (Client)
|  |- top-bar.tsx                 # TopBar (Server)
|  |- search-input.tsx            # SearchInput (Client)
|  `- user-avatar.tsx             # UserAvatar (Server)
|- dashboard/
|  |- metrics-grid.tsx            # MetricsGrid (Server)
|  |- metric-card.tsx             # MetricCard (Server)
|  |- activity-list.tsx           # ActivityList (Server)
|  |- activity-item.tsx           # ActivityItem (Server)
|  `- chart-section.tsx           # ChartSection (Client)
`- shared/
   |- card.tsx                    # Card composition (Server)
   `- button.tsx                  # Button variants (Server for static, Client for interactive)
```

**Naming convention:**
- File name = component name in kebab-case
- One component per file (no barrel exports)
- Group by domain (layout, dashboard, shared) - not by type (server, client)

## Server vs Client Decision Matrix

For each component, answer these questions. If any answer is "yes", the component needs `"use client"`:

| Question | Yes = Client | No = Server |
|---|---|---|
| Does it use `useState`, `useReducer`, `useEffect`? | Client | Server |
| Does it handle click/submit/change events? | Client | Server |
| Does it use browser-only APIs (`window`, `document`, `localStorage`)? | Client | Server |
| Does it use a client-only library (chart lib, animation lib)? | Client | Server |
| Does it only wrap/render children without its own interactivity? | Server | Check other rows |

**Key insight:** A Server Component can render Client Components as children. The boundary is at the component that needs interactivity, not its parent. `MetricsGrid` (server) renders `MetricCard` (server) - both server. `DashboardPage` (server) can render `Sidebar` (client), but `Sidebar` cannot import Server Components directly. The rule is:

- Server component -> can import and render server OR client components
- Client component -> can import and render client components only
- Server -> Client boundary: use `children` prop to pass server-rendered content into client wrapper

```tsx
// Sidebar.tsx - Client component
"use client"
export default function Sidebar({ children }: { children: React.ReactNode }) {
  const [collapsed, setCollapsed] = useState(false)
  return (
    <aside className={collapsed ? "w-16" : "w-60"}>
      <button onClick={() => setCollapsed(!collapsed)}>Toggle</button>
      {/* children is rendered by the server parent, passed through */}
      {children}
    </aside>
  )
}

// layout.tsx - Server component
import Sidebar from "@/components/layout/sidebar"
import SidebarNav from "@/components/layout/sidebar-nav"

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <Sidebar>
      <SidebarNav />  {/* Server-rendered, passed as children to Client Sidebar */}
    </Sidebar>
  )
}
```

## Props Design Principles

1. **Data flows down:** Props carry data from parent to child. Never pass callbacks that modify parent state through more than one level.
2. **Minimal props:** A component should receive exactly what it needs. If a card needs `title` and `value`, don't pass the entire `Metric` object.
3. **Avoid prop drilling beyond 2 levels:** If data passes through 3+ components, lift state or use context (see `state-management` skill).
4. **Use composition over props for layout:** `children` and slot props are better than `sidebarContent`, `headerContent` props.
5. **Primitive types in leaf components:** Leaf components (cards, buttons, items) receive `string`, `number`, `boolean`. Container components (grids, lists) receive structured data.

```tsx
// Leaf component - primitive props
interface MetricCardProps {
  title: string
  value: string
  change: string
  changeType: "positive" | "negative"
  icon: React.ReactNode
}

// Container component - structured data
interface MetricsGridProps {
  metrics: Array<{
    title: string
    value: string
    change: string
    changeType: "positive" | "negative"
    icon: string    // icon name, resolved in container
  }>
}
```

## Composition Patterns

### Slot Pattern - flexible layout containers

```tsx
// Server Component - no interactivity, just layout
interface PageLayoutProps {
  header: React.ReactNode
  sidebar: React.ReactNode
  children: React.ReactNode
}

export default function PageLayout({ header, sidebar, children }: PageLayoutProps) {
  return (
    <div className="flex min-h-screen">
      <aside className="w-60 border-r border-border">{sidebar}</aside>
      <div className="flex-1">
        <header className="border-b border-border">{header}</header>
        <main className="p-8">{children}</main>
      </div>
    </div>
  )
}
```

### Variant Pattern - same structure, different style

```tsx
// Button - variant determines visual style, not structure
interface ButtonProps {
  variant?: "primary" | "secondary" | "ghost"
  size?: "sm" | "md" | "lg"
  children: React.ReactNode
  onClick?: () => void
}

const variantStyles = {
  primary: "bg-primary text-surface-elevated hover:bg-primary-hover",
  secondary: "bg-surface-elevated text-primary border border-primary hover:bg-primary-light",
  ghost: "text-text hover:bg-surface-subtle",
}

const sizeStyles = {
  sm: "px-2 py-1 text-caption",
  md: "px-4 py-2 text-body",
  lg: "px-8 py-3 text-body-large",
}

export default function Button({ variant = "primary", size = "md", children, onClick }: ButtonProps) {
  return (
    <button className={cn(
      "rounded-md font-heading",
      variantStyles[variant],
      sizeStyles[size]
    )} onClick={onClick}>
      {children}
    </button>
  )
}
```

## Decomposition Checklist

- [ ] Every visual section in the prototype maps to a component
- [ ] Repeated elements have been extracted into reusable components
- [ ] Each component has a defined TypeScript interface
- [ ] Server/client boundary is marked at the smallest interactive unit
- [ ] Client components receive server content through `children` props, not imports
- [ ] Shared patterns (cards, buttons, layouts) are in `components/shared/`
- [ ] Props are minimal - leaf components receive primitives, containers receive structured data
- [ ] No prop drilling beyond 2 levels (use context or lift state if needed)
- [ ] Files organized by domain, not by component type
