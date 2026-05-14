---
name: frontend-code-review
description: "Code review heuristics for React/Next.js/TypeScript/Tailwind with risk-vs-preference classification, architecture smell detection, and 12 common anti-patterns with root causes. Use when reviewing frontend PRs, conducting architecture reviews, or establishing team review standards."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Frontend Code Review

Structured code review heuristics for Next.js + Tailwind v4 + TypeScript projects. Classify findings as risk (must fix) or preference (discuss, not block), detect architecture smells early, and identify 12 common anti-patterns with root causes and fixes.

## When to use this skill

- Reviewing frontend PRs (pull requests, merge requests)
- Conducting architecture reviews on existing code
- Establishing or updating team review standards and checklists
- Mentoring new team members on review expectations
- Writing review comments that distinguish blockers from suggestions

## Risk vs Preference Classification

Every review finding falls into one of two categories. This classification determines whether a finding blocks the PR or is a discussion point.

### Risk (must fix, blocks merge)

Findings that can cause security vulnerabilities, data loss, performance degradation, accessibility violations, or hydration mismatches. These must be resolved before the PR merges.

| Category | Examples |
|---|---|
| Security vulnerability | XSS via unescaped input, exposed secrets in client bundles, missing CSRF on state-mutating requests |
| Data loss potential | Unvalidated form submissions, optimistic updates without rollback, missing error handling on mutations |
| Performance bottleneck | Unbounded client-side fetching, missing Suspense boundaries, large client bundles, unnecessary re-renders from state misuse |
| Accessibility violation | Missing ARIA labels on interactive elements, no keyboard navigation, focus trap absent in modals, color-only indicators |
| Hydration mismatch risk | Server/client content divergence, Date/time rendering without suppression, random values in server components |
| UI ownership risk | Prebuilt UI control library added for ordinary controls, copied CSS leaked globally, or vendor JS/CSS imported without review |

### Preference (discuss, not block)

Findings that affect code style, organization, or consistency but cannot cause user-facing defects. Raise these as suggestions; the author decides.

| Category | Examples |
|---|---|
| Naming convention | Variable names, function names, file names that differ from team style |
| Component organization | Grouping of related components, folder structure preferences |
| CSS class ordering | Order of Tailwind utility classes within a className string |
| Minor CSS organization | Local ordering of already-scoped selectors when behavior and visual output are unchanged |
| Variable naming style | `isX` vs `hasX` for booleans, `fetchX` vs `getX` for data access |

> For the full framework with examples and review comment templates, see `references/review-heuristics`.

## Architecture Smell Detection

Architecture smells indicate structural problems that degrade maintainability over time. Detect them early before they compound.

| Smell | Detection Pattern | Threshold |
|---|---|---|
| Props drilling | Component passes props it does not use itself, only forwards to children | Beyond 2 levels |
| God component | Single component with many responsibilities, many props, many state variables | 100+ lines or 7+ props |
| Shared state without clear ownership | Multiple components read/write same state, no single owner for updates | Any occurrence |
| Fetch in wrong boundary | Client component fetching data that a server component could fetch instead | Any occurrence |
| Over-abstracted hooks | Custom hook with many parameters, multiple return values, complex internal logic | 5+ parameters or 4+ return values |
| UI library dependency drift | MUI/AntD/Chakra/Mantine/Bootstrap JS/DaisyUI/Flowbite/shadcn controls introduced for standard UI | Any occurrence unless explicitly requested |
| Copied CSS leakage | Third-party selectors affect global `button`, `input`, `a`, `div`, `*`, or `body` | Any occurrence |

### How to detect smells during review

1. **Props drilling**: Trace prop chains. If a component receives a prop and passes it unchanged to a child, and that child also passes it down, the chain is too deep. Lift state or use composition.

2. **God component**: Count lines and props. A component exceeding 100 lines or accepting 7+ props is doing too much. Split into focused sub-components.

3. **Shared state without ownership**: When two or more components both dispatch actions to the same state slice, identify which component owns the state. Give ownership to the highest common ancestor or extract into a context with a clear API.

4. **Fetch in wrong boundary**: If a client component has `useEffect` or `fetch` for data that does not require user interaction to determine, move the fetch to a server component or use TanStack Query.

5. **Over-abstracted hooks**: If a hook's parameter list or return object is large, it wraps too much logic. Split into smaller, focused hooks or inline the logic in the component.

> For detection patterns and smell catalog with examples, see `references/review-heuristics`.

## 12 Anti-Patterns

Each anti-pattern includes the root cause (why it happens) and the fix (what to do instead). For expanded analysis with before/after code examples, see `references/anti-patterns-with-fixes`.

### 1. Storing server data in client state

**Root cause**: Developers default to `useState` + `useEffect` for all data, treating server responses like local UI state. This pattern comes from SPA habits where everything runs on the client.

**Fix**: Use TanStack Query (React Query) for server state. It handles caching, refetching, stale-while-revalidate, and avoids manual loading/error state management.

### 2. Boolean flags for state

**Root cause**: Developers model component state as separate boolean variables (`isLoading`, `isError`, `isSuccess`) because it feels intuitive. This leads to impossible states (e.g., both `isLoading` and `isError` true simultaneously).

**Fix**: Use discriminated unions. Define state as `{ status: "idle" | "loading" | "error" | "success" }` with associated data per status. Impossible states become impossible.

### 3. Effect for derived state

**Root cause**: Developers reach for `useEffect` whenever they need to compute a value from other values, treating it as a reactive "watcher" pattern common in other frameworks.

**Fix**: Compute derived values directly in the render body. If `filteredList` depends on `items` and `searchTerm`, calculate it as `const filteredList = items.filter(...)` during render. Use `useMemo` only when the computation is expensive and the inputs change infrequently.

### 4. Missing Suspense boundary

**Root cause**: Developers skip `loading.tsx` because the page renders fast in development, or they treat loading states as an afterthought added "when we have time."

**Fix**: Add `loading.tsx` alongside every page that fetches data. For nested async components, wrap them in `<Suspense>` with appropriate fallbacks. This enables streaming and prevents the whole page from blocking.

### 5. Unnecessary 'use client'

**Root cause**: Developers add `'use client'` to every component file out of habit from the Pages Router era, or because they are unsure which components need it. This inflates the client bundle unnecessarily.

**Fix**: Keep components as server by default. Only add `'use client'` when a component uses event handlers (onClick, onChange), React hooks (useState, useEffect), or browser APIs (window, document). Push the client boundary as far down the tree as possible.

### 6. Hardcoded theme values

**Root cause**: Developers copy colors and spacing from design specs as literal values (`bg-blue-500`, `text-gray-700`) instead of referencing the design system tokens. This happens when the token system is not yet set up or when developers are unfamiliar with Tailwind v4 `@theme`.

**Fix**: Use `@theme` tokens. Define semantic tokens in `globals.css` and reference them with `bg-[--color-primary]`, `text-[--color-text]`. Never use hardcoded utility classes for colors or spacing that should be part of the design system.

### 7. Prop drilling

**Root cause**: Developers pass data through intermediate components that do not use it themselves, because adding context or restructuring feels like over-engineering for a "simple" data flow. The drilling grows as the tree deepens.

**Fix**: Lift state to the highest component that actually uses it, or use composition (pass children or render functions) to skip intermediate layers. When the drilling exceeds 2 levels, extract a context with a clear API.

### 8. Inline styles

**Root cause**: Developers use `style={{ }}` for one-off values that do not map to existing Tailwind utilities, or when prototyping quickly. This breaks the design system and creates inconsistency.

**Fix**: Add a token to `@theme` for any value you use more than once, and reference it with the Tailwind arbitrary-value syntax. For truly one-off values, use Tailwind arbitrary properties (`[property:value]`) instead of inline styles.

### 9. Missing Zod validation

**Root cause**: Developers skip runtime validation on form inputs and API responses because TypeScript provides static types. Static types do not exist at runtime; unvalidated data from users or external APIs can have any shape.

**Fix**: Add Zod schemas at data boundaries. Validate form submissions before processing. Validate API responses before using them. Derive TypeScript types from Zod schemas with `z.infer<typeof schema>` to keep static and runtime types aligned.

### 10. Missing error boundary

**Root cause**: Developers skip `error.tsx` because errors are "handled" in the component with try/catch or conditional rendering. Runtime errors from failed renders still crash the entire page without a boundary.

**Fix**: Add `error.tsx` alongside every route segment. This catches unexpected render failures and shows a recovery UI. For client components with error-prone operations, wrap them in an `<ErrorBoundary>` component.

### 11. Untyped fetch responses

**Root cause**: Developers call `fetch()` and cast the response with `as SomeType` or use a generic type annotation, trusting that the API returns the expected shape. This provides no runtime verification and silently passes malformed data through the app.

**Fix**: Add Zod validation at the fetch boundary. Parse every response with a schema before the data enters the app. Wrap the result in `Result<T, E>` to force error handling at the call site.

### 12. Missing accessibility

**Root cause**: Developers focus on visual design and functionality first, treating accessibility as a compliance checkbox added at the end. This leaves interactive elements without keyboard support, ARIA attributes, or focus management.

**Fix**: Add accessibility during implementation, not after. Every interactive element needs an ARIA label if the visual label is insufficient, keyboard handlers (Enter/Space for buttons, Escape for dismiss), and focus management (trap in modals, return focus on close). Use semantic HTML elements first; ARIA only when HTML semantics are insufficient.

## Review Checklist

Copy and paste this checklist into your review. Check items by risk category.

### Risk items (must fix before merge)

- [ ] No XSS vectors (unescaped user input, dangerouslySetInnerHTML without sanitization)
- [ ] No secrets exposed in client bundles (API keys, tokens in client components)
- [ ] Form mutations validated with Zod schemas at the boundary
- [ ] API responses validated with Zod before entering the app
- [ ] Server data fetched via TanStack Query, not useState + useEffect
- [ ] No hydration mismatch risks (consistent server/client rendering)
- [ ] `loading.tsx` present for every page that fetches data
- [ ] `error.tsx` present for every route segment
- [ ] Interactive elements keyboard-accessible (buttons, links, modals)
- [ ] ARIA labels on icon-only buttons and custom widgets
- [ ] Focus trap in modals and dialogs
- [ ] No unbounded client-side data fetching
- [ ] `'use client'` only on components that need client features

### Preference items (discuss, not block)

- [ ] Component names follow team convention
- [ ] File organization matches agreed structure
- [ ] State modeled as discriminated unions, not boolean flags
- [ ] Derived values computed in render, not in effects
- [ ] Theme values use `@theme` tokens, not hardcoded utilities
- [ ] Props not drilled beyond 2 levels
- [ ] No inline styles; values reference `@theme` or Tailwind arbitrary properties
- [ ] No god components (100+ lines, 7+ props)
- [ ] Custom hooks focused (not over-abstracted)
- [ ] Fetch calls in the correct boundary (server where possible)

## Related Skills

- `react-best-practices` — Component patterns, hooks guidelines, composition patterns
- `typescript-react` — TypeScript patterns for React, typed props, discriminated unions
- `web-design-audit` — Auditing implemented pages against design specs for visual fidelity
- `frontend-debugging` — Debugging React rendering, state, hydration, and performance issues

## References

- [Review Heuristics](references/review-heuristics.md) — Full risk-vs-preference framework with examples, architecture smell catalog, and review comment templates
- [Anti-Patterns with Fixes](references/anti-patterns-with-fixes.md) — 12 anti-patterns expanded with root cause analysis, before/after code examples, and step-by-step fix instructions
