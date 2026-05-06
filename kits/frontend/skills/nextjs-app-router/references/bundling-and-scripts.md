# Bundling and Scripts

## Server-Incompatible Packages

Some npm packages use browser-only APIs (`window`, `document`) or Node-only APIs (`fs`, `path`) in their module entry points. When Next.js tries to bundle them for the wrong environment, it fails.

### Identifying the Problem

Common error messages:
- `Module not found: Can't resolve 'fs'` — Node-only module imported in client bundle
- `ReferenceError: window is not defined` — browser-only module imported in server bundle
- `Module not found: Can't resolve 'stream'` — Node stream API in client bundle

### Fixing Server-Bundle Issues

If a package only works in Node.js (e.g., database drivers, file system tools), exclude it from the server bundle:

```ts
// next.config.ts
const nextConfig = {
  serverExternalPackages: ['oracledb', 'canvas', 'better-sqlite3', 'pg-native'],
}

export default nextConfig
```

`serverExternalPackages` tells Next.js not to bundle these packages on the server. They are loaded from `node_modules` at runtime instead.

### Fixing Client-Bundle Issues

If a package uses `window` or `document` in its entry point but you need it on the client:

1. **Dynamic import with `ssr: false`** — only loads on the client:

```tsx
'use client'

import dynamic from 'next/dynamic'

const Chart = dynamic(() => import('react-chartjs-2'), {
  ssr: false,              // skip server rendering entirely
  loading: () => <div className="h-64 animate-pulse bg-gray-200 rounded" />,
})

export function Dashboard() {
  return <Chart data={chartData} />
}
```

2. **Conditional import** — check for browser environment:

```tsx
'use client'

import { useEffect, useState } from 'react'

export function MapComponent() {
  const [MapLib, setMapLib] = useState<typeof import('maplibre-gl') | null>(null)

  useEffect(() => {
    import('maplibre-gl').then((mod) => setMapLib(mod))
  }, [])

  if (!MapLib) return <div className="h-64 animate-pulse bg-gray-200 rounded" />

  return <MapLib.Map mapStyle="https://demotiles.maplibre.org/style.json" />
}
```

## CSS Imports

### Tailwind v4 Setup

Tailwind v4 uses CSS-first configuration. Import it in your root layout:

```css
/* app/globals.css */
@import "tailwindcss";

/* Custom theme overrides */
@theme {
  --color-primary: #3b82f6;
  --font-sans: var(--font-inter);
}
```

```tsx
// app/layout.tsx
import './globals.css'
```

### Third-Party CSS

Some packages ship their own CSS. Import it in the root layout or in the component that uses it:

```tsx
// Import in root layout for global CSS
// app/layout.tsx
import 'react-datepicker/dist/react-datepicker.css'
import './globals.css'
```

For CSS that only one component needs, import it locally:

```tsx
// app/dashboard/map.tsx
import 'maplibre-gl/dist/maplibre-gl.css'

export function Map() {
  // ...
}
```

### CSS Import Issues

- CSS imported in a Server Component applies globally (no scoping)
- CSS imported in a `'use client'` component also applies globally (CSS Modules are scoped)
- Use CSS Modules (`*.module.css`) for scoped styles when not using Tailwind

## Polyfills

### When Polyfills Are Needed

Some packages rely on browser APIs that don't exist in Node.js (for SSR), or Node APIs that don't exist in browsers (for client bundle):

```tsx
// Polyfill for server-side rendering
// app/layout.tsx or a dedicated polyfill file

// If a package uses window.matchMedia on the server:
if (typeof window === 'undefined') {
  globalThis.matchMedia = () => ({
    matches: false,
    addListener: () => {},
    removeListener: () => {},
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => false,
  })
}
```

### Polyfill Best Practices

- Load polyfills early (in root layout or a separate `polyfills.ts` file)
- Only polyfill what is actually needed — do not include full core-js unless necessary
- Prefer conditional polyfills that check for the missing API
- Consider using `next/dynamic` with `ssr: false` instead of polyfilling browser APIs for server rendering

## ESM/CJS Issues

### Module Format Mismatches

Some packages export ESM (`"type": "module"` in package.json) but are consumed as CJS, or vice versa. This causes errors like:

- `Must use import() to load ESM module`
- `require() of ESM module not supported`

### Fixes

1. **Transpile the package** — tell Next.js to transpile problematic packages:

