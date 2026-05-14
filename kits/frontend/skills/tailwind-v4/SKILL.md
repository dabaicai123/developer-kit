---
name: tailwind-v4
description: "Applies Tailwind CSS v4 patterns for Next.js and TypeScript: CSS-first @theme configuration, OKLCH palettes, semantic tokens, dynamic utilities, new variants, tailwind-variants, and v3-to-v4 migration. Use when styling Tailwind v4 components or migrating from v3."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Tailwind CSS v4 Patterns

CSS-first configuration, OKLCH colors, semantic tokens, and component variants for Next.js + Tailwind v4 + TypeScript projects. The team does NOT use shadcn/ui or prebuilt UI control libraries for ordinary components.

## When to use this skill

- Setting up or modifying the `@theme` block in `app/globals.css`
- Defining semantic color tokens from design specs (Figma/ClaudeDesign/OpenDesign)
- Converting hex colors to OKLCH for perceptually uniform palettes
- Using `tv()` from tailwind-variants for component-level variant composition
- Implementing CSS-only enter/exit transitions with `@starting-style`
- Applying `not-*`, `in-*`, or `nth-*` variants
- Using dynamic arbitrary values without extending config
- Migrating from Tailwind v3 to v4
- Building responsive layouts with container queries
- Integrating copied third-party CSS without adopting its UI component library

## UI Dependency Policy

Copied CSS is allowed. Prebuilt UI controls are not the default.

**Do NOT:**

- Do NOT install shadcn/ui components, MUI, Ant Design, Chakra, Mantine, Bootstrap JS components, DaisyUI, Flowbite, or similar packages for standard controls.
- Do NOT replace a copied CSS snippet with a library component if semantic HTML plus scoped CSS is enough.
- Do NOT leave third-party CSS global; scope it first, then extract repeated values into `@theme`.
- Do NOT use Tailwind conversion as busywork; keep complex one-off effects in scoped CSS when that is simpler and safer.

## Overview

Tailwind v4 replaces `tailwind.config.js` with CSS-first `@theme` blocks. All design tokens become CSS variables. Colors use OKLCH format for perceptually uniform gradients and consistent lightness ramps. Dynamic values work without config extension. New CSS-native variants (`not-*`, `in-*`, `nth-*`) and `@starting-style` reduce JavaScript dependency for styling.

## @theme Configuration

No JavaScript config file. Define everything in CSS.

```css
@import "tailwindcss";

@theme {
  /* Colors — OKLCH format, semantic names */
  --color-primary: oklch(0.55 0.18 250);
  --color-primary-hover: oklch(0.48 0.18 250);
  --color-secondary: oklch(0.65 0.15 30);
  --color-text: oklch(0.22 0.02 250);
  --color-text-secondary: oklch(0.45 0.02 250);
  --color-surface: oklch(0.98 0.01 250);
  --color-surface-elevated: oklch(1.0 0 0);
  --color-border: oklch(0.88 0.01 250);
  --color-error: oklch(0.55 0.22 25);
  --color-success: oklch(0.55 0.17 145);

  /* Typography */
  --font-family-sans: "Inter", system-ui, sans-serif;
  --text-xs: 0.75rem;
  --text-sm: 0.875rem;
  --text-base: 1rem;
  --text-lg: 1.125rem;
  --text-xl: 1.25rem;
  --text-2xl: 1.5rem;
  --font-weight-normal: 400;
  --font-weight-medium: 500;
  --font-weight-semibold: 600;
  --font-weight-bold: 700;

  /* Spacing — 4px scale via --spacing */
  --spacing: 0.25rem;

  /* Border radius */
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
  --radius-xl: 0.75rem;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 2px 0 oklch(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px oklch(0 0 0 / 0.1), 0 2px 4px -2px oklch(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px oklch(0 0 0 / 0.1), 0 4px 6px -4px oklch(0 0 0 / 0.1);
}
```

**Namespace rules:** Prefixes determine which utilities are generated.

| Namespace | Utilities generated |
|---|---|
| `--color-*` | `bg-primary`, `text-text`, `border-border`, etc. |
| `--font-*` | `font-family-sans` |
| `--text-*` | `text-xs`, `text-sm`, `text-base`, etc. |
| `--font-weight-*` | `font-weight-bold` |
| `--spacing-*` | Spacing and sizing utilities; or `--spacing` for the base unit |
| `--breakpoint-*` | Responsive variants: `sm:*`, `md:*`, etc. |
| `--container-*` | Container query variants: `@sm:*`, `@md:*`, etc. |
| `--radius-*` | `rounded-sm`, `rounded-md`, etc. |
| `--shadow-*` | `shadow-sm`, `shadow-md`, etc. |
| `--animate-*` | `animate-spin`, etc. |

