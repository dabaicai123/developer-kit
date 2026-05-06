# Bundle Size Optimization

Rules for minimizing JavaScript shipped to the client. Barrel imports and eagerly-loaded heavy components directly impact TTI and LCP.

---

## Rule 1: Avoid Barrel File Imports

Import directly from source files instead of barrel files. Barrel files (index.js that re-export everything) cause the bundler to load thousands of unused modules.

Popular icon and component libraries can have up to 10,000 re-exports in their entry file. Importing from them takes 200-800ms on every cold start.

**Bad (imports entire library):**

```tsx
import { Check, X, Menu } from 'lucide-react'
// Loads 1,583 modules, ~2.8s extra in dev

import { Button, TextField } from '@mui/material'
// Loads 2,225 modules, ~4.2s extra in dev

import { debounce, throttle } from 'lodash'
// Loads the entire lodash library

import { format, parse } from 'date-fns'
// Loads all 200+ locale and function modules
```

**Good -- Next.js 13.5+ (recommended):**

```ts
// next.config.ts - automatically optimizes barrel imports at build time
const nextConfig = {
  experimental: {
    optimizePackageImports: [
      'lucide-react',
      '@mui/material',
      '@mui/icons-material',
      'lodash',
      'date-fns',
      'rxjs',
    ],
  },
}

export default nextConfig
```

```tsx
// Keep the standard imports - Next.js transforms them to direct imports
import { Check, X, Menu } from 'lucide-react'
// Full TypeScript support, no manual path wrangling
```

This preserves TypeScript type safety and editor autocompletion while eliminating barrel import cost.

**Good -- Direct imports (without optimizePackageImports):**

```tsx
import Button from '@mui/material/Button'
import TextField from '@mui/material/TextField'
// Loads only what you use

import debounce from 'lodash/debounce'
import throttle from 'lodash/throttle'
// Loads only the specific functions

import format from 'date-fns/format'
import parse from 'date-fns/parse'
// Loads only the needed functions
```

Commonly affected libraries: `lucide-react`, `@mui/material`, `@mui/icons-material`, `@tabler/icons-react`, `react-icons`, `@headlessui/react`, `@radix-ui/react-*`, `lodash`, `ramda`, `date-fns`, `rxjs`, `react-use`.

These optimizations provide 15-70% faster dev boot, 28% faster builds, 40% faster cold starts.

---

## Rule 2: Dynamic Imports for Heavy Components

Use `next/dynamic` to lazy-load large components not needed on initial render.

**Bad (Monaco bundles with main chunk ~300KB):**

```tsx
import { MonacoEditor } from './monaco-editor'

function CodePanel({ code }: { code: string }) {
  return <MonacoEditor value={code} />
}
```

**Good (Monaco loads on demand):**

```tsx
import dynamic from 'next/dynamic'

const MonacoEditor = dynamic(
  () => import('./monaco-editor').then(m => m.MonacoEditor),
  { ssr: false }
)

function CodePanel({ code }: { code: string }) {
  return <MonacoEditor value={code} />
}
```

Common candidates for dynamic imports: code editors, chart libraries, map components, PDF viewers, heavy animation libraries, table components with 50+ columns.

The `ssr: false` option prevents server-side rendering of client-only modules, reducing server bundle size.

---

## Rule 3: Conditional Module Loading

Load large data or modules only when a feature is activated or a user action triggers them.

**Bad (animation frames always loaded):**

```tsx
import { frames } from './animation-frames'

function AnimationPlayer({ enabled }: { enabled: boolean }) {
  if (!enabled) return <Placeholder />
  return <Canvas frames={frames} />
}
```

**Good (loads only when enabled):**

```tsx
import { useState, useEffect } from 'react'

function AnimationPlayer({
  enabled,
  setEnabled,
}: {
  enabled: boolean
  setEnabled: React.Dispatch<React.SetStateAction<boolean>>
}) {
  const [frames, setFrames] = useState<Frame[] | null>(null)

  useEffect(() => {
    if (enabled && !frames && typeof window !== 'undefined') {
      import('./animation-frames')
        .then(mod => setFrames(mod.frames))
        .catch(() => setEnabled(false))
    }
  }, [enabled, frames, setEnabled])

  if (!frames) return <Skeleton />
  return <Canvas frames={frames} />
}
```

The `typeof window !== 'undefined'` check prevents bundling this module for SSR, reducing server bundle size.

