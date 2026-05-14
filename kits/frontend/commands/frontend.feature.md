---
name: frontend-feature
description: "Implement a frontend feature (React component, Next.js page, form, data fetching) with type-safe patterns"
argument-hint: "<feature description>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

# Frontend Feature Implementation

Implement a frontend feature following type-safe, production-ready patterns.

## Non-Negotiables / Do NOT

- Do NOT install or use prebuilt UI control libraries such as MUI, Ant Design, Chakra, Mantine, Bootstrap JS components, DaisyUI, Flowbite, shadcn/ui components, or similar packages for standard controls.
- Do NOT replace copied third-party CSS with a library default component.
- Do NOT leave copied CSS as broad global selectors. Scope it under a feature root, CSS Module, or dedicated feature CSS entry.
- Do NOT import remote CDN CSS, external resets, external font CSS, or vendor JavaScript behavior casually.
- Do NOT add JavaScript for visual state that CSS can express with native selectors, Tailwind v4 variants, container queries, or `@starting-style`.
- Do NOT add speculative variants, catch-all config props, or wrappers that make simple UI harder to edit.

## Workflow

### 1. Understand Requirement

- Clarify the feature scope: component, page, form, or data flow
- Identify data sources: server components, API routes, Server Actions
- Determine user interactions: display-only, interactive, form submission
- Identify edge cases: loading states, error states, empty states
- Identify whether the feature starts from copied third-party CSS, a template, or a design export

### 2. Determine Server/Client Boundary

- **Server component** (default) — data fetching, static rendering, SEO pages
- **Client component** (only when needed) — event handlers, hooks, browser APIs
- Keep data fetching in server components whenever possible
- Move interactivity to the smallest possible client component subtree

### 3. Design Component Hierarchy

- Identify visual sections → separate components
- Identify repetition → reusable components
- Use composition patterns for complex APIs (compound components)
- Define props interfaces — `interface` for props, `type` for unions
- Use discriminated unions for state, not boolean flags

### 4. Implement with TypeScript + Tailwind Tokens

- Declare functions with explicit props parameter (no `React.FC`)
- Use explicit event handler types (no implicit `any`)
- Use `useRef<HTMLSpecificElement>` (no generic `HTMLElement`)
- Use Tailwind semantic tokens: `bg-[--color-primary]`, not `bg-blue-500`
- Scope copied CSS first; promote repeated values to `@theme` tokens only after inventory
- Use `tv()` only for genuine multi-variant components
- Mobile-first responsive design
- Add ARIA attributes for interactive elements

### 5. Add Zod Validation (If Forms)

- Define Zod schema for form data
- Derive TypeScript type via `z.infer<typeof schema>`
- Implement Server Action with Zod validation at boundary
- Use `satisfies` for config validation where appropriate

### 6. Add Loading/Error States

- `loading.tsx` Suspense fallback for every route with async data
- `error.tsx` error boundary for every route with async data
- `not-found.tsx` for 404 cases
- Empty state UI for zero-data scenarios

### 7. Write Tests

- Component tests with Vitest + Testing Library for interactive components
- Server Action tests for form submissions and mutations
- E2E tests only for critical user journeys

## Skills Integration

| Step | Skill |
|------|-------|
| React patterns | `react-best-practices` |
| TypeScript patterns | `typescript-react` |
| Tailwind patterns | `tailwind-v4` |
| Copied CSS integration | `third-party-css-integration` |
| Next.js patterns | `nextjs-app-router` |
| Testing patterns | `frontend-testing` |