**Override the default theme entirely:**

```css
@theme {
  --color-*: initial; /* removes all default color utilities */
  --color-primary: oklch(0.55 0.18 250);
  --color-text: oklch(0.22 0.02 250);
  /* only these color utilities will exist */
}
```

**Reference other variables with `inline`:**

```css
@theme inline {
  --font-sans: var(--font-inter); /* utility resolves to var(--font-inter), not var(--font-sans) */
}
```

> For complete @theme setup with OKLCH palette generation, see `references/theme-setup`.

## OKLCH Color Format

OKLCH separates lightness (L), chroma (C), and hue (H) into independent channels. This produces perceptually uniform palettes where equal L-steps feel equally distant to the eye.

```css
/* OKLCH format: oklch(L C H) */
/* L: lightness 0-1, C: chroma (saturation) 0-0.4, H: hue angle 0-360 */
--color-primary-50: oklch(0.97 0.02 250);   /* very light */
--color-primary-100: oklch(0.93 0.05 250);
--color-primary-200: oklch(0.85 0.10 250);
--color-primary-300: oklch(0.75 0.15 250);
--color-primary-400: oklch(0.65 0.18 250);
--color-primary-500: oklch(0.55 0.18 250);  /* base */
--color-primary-600: oklch(0.48 0.18 250);
--color-primary-700: oklch(0.40 0.15 250);
--color-primary-800: oklch(0.32 0.10 250);
--color-primary-900: oklch(0.25 0.06 250);  /* very dark */
```

**Hex to OKLCH conversion** — use the browser DevTools color picker, or an online converter like oklch.com. Keep the hue constant across a palette; step lightness in even increments (0.05-0.08 per step). Chroma peaks at the mid-range (500-600) and tapers at extremes.

**Gradient interpolation** — v4 defaults to OKLAB. Override with a modifier:

```html
<div class="bg-linear-to-r/oklch from-indigo-500 to-teal-400">
  <!-- vivid gradient via OKLCH interpolation -->
</div>
```

## Semantic Token Naming

Use purpose-based names, not palette-based names. A token named `--color-primary` can be retuned without touching any component code.

| Token | Purpose | Example value |
|---|---|---|
| `--color-primary` | Primary action color | `oklch(0.55 0.18 250)` |
| `--color-primary-hover` | Primary hover state | `oklch(0.48 0.18 250)` |
| `--color-secondary` | Secondary action color | `oklch(0.65 0.15 30)` |
| `--color-text` | Default text color | `oklch(0.22 0.02 250)` |
| `--color-text-secondary` | Dimmed/placeholder text | `oklch(0.45 0.02 250)` |
| `--color-surface` | Card/page background | `oklch(0.98 0.01 250)` |
| `--color-border` | Border/divider color | `oklch(0.88 0.01 250)` |
| `--color-error` | Error/danger state | `oklch(0.55 0.22 25)` |
| `--color-success` | Success/confirmation | `oklch(0.55 0.17 145)` |

**In components, always reference semantic tokens:**

```tsx
<button className="bg-primary text-surface-elevated hover:bg-primary-hover rounded-md px-4 py-2">
  Submit
</button>
```

Never reference palette scales directly in component code (`bg-blue-500`) — that breaks theme retuning.

## Dynamic Utility Values

v4 lets you use arbitrary values inline without extending any config. Use brackets `[]` for one-off values.

```html
<!-- Arbitrary spacing -->
<div class="p-[18px] mt-[2.5rem]">

<!-- Arbitrary colors (use OKLCH or hex) -->
<div class="bg-[oklch(0.7_0.15_120)]">

<!-- Arbitrary grid -->
<div class="grid-cols-[1fr_2fr_1fr]">

<!-- Arbitrary font size -->
<span class="text-[22px]">
```

**Rule:** For values that repeat across multiple components, add a `@theme` token instead of using arbitrary values everywhere. Arbitrary values are for one-offs, not for values that should be on the design system scale.

## @starting-style for CSS-only Transitions

The `starting` variant maps to `@starting-style`, enabling CSS-only enter/exit transitions without JavaScript.

```css
/* Define the transition in @theme or in a component class */
.popover-enter {
  transition: opacity 0.3s, transform 0.3s;
}
```

```tsx
// Popover with enter transition
<div popover id="my-popover" className="
  opacity-100 scale-100
  transition-discrete starting:open:opacity-0 starting:open:scale-95
">
  Content
</div>
```

The `starting` variant sets the initial state before the element appears. Combined with `transition-discrete`, the browser transitions from the `starting:` state to the final state on entry.

**Exit transitions** require `@starting-style` on the final state:

```tsx
<div popover id="my-popover" className="
  opacity-100 scale-100
  transition-discrete
  starting:open:opacity-0 starting:open:scale-95
  open:opacity-100 open:scale-100
">
  Content
</div>
```

## New Variants

### not-* variant

Negate any variant. Style elements that do NOT match a condition.

```html
<!-- Underline all items except the last -->
<ul>
  <li className="not-last:underline">Item 1</li>
  <li className="not-last:underline">Item 2</li>
  <li className="not-last:underline">Item 3</li>
</ul>

<!-- Hover color, but not when focused -->
<button className="hover:not-focus:bg-primary">
  Action
</button>

<!-- Style elements that are not hovered -->
<div className="not-hover:opacity-80">
```

### in-* variant

Like `group-*` but without needing a `group` class. Targets the nearest ancestor matching the variant condition.

```html
<!-- Highlight text when inside a hovered parent -->
<div className="bg-surface p-4">
  <span className="in-hover:text-primary">Highlighted on parent hover</span>
</div>

<!-- Style when parent is focused -->
<input className="in-focus:border-primary" />
```

### nth-* variant

Target elements by their position using CSS `:nth-*` pseudo-classes.

```html
<!-- Stripe every even row -->
<table>
  <tr className="nth-even:bg-surface">...</tr>
</table>

<!-- First child styling -->
<div className="nth-first:font-bold nth-first:text-primary">

<!-- Specific nth pattern -->
<li className="nth-[3n+1]:border-l-primary">
```

## tailwind-variants (tv())

Use `tv()` for component-level variant composition when a component has multiple visual variants that map to different class combinations.

**Install:**

```bash
npm install tailwind-variants
```

**Basic usage:**

```tsx
import { tv } from "tailwind-variants";

const button = tv({
  base: "font-medium rounded-md active:opacity-80 transition-colors",
  variants: {
    variant: {
      primary: "bg-primary text-surface-elevated hover:bg-primary-hover",
      secondary: "bg-secondary text-surface-elevated hover:bg-secondary-hover",
      outline: "border border-border text-text hover:bg-surface",
    },
    size: {
      sm: "text-sm px-3 py-1",
      md: "text-base px-4 py-2",
      lg: "text-lg px-6 py-3",
    },
  },
  defaultVariants: {
    variant: "primary",
    size: "md",
  },
});

// Usage
<Button className={button({ variant: "outline", size: "sm" })}>
  Cancel
</Button>
```

**Slots** — for components with multiple styled parts:

```tsx
const card = tv({
  slots: {
    base: "rounded-lg shadow-md overflow-hidden",
    header: "px-4 py-3 border-b border-border",
    body: "px-4 py-4",
    footer: "px-4 py-3 bg-surface",
  },
  variants: {
    variant: {
      elevated: {
        base: "shadow-lg",
        header: "bg-surface-elevated",
      },
      flat: {
        base: "shadow-sm border border-border",
      },
    },
  },
  defaultVariants: {
    variant: "elevated",
  },
});

// Usage
const { base, header, body, footer } = card({ variant: "elevated" });

<section className={base()}>
  <div className={header()}>Title</div>
  <div className={body()}>Content</div>
  <div className={footer()}>Actions</div>
</section>
```

**Compound variants** — styles that apply only when multiple variants are active simultaneously:

```tsx
const button = tv({
  base: "rounded-md font-medium",
  variants: {
    variant: {
      primary: "bg-primary text-surface-elevated",
      outline: "border border-border text-text",
    },
    size: {
      sm: "text-sm px-3 py-1",
      lg: "text-lg px-6 py-3",
    },
  },
  compoundVariants: [
    {
      variant: "primary",
      size: "lg",
      class: "shadow-md", // large primary buttons get a shadow
    },
  ],
});
```

**When to use tv() vs conditional classes:**

| Situation | Approach |
|---|---|
| Component has 3+ variant combinations | Use `tv()` |
| Component has 1-2 simple variants (e.g., just size) | Conditional classes are fine |
| Component has multiple styled parts (slots) | Use `tv()` with slots |
| One-off conditional style | `clsx` or ternary in className |
| Shared base style across many variants | Use `tv()` with `base` |

> For complete tv() patterns including responsive variants and extend, see `references/component-variants`.

## v3 to v4 Migration — Key Changes

| v3 | v4 | Notes |
|---|---|---|
| `tailwind.config.js` | `@theme` CSS block | No JS config; use `@config` directive only for legacy |
| `@tailwind base; @tailwind components; @tailwind utilities;` | `@import "tailwindcss";` | Single import replaces three directives |
| `bg-gradient-to-r` | `bg-linear-to-r` | Gradient renamed |
| `ring-width` / `ring-color` defaults | `currentColor` / 3px default | Override with `--default-ring-width` / `--default-ring-color` |
| `border-color` defaults to `gray-200` | `border-color` defaults to `currentColor` | More aligned with browser defaults |
| `theme()` function in CSS | CSS variables (`var(--color-primary)`) | Prefer variables; `theme()` still works with new syntax |
| Plugin ecosystem (JS) | `@plugin` directive in CSS | CSS-first plugins |
| `content` array in config | Auto-detected from project | No `content` config needed |
| `@tailwindcss/container-queries` plugin | Built-in | Remove the plugin |
| `postcss-import`, `autoprefixer` | Built-in | Remove these PostCSS plugins |

**Automated migration:**

```bash
npx @tailwindcss/upgrade@latest
```

> For complete migration guide, see `references/v3-to-v4-migration`.

## Best Practices

- Define all design tokens in `@theme` — never scatter values across component code
- Use OKLCH for color definitions — perceptually uniform, better gradients, wider gamut
- Name tokens by purpose (`--color-primary`) not by palette (`--color-blue-500`) — enables theme retuning without touching components
- Use `tv()` for components with 3+ variant combinations; use conditional classes for simpler cases
- Use `@starting-style` for enter/exit transitions instead of JavaScript animation libraries
- Use `not-*` instead of `first:` + `last:` workarounds where it simplifies logic
- Reference semantic tokens in utility classes (`bg-primary`, `text-text`) — not palette scales
- Prefer CSS variables (`var(--color-primary)`) over the `theme()` function
- Use `--spacing: 0.25rem` to set the base spacing unit — all spacing utilities scale from it
- Put shared theme tokens in a separate CSS file for monorepo sharing: `@import "../brand/theme.css"`

## Anti-patterns

| Anti-pattern | Why | Correct |
|---|---|---|
| Hardcoded hex colors in components | No semantic meaning, impossible to retune theme | Define `@theme` tokens and reference them |
| `tailwind.config.js` in v4 projects | v4 is CSS-first; JS config only for legacy compat | Use `@theme` blocks in CSS |
| `tv()` for every component | Over-engineering simple cases; adds runtime overhead | Use `tv()` only for 3+ variant combos; conditional classes for simple cases |
| Palette names in component code (`bg-blue-500`) | Breaks theme retuning; no semantic meaning | Use semantic tokens (`bg-primary`) |
| Arbitrary values for repeated patterns (`p-[18px]`) | Drifts from design system, inconsistent spacing | Add a `@theme` token for values used more than once |
| Mixing `@theme` tokens with hardcoded values | Inconsistent: `bg-primary` next to `text-[#333]` | All values through `@theme` tokens |
| Using `@apply` extensively | Runtime cost, harder to debug | Use utility classes directly in JSX, or CSS variables in custom CSS |
| Keeping `postcss-import` / `autoprefixer` | v4 handles these internally | Remove from PostCSS config |
| Importing `@tailwindcss/container-queries` plugin | Built into v4 | Remove the package |
| Installing UI control libraries for copied CSS | Baked DOM/theme APIs make later edits harder | Project-owned markup plus scoped CSS |
| Unscoped third-party selectors | Global leaks cause unrelated UI regressions | Namespace or CSS Module before import |

## References

- `references/theme-setup` — Complete @theme configuration with OKLCH palette generation and token hierarchy
- `references/component-variants` — tailwind-variants (tv()) patterns: slots, compound variants, responsive variants, extend
- `references/v3-to-v4-migration` — Full migration guide: JS config removal, @theme blocks, renamed utilities, deprecated features
- `references/responsive-layouts` — Responsive patterns: mobile-first, breakpoint customization, container queries, grid/flex
- `references/new-utilities-and-variants` — @starting-style, not-*, in-*, nth-*, field-sizing, color-scheme, 3D transforms

## Related Skills

- `design-to-code` — Converting Figma/ClaudeDesign/OpenDesign specs to React components using Tailwind tokens
- `nextjs-app-router` — App Router conventions, server/client boundaries, layout patterns
- `react-composition` — Component composition patterns, slots, compound components

## Keywords

tailwind v4, @theme, oklch, semantic tokens, tailwind-variants, tv(), @starting-style, not-variant, in-variant, nth-variant, container queries, v3 migration, CSS-first configuration, design tokens