```ts
// next.config.ts
const nextConfig = {
  transpilePackages: ['some-esm-only-pkg', '@org/problematic-lib'],
}

export default nextConfig
```

2. **Use dynamic import** — for packages that only support ESM:

```tsx
const module = await import('some-esm-only-pkg')
```

3. **Server external package** — for packages that don't work when bundled:

```ts
const nextConfig = {
  serverExternalPackages: ['problematic-node-pkg'],
}
```

### Common ESM/CJS Problematic Packages

| Package | Issue | Fix |
|---------|-------|-----|
| `uuid` | ESM-only in v9+ | `transpilePackages: ['uuid']` |
| `got` | ESM-only | `serverExternalPackages: ['got']` |
| `node-fetch` v3 | ESM-only | Use built-in `fetch` instead |
| `openai` | ESM-only | `transpilePackages: ['openai']` |

### Import Assertions

Some packages use `import ... from '...' with { type: 'json' }` for JSON imports. Next.js supports this in Server Components and Route Handlers, but not in Client Components.

## next/script

### When to Use next/script vs Native `<script>`

| Scenario | Use next/script | Use native `<script>` |
|----------|----------------|------------------------|
| Third-party analytics (GA, etc.) | Yes — controls loading strategy | No — no loading control |
| Scripts needed before page renders | Yes — `strategy="beforeInteractive"` | Possible but uncontrolled |
| Scripts that can load after page | Yes — `strategy="afterInteractive"` or `"lazyOnload"` | Yes — `<script defer>` |
| Inline scripts | Yes — `strategy` controls execution | Yes — `<script>` with inline code |
| Scripts needed in specific routes only | Yes — scoped to layout/page | No — global by default |

### Loading Strategies

```tsx
import Script from 'next/script'

// Strategy: afterInteractive (default) — loads immediately after page becomes interactive
<Script src="https://cdn.example.com/analytics.js" strategy="afterInteractive" />

// Strategy: lazyOnload — loads during idle time, lowest priority
<Script src="https://cdn.example.com/chat-widget.js" strategy="lazyOnload" />

// Strategy: beforeInteractive — loads before page renders (highest priority)
// Only works in root layout.tsx
<Script src="https://cdn.example.com/critical.js" strategy="beforeInteractive" />

// Strategy: worker — loads in a web worker (experimental, may not work with all scripts)
<Script src="https://cdn.example.com/heavy-lib.js" strategy="worker" />
```

### Script in Root Layout

Scripts in the root layout apply to every page. Use `afterInteractive` or `lazyOnload` for most third-party scripts:

```tsx
// app/layout.tsx
import Script from 'next/script'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html>
      <body>
        {children}
        <Script
          src="https://cdn.example.com/analytics.js"
          strategy="afterInteractive"
          onLoad={() => console.log('Analytics loaded')}
        />
      </body>
    </html>
  )
}
```

### Script in Specific Route

Scripts in a page or layout only load when that route is active:

```tsx
// app/dashboard/layout.tsx
import Script from 'next/script'

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  return (
    <div>
      {children}
      <Script
        src="https://cdn.example.com/dashboard-widget.js"
        strategy="lazyOnload"
      />
    </div>
  )
}
```

### onLoad and onReady

```tsx
<Script
  src="https://cdn.example.com/chat.js"
  strategy="lazyOnload"
  onLoad={() => {
    // Called when script finishes loading (first time only)
    initializeChat()
  }}
  onReady={() => {
    // Called when script finishes loading AND has already been loaded before (subsequent navigations)
    reinitializeChat()
  }}
  onError={(e) => {
    // Called when script fails to load
    console.error('Chat script failed:', e)
  }}
/>
```

### Inline Scripts

```tsx
<Script id="show-banner" strategy="lazyOnload">
  {`document.getElementById('banner').classList.remove('hidden')`}
</Script>
```

Always assign an `id` to inline scripts so Next.js can track and deduplicate them.

## Third-Party Script Checklist

- [ ] Use `strategy="lazyOnload"` for analytics and chat widgets (lowest priority)
- [ ] Use `strategy="afterInteractive"` for scripts that need to run early but aren't critical
- [ ] Use `strategy="beforeInteractive"` only for critical scripts in root layout
- [ ] Place route-specific scripts in that route's layout, not in root layout
- [ ] Add `id` to all inline scripts
- [ ] Handle `onError` for third-party scripts that may fail
- [ ] Prefer Server Components and CSS over client-side JavaScript libraries when possible