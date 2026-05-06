---
name: design-to-component
description: "Convert a design specification to a Next.js React component with Tailwind v4 styling"
argument-hint: "<design specification or screenshot path>"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
model: inherit
---

# Design-to-Component Conversion

Convert a visual design specification to a production-ready Next.js React component with Tailwind v4 styling.

## Workflow

### 1. Receive Design Input

- **Screenshot path** — Read the image file and extract visual information
- **Written specification** — Parse text description into visual requirements
- **Figma/OpenDesign specification** — Parse structured design data
- Identify all visual elements: colors, typography, spacing, layout, interactive states

### 2. Extract Tokens into @theme

- Extract colors → convert to OKLCH → assign semantic names (`--color-primary`, `--color-surface`)
- Extract typography → map to `next/font` + `@theme` tokens (`--font-size-lg`, `--font-weight-bold`)
- Extract spacing → map to `@theme` tokens (`--spacing-md`, `--spacing-lg`)
- Extract borders/shadows → map to `@theme` tokens
- Write `@theme` block in global CSS with all tokens

### 3. Build HTML Prototype

- Create static HTML matching the design pixel-for-pixel
- Use token references in classes: `bg-[--color-primary]`, `text-[--color-on-surface]`
- Match layout structure: flexbox/grid positioning, responsive behavior
- Include all text content from the design
- Verify visual fidelity against original

### 4. Convert to Tailwind v4

- Replace any hardcoded values with token references
- Apply `@starting-style` for entry transitions
- Ensure mobile-first responsive design
- Use `tv()` only for genuine multi-variant components
- No `tailwind.config.js` — all configuration in CSS

### 5. Decompose into Components

- Identify visual boundaries → separate components
- Identify repetition → reusable components
- Identify interactivity → `'use client'` components
- Define `interface` for props shapes, `type` for unions
- Determine server vs client boundary

### 6. Add TypeScript Props

- Declare functions with explicit props (no `React.FC`)
- Use discriminated unions for state, not boolean flags
- Use explicit event handler types
- Use specific `useRef` element types
- Use `satisfies` for component config validation

### 7. Implement Dynamic Behavior

- Add `'use client'` only where interactivity exists
- Add event handlers with explicit TypeScript types
- Add ARIA attributes for accessibility
- Use `next/image` for images, `next/font` for fonts
- Implement Server Actions for form submissions
- Add Zod validation at boundaries

### 8. Verify Visual Fidelity

- Compare rendered component against original design
- Check responsive behavior at all breakpoints
- Check all interactive states (hover, focus, active, disabled)
- Check loading and error states

### 9. Add Accessibility

- ARIA labels on icon buttons and interactive elements
- Keyboard navigation for all interactive elements
- Alt text on images (decorative = `alt=""`)
- Focus management for modals and dialogs
- Color contrast meets WCAG 2.1 AA (4.5:1 for text)

## Skills Integration

| Step | Skill |
|------|-------|
| Token extraction | `design-to-code` |
| Tailwind patterns | `tailwind-v4` |
| React patterns | `react-best-practices` |
| TypeScript patterns | `typescript-react` |
| Accessibility | `web-design-audit` |