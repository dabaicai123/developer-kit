---
name: react-best-practices
description: "React performance optimization with priority-ranked rules across 8 categories: eliminating waterfalls, bundle size, server-side perf, client data fetching, re-render optimization, rendering perf, JS perf, and advanced patterns. Use when writing or reviewing React components, implementing data fetching, or optimizing bundle size."
version: "1.0.0"
type: skill
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# React Performance Best Practices

Priority-ranked rules for React + Next.js + TypeScript performance optimization. 8 categories, ordered by impact.

## When to use this skill

- Writing new React components or Next.js pages
- Implementing data fetching (server or client-side)
- Reviewing code for performance issues
- Refactoring existing React/Next.js code
- Optimizing bundle size or load times

## Priority Categories

| Priority | Category | Impact | Key Focus |
|----------|----------|--------|-----------|
| 1 | Eliminating Waterfalls | CRITICAL | Parallel fetching, Suspense streaming |
| 2 | Bundle Size Optimization | CRITICAL | Direct imports, dynamic imports, tree-shaking |
| 3 | Server-Side Performance | HIGH | Lean RSCs, React.cache, streaming |
| 4 | Client-Side Data Fetching | MEDIUM-HIGH | SWR/TanStack Query, request dedup |
| 5 | Re-render Optimization | MEDIUM | Memoize when profiling shows need, stable callbacks |
| 6 | Rendering Performance | MEDIUM | Virtualization, content-visibility, layout shifts |
| 7 | JavaScript Performance | LOW-MEDIUM | Map/Set lookups, early exits, CSS transitions |
| 8 | Advanced Patterns | LOW | Code splitting, stable callback refs |

## 1. Eliminating Waterfalls (CRITICAL)

Sequential async operations cause 2-10x slowdown. Every independent fetch that runs after an unrelated await is wasted time.

Key rules:

- **Parallel execution** -- Use `Promise.all()` for independent operations. Three sequential fetches become one round trip.
- **Defer await** -- Move `await` into branches where the value is actually used. Early returns skip unnecessary async work.
- **Suspense streaming** -- Wrap slow data sections in `<Suspense>` so the shell renders immediately while content streams in.
- **Start promises early** -- In API routes and Server Actions, create all promises upfront, then await only when results are needed.
- **Chain nested fetches per item** -- When fetching nested data (chat -> author), chain within each item's promise so a slow item doesn't block the rest.

> See `references/eliminating-waterfalls.md` for full rules with bad/good code examples.

## 2. Bundle Size Optimization (CRITICAL)

Barrel file imports and eagerly-loaded heavy components directly impact TTI and LCP.

Key rules:

- **Avoid barrel imports** -- Import directly from source files. A single `import { Button } from '@mui/material'` loads 2,225 modules. Use `optimizePackageImports` in Next.js or deep import paths.
- **Dynamic imports** -- Use `next/dynamic` for heavy components (editors, charts) not needed on initial render. Add `ssr: false` for client-only modules.
- **Conditional loading** -- Lazy-load modules only when a feature flag or user action activates them.
- **Statically analyzable paths** -- Use explicit import maps instead of dynamic string concatenation in `import()` or `fs` paths. The bundler cannot analyze `import(VARIABLE)` and widens the trace.
- **Preload on intent** -- Call `void import('./heavy-module')` on hover/focus to reduce perceived latency.

> See `references/bundle-size-optimization.md` for full rules with bad/good code examples.

## 3. Server-Side Performance (HIGH)

RSCs are powerful but easy to misuse. Every unnecessary serialization or sequential fetch on the server slows the response.

Key rules:

- **Minimize RSC serialization** -- Only pass fields the client actually uses across the server/client boundary. Passing a 50-field user object to a component that displays `name` wastes serialization cost.
- **React.cache() for deduplication** -- Wrap database queries, auth checks, and non-fetch async work with `cache()` to deduplicate within a single request. Use primitive arguments (not inline objects) for cache hits.
- **Hoist static I/O** -- Move font/logo/config reads to module level so they run once per module load, not per request.
- **Parallel fetching via composition** -- Split fetches into separate async components so they run concurrently instead of sequentially down the tree.
- **after() for non-blocking work** -- Use `after()` from `next/server` to schedule logging, analytics, and cache invalidation after the response is sent.

> See `references/server-side-performance.md` for full rules with bad/good code examples.

## 4. Client-Side Data Fetching (MEDIUM-HIGH)

When data must be fetched on the client, use a dedicated library for deduplication, caching, and revalidation.

Key rules:

- **SWR or TanStack Query** -- Never use raw `useEffect + fetch`. These libraries deduplicate requests across component instances, cache responses, and revalidate automatically.
- **Colocate fetch with consumer** -- Each component fetches its own data. Avoid top-level fetches that pass data through multiple layers of props.
- **Stale-while-revalidate** -- Show cached data immediately, then refresh in the background. Users never wait for repeated visits.
- **Request deduplication** -- Multiple components requesting the same key share one network call.

> See `references/client-data-fetching.md` for full rules with bad/good code examples.

## 5. Re-render Optimization (MEDIUM)

Re-renders are the most common React perf issue, but over-memoizing creates complexity. Profile first, then apply targeted fixes.

Key rules:

- **Memoize only when profiling shows need** -- Don't wrap everything in `memo()`/`useMemo()`. React Compiler handles most cases automatically. Only manually memoize when React DevTools Profiler confirms wasted renders.
- **Stable callbacks** -- Use functional `setState` (`setItems(curr => ...)`) to eliminate state from dependency arrays. This creates callbacks that never need recreation.
- **No inline components** -- Never define a component inside another component. Each render creates a new type, causing full remounts, lost state, and DOM thrash.
- **Derive during render** -- If a value is computable from existing state/props, compute it inline. Never sync it via `useEffect + setState`.
- **Narrow dependencies** -- Use primitive deps (`user.id` instead of `user`) in effects. Subscribe to derived booleans (`isMobile`) instead of continuous values (`width`).
- **Split combined computations** -- When a `useMemo` has independent sub-computations with different deps, split them into separate `useMemo` calls.

> See `references/re-render-optimization.md` for full rules with bad/good code examples.

## 6. Rendering Performance (MEDIUM)

DOM rendering costs compound quickly with long lists and layout instability.

Key rules:

- **Virtualization for long lists** -- Use `@tanstack/react-virtual` or similar for lists over 100 items. Rendering 1000 DOM nodes when only 20 are visible wastes layout/paint time.
- **content-visibility: auto** -- For non-virtualized long lists, apply `content-visibility: auto` with `contain-intrinsic-size` to skip off-screen layout/paint.
- **Prevent layout shifts** -- Always set explicit dimensions on images (`width`/`height` or `sizes`). Use `next/image` which enforces this. Reserve space for async content with skeleton fallbacks.
- **Explicit conditional rendering** -- Use ternaries (`count > 0 ? <Badge /> : null`) not `&&` for numeric conditions. `0 && <Badge />` renders "0" as text.
- **Resource hints** -- Use React DOM's `prefetchDNS`, `preconnect`, `preload` in server components to start loading critical resources before the client receives HTML.
- **Hoist static JSX** -- Extract large static SVGs and skeleton elements to module-level constants to avoid re-creation.

> See `references/rendering-performance.md` for full rules with bad/good code examples.

## 7. JavaScript Performance (LOW-MEDIUM)

Micro-optimizations that compound in hot loops and frequent event handlers.

Key rules:

- **Map/Set for O(1) lookups** -- Replace `array.find()` in loops with `Map.get()` or `Set.has()`.
- **Early exit** -- Return early from functions. Check cheap conditions before expensive ones.
- **Combine iterations** -- Replace `arr.filter().map()` with a single `flatMap` or manual loop.
- **Cache property access** -- In tight loops, cache `obj.property` to a local variable.
- **CSS transitions over JS** -- Use Tailwind `transition-*` and `animate-*` classes instead of JavaScript-driven animations. CSS transitions run on the compositor thread, skipping main-thread blocking.

## 8. Advanced Patterns (LOW)

Patterns for complex optimization scenarios.

Key rules:

- **Code splitting patterns** -- Group route-level code splits in `loading.tsx`. Split feature modules behind dynamic imports gated by feature flags.
- **Stable callback refs** -- Store event handlers in refs when passing them to native DOM APIs or long-lived subscriptions that shouldn't re-subscribe on every render.
- **Initialize once** -- For one-time app setup (WebSocket connections, global listeners), use a `useRef` flag to ensure it runs only on mount, not on re-renders.

## Anti-patterns

- **Sequential await for independent data** -- `const a = await fetchA(); const b = await fetchB()` when neither depends on the other
- **Barrel file imports** -- `import { X } from 'huge-library'` that loads thousands of modules
- **Raw useEffect + fetch** -- `useEffect(() => { fetch(url).then(...) }, [])` instead of SWR/TanStack Query
- **Inline component definitions** -- `const Inner = () => ...` inside a parent component body
- **Syncing derived state via effects** -- `useEffect(() => setFullName(first + last), [first, last])`
- **Passing full objects across RSC boundaries** -- `<ClientComp user={user50Fields} />` when only `name` is used
- **Missing Suspense for slow sections** -- A single `await` blocking the entire page shell
- **Dynamic import paths** -- `import(pathVar)` that forces the bundler to widen traces
- **&& with numeric values** -- `{count && <Badge />}` rendering "0" as text
- **Missing layout dimensions** -- Images without `width`/`height` causing layout shifts
- **Memoizing simple primitives** -- `useMemo(() => a + b, [a, b])` that costs more than the computation itself

## References

- See `references/` directory for detailed reference topics with bad/good code examples:
  1. `eliminating-waterfalls.md` -- Parallel fetching, Suspense streaming, promise chaining, API route patterns
  2. `bundle-size-optimization.md` -- Barrel imports, dynamic imports, conditional loading, preload, tree-shaking
  3. `server-side-performance.md` -- RSC patterns, React.cache, serialization, hoisting, after()
  4. `client-data-fetching.md` -- SWR/TanStack Query, colocated fetching, stale-while-revalidate, cache config
  5. `re-render-optimization.md` -- Memo guidelines, stable callbacks, derived state, no inline components, narrow deps
  6. `rendering-performance.md` -- Virtualization, content-visibility, layout shifts, resource hints, conditional rendering

## Related Skills

- `nextjs-app-router` -- RSC file conventions, Server Actions, Suspense, route handlers
- `react-composition` -- Component composition patterns, children prop, compound components
- `state-management` -- Zustand/Jotai patterns, store design, selector optimization
- `data-fetching` -- Data fetching strategies, caching, real-time updates

## Keywords

react, performance, optimization, waterfalls, bundle-size, rsc, server-components, re-render, memo, useCallback, useMemo, Suspense, streaming, virtualization, TanStack Query, SWR, dynamic-import, tree-shaking, Next.js