---

## Rule 4: Defer Non-Critical Third-Party Libraries

Analytics, logging, and error tracking don't block user interaction. Load them after hydration.

**Bad (blocks initial bundle):**

```tsx
import { Analytics } from '@analytics/sdk/react'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  )
}
```

**Good (loads after hydration):**

```tsx
import dynamic from 'next/dynamic'

const Analytics = dynamic(
  () => import('@analytics/sdk/react').then(m => m.Analytics),
  { ssr: false }
)

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <Analytics />
      </body>
    </html>
  )
}
```

---

## Rule 5: Preload Based on User Intent

Preload heavy bundles before they are needed to reduce perceived latency. Trigger on hover or focus.

**Bad (loads on click, user waits):**

```tsx
function EditorButton({ onClick }: { onClick: () => void }) {
  return <button onClick={onClick}>Open Editor</button>
}
```

**Good (preloads on hover/focus):**

```tsx
function EditorButton({ onClick }: { onClick: () => void }) {
  const preload = () => {
    if (typeof window !== 'undefined') {
      void import('./monaco-editor')
    }
  }

  return (
    <button onMouseEnter={preload} onFocus={preload} onClick={onClick}>
      Open Editor
    </button>
  )
}
```

The module starts downloading during hover (~200ms before click), so by the time the user clicks, it is likely already loaded.

---

## Rule 6: Use Statically Analyzable Import Paths

Build tools work best when import paths are obvious at build time. Dynamic string paths force the bundler to widen traces or include broad file sets.

**Bad (bundler cannot determine what will be imported):**

```tsx
const PAGE_MODULES = {
  home: './pages/home',
  settings: './pages/settings',
} as const

const Page = await import(PAGE_MODULES[pageName])
// Bundler must include all files under ./pages/
```

**Good (explicit map of allowed modules):**

```tsx
const PAGE_MODULES = {
  home: () => import('./pages/home'),
  settings: () => import('./pages/settings'),
} as const

const Page = await PAGE_MODULES[pageName]()
// Bundler sees each import() individually, traces only these two files
```

This also applies to file-system paths in server code. `path.join(process.cwd(), someVar)` can widen Next.js output file tracing:

**Bad (widens traced file set):**

```tsx
const baseDir = path.join(process.cwd(), 'content/' + contentKind)
```

**Good (each path is literal):**

```tsx
const baseDir =
  kind === ContentKind.Blog
    ? path.join(process.cwd(), 'content/blog')
    : path.join(process.cwd(), 'content/docs')
```

---

## Rule 7: Code Splitting Strategies

Group splits by route and feature, not by arbitrary file boundaries.

**Route-level splitting (automatic in Next.js):**

```tsx
// Each page.tsx is automatically a separate chunk
// app/dashboard/page.tsx — only loaded when visiting /dashboard
// app/settings/page.tsx — only loaded when visiting /settings
```

**Feature-level splitting (manual):**

```tsx
import dynamic from 'next/dynamic'

// Only loaded when the feature is active
const AdvancedSearch = dynamic(
  () => import('./advanced-search').then(m => m.AdvancedSearch),
  { ssr: false }
)

function SearchPage({ hasAdvancedSearch }: { hasAdvancedSearch: boolean }) {
  return (
    <div>
      <BasicSearch />
      {hasAdvancedSearch && <AdvancedSearch />}
    </div>
  )
}
```

**loading.tsx for instant feedback:**

```tsx
// app/dashboard/loading.tsx — shows immediately while page chunk loads
export default function DashboardLoading() {
  return (
    <div className="p-8 space-y-4">
      <div className="animate-pulse h-8 bg-gray-200 rounded w-1/3" />
      <div className="animate-pulse h-64 bg-gray-200 rounded" />
    </div>
  )
}
```

---

## Bundle Analysis

Use `@next/bundle-analyzer` to find unexpected large chunks:

```tsx
// next.config.ts
import { withBundleAnalyzer } from '@next/bundle-analyzer'

const nextConfig = {
  experimental: {
    optimizePackageImports: ['lucide-react', 'lodash', 'date-fns'],
  },
}

export default process.env.ANALYZE === 'true'
  ? withBundleAnalyzer(nextConfig)
  : nextConfig
```

Run with `ANALYZE=true npm run build` to generate interactive treemaps showing exactly what each chunk contains.