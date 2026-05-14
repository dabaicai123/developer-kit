---
paths:
  - "**/*.tsx"
  - "**/*.jsx"
---

# Rule: React Conventions

Enforce consistent React patterns across Next.js App Router projects. For detailed patterns, use `react-best-practices`, `react-composition`, and `typescript-react` skills.

## Guidelines

1. **Use `'use client'` only when necessary** - event handlers (onClick, onChange), hooks (useState, useEffect), browser APIs (window, document). Keep server components by default.

2. **Use composition patterns over configuration props** - compound components (Tabs/TabPanel, Card/CardHeader) for complex APIs. Single component with props for simple, constrained APIs.

3. **Derive TypeScript types from Zod schemas** - `z.infer<typeof schema>` for form and API data. Never define duplicate TypeScript interfaces for data already described by Zod.

4. **Use Tailwind @theme tokens** - `bg-primary` not `bg-blue-500`. Reference semantic tokens, never hardcoded color/spacing values.

5. **Use semantic HTML first, ARIA only when needed** - native buttons, links, labels, and form controls carry built-in semantics. Add ARIA for gaps such as icon-only buttons (`aria-label`), collapsibles (`aria-expanded`), and custom widgets. All interactive elements must be keyboard-accessible.

6. **Memoize only when profiling shows a problem** - never preemptively wrap in React.memo or useMemo. Start simple, optimize when measured.

7. **Use project-owned UI controls** - build controls with semantic HTML and local components. Do not introduce prebuilt UI control libraries for standard controls unless explicitly requested; follow `third-party-css-conventions`.

## Anti-Patterns

- Prebuilt UI control libraries for ordinary UI - own the markup so copied CSS stays easy to modify
- Copied CSS with broad global selectors - scope styles before wiring React components
- Adding `'use client'` to every component - only add when client features are needed
- Boolean prop proliferation (isLoading, isError, isSuccess) - use discriminated unions for state
- Prop drilling beyond 2 levels - use context or composition
- Hardcoded utility classes (`bg-blue-500`, `text-gray-700`) - use @theme token references
- Premature memoization - optimize after measuring
- Missing loading/error states for async data - always provide Suspense and error boundaries
