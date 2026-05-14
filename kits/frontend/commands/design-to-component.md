---
name: design-to-component
description: "Convert a design specification to a Next.js React component with Tailwind v4 styling"
argument-hint: "<design specification or screenshot path>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

# Design-to-Component Conversion

Convert a visual design specification to a production-ready Next.js React component with Tailwind v4 styling.

## Non-Negotiables / Do NOT

- Do NOT add or use prebuilt UI control libraries for standard controls unless the user explicitly asks; follow `third-party-css-conventions` for project-owned UI.
- Do NOT replace copied third-party CSS with a library default component.
- Do NOT leave copied CSS global. Scope it under a feature root or CSS Module before importing it.
- Do NOT import remote CDN CSS, external resets, external font CSS, or vendor JavaScript behavior casually.
- Do NOT solve copied CSS conflicts with `!important`, broad selectors, or higher-specificity overrides.
- Do NOT convert all copied CSS to Tailwind before visual fidelity is verified; keep complex low-churn effects in scoped CSS when that is simpler.
- Do NOT ship controls without keyboard, focus-visible, disabled, loading, empty, and error states where relevant.

## Workflow

### 1. Receive Design Input

- **Screenshot path** - Read the image file and extract visual information
- **Written specification** - Parse text description into visual requirements
- **Figma/OpenDesign specification** - Parse structured design data
- Identify copied third-party HTML/CSS inputs: selectors, assets, animations, broad globals, and repeated values
- Identify all visual elements: colors, typography, spacing, layout, interactive states

### 2. Extract Tokens into @theme

- Extract colors -> convert to OKLCH -> assign semantic names (`--color-primary`, `--color-surface`)
- Extract typography -> map to `next/font` + `@theme` tokens (`--text-lg`, `--font-weight-bold`)
- Extract spacing -> map to `@theme` tokens (`--spacing-md`, `--spacing-lg`)
- Extract borders/shadows -> map to `@theme` tokens
- Write `@theme` block in global CSS with all tokens

### 3. Build HTML Prototype

- Create static HTML matching the design pixel-for-pixel
- Use token references in classes: `bg-primary`, `text-on-surface`
- Keep copied CSS scoped in one feature CSS file or CSS Module until the layout is stable
- Match layout structure: flexbox/grid positioning, responsive behavior
- Include all text content from the design
- Verify visual fidelity against original

### 4. Convert to Tailwind v4

- Replace any hardcoded values with token references
- Apply `@starting-style` for entry transitions
- Ensure mobile-first responsive design
- Use `tv()` only for genuine multi-variant components
- Keep new Tailwind v4 tokens in CSS `@theme`; use `tailwind.config.js` only through `@config` for legacy migration

### 5. Decompose into Components

- Identify visual boundaries -> separate components
- Identify repetition -> reusable components
- Identify client-only interactivity -> `'use client'` components only for event handlers, hooks, browser APIs, imperative measurements, or client-only libraries
- Define `interface` for props shapes, `type` for unions
- Determine server vs client boundary

### 6. Add TypeScript Props

- Declare functions with explicit props (no `React.FC`)
- Use discriminated unions for state, not boolean flags
- Use explicit event handler types
- Use specific `useRef` element types
- Use `satisfies` for component config validation

### 7. Implement Dynamic Behavior

- Add `'use client'` only where client-only features exist; CSS hover/focus/active states stay in Server Components
- Add event handlers with explicit TypeScript types
- Use semantic HTML first; add ARIA only where native semantics are insufficient
- Use `next/image` for images, `next/font` for fonts
- Implement Server Actions for form submissions
- Add Zod validation at boundaries

### 8. Verify Visual Fidelity

- Compare rendered component against original design
- Check responsive behavior at all breakpoints
- Check all interactive states (hover, focus, active, disabled)
- Check loading and error states

### 9. Add Accessibility

- ARIA labels on icon-only buttons and custom widgets whose visual label is insufficient
- Keyboard navigation for all interactive elements
- Alt text on images (decorative = `alt=""`)
- Focus management for modals and dialogs
- Color contrast meets WCAG 2.1 AA (4.5:1 for text)

## Skills Integration

| Step | Skill |
|------|-------|
| Token extraction | `design-to-code` |
| Tailwind patterns | `tailwind-v4` |
| Copied CSS integration | `third-party-css-integration` |
| React patterns | `react-best-practices` |
| TypeScript patterns | `typescript-react` |
| Accessibility | `web-design-audit` |
