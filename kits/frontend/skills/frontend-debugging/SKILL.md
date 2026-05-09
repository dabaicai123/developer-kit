---
name: frontend-debugging
description: 4 debugging playbooks for common frontend issues: type errors, hydration mismatches, effect dependency bugs, and Next.js-specific problems. Quick diagnosis table included.
version: "1.0.0"
type: skill
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Frontend Debugging

Systematic playbooks for the four most common frontend debugging scenarios.

## When to Use This Skill

- Debugging TypeScript type errors in React components
- Fixing SSR/CSR hydration mismatches in Next.js
- Resolving useEffect dependency bugs (infinite loops, stale closures)
- Debugging Next.js-specific issues (cache, Suspense, routing)

## Quick Diagnosis Table

| Symptom | Likely Cause | Playbook |
|---|---|---|
| `Type 'X' is not assignable to type 'Y'` | Type inference mismatch | [type-error-debugging](references/type-error-debugging.md) |
| `Text content did not match server/client` | SSR/CSR mismatch | [hydration-issues](references/hydration-issues.md) |
| Infinite re-render loop | useEffect dependency cycle | [effect-dependency-bugs](references/effect-dependency-bugs.md) |
| Stale data in component | Closure over stale value | [effect-dependency-bugs](references/effect-dependency-bugs.md) |
| Page shows stale data after mutation | Next.js cache not revalidated | [nextjs-debug-tricks](references/nextjs-debug-tricks.md) |
| Suspense fallback shows forever | Server Component bailout | [nextjs-debug-tricks](references/nextjs-debug-tricks.md) |
| 404 on dynamic route | generateStaticParams issue | [nextjs-debug-tricks](references/nextjs-debug-tricks.md) |
| `Cannot read properties of undefined` | Optional chaining missing | [type-error-debugging](references/type-error-debugging.md) |

## The Four Playbooks

### 1. Type Error Debugging

**Symptoms**: TypeScript compiler errors, `as` assertions needed, runtime `undefined` crashes.

**Flow**:
1. Read the error message carefully - identify which constraint is violated
2. Check if inference is correct (hover types, use `satisfies`)
3. Add explicit annotation where inference fails
4. Use `satisfies` instead of `as` for type checking without overriding
5. Narrow types with discriminated unions instead of casting

### 2. Hydration Issues

**Symptoms**: React hydration warning, content flicker, layout shift on mount.

**Flow**:
1. Check for date/time rendering (server time != client time)
2. Check for browser-only APIs (window, document, navigator)
3. Check for conditional rendering based on client state
4. Check for third-party scripts that modify DOM
5. Fix: suppress hydration warning for intentional mismatches, use `useEffect` for client-only content

### 3. Effect Dependency Bugs

**Symptoms**: Infinite loop, stale callback, missing cleanup, unexpected re-fetches.

**Flow**:
1. Identify the loop trigger (which state change causes re-render)
2. Check effect dependencies (missing vs extra)
3. Check if dependency is a new reference every render (object/array literal)
4. Use `useRef` for values that shouldn't trigger re-runs
5. Use `useCallback` for callback dependencies
6. Add cleanup function for subscriptions/timers

### 4. Next.js Debug Tricks

**Symptoms**: Stale cached data, Suspense not resolving, unexpected dynamic rendering.

**Flow**:
1. Check fetch caching options (`cache`, `next.revalidate`, `next.tags`)
2. Check dynamic rendering markers (`cookies()`, `headers()`, `searchParams`)
3. Use `next build` to see which pages are static vs dynamic
4. Use React DevTools Profiler to find bailout issues
5. Check Suspense boundaries for missing fallbacks

## General Debugging Principles

1. **Read the error message**: React and TypeScript errors are specific. Read them before googling.
2. **Isolate the problem**: Comment out code until the error disappears. Add it back one piece at a time.
3. **Check assumptions**: Hover over types in your editor. Are they what you expect?
4. **Binary search**: Split the code in half, test each half. Narrow down to the exact line.
5. **Console.log strategically**: Log types (`console.log(typeof x)`), not just values.
6. **Use React DevTools**: Inspect component props, state, and context values.

## Related Skills

- **typescript-react**: Type patterns that prevent common errors
- **nextjs-app-router**: RSC, caching, Suspense mechanics
- **frontend-testing**: Testing as a debugging tool

## References

- [type-error-debugging](references/type-error-debugging.md) - Flowchart for systematic type error resolution
- [hydration-issues](references/hydration-issues.md) - SSR/CSR mismatch diagnosis and fixes
- [effect-dependency-bugs](references/effect-dependency-bugs.md) - Detection patterns for loops, stale closures, cleanup
- [nextjs-debug-tricks](references/nextjs-debug-tricks.md) - Cache debugging, Suspense bailout, debug build paths