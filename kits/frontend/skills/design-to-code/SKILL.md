---
name: design-to-code
description: "Convert design specifications (Figma, ClaudeDesign, OpenDesign) to Next.js React components via Tailwind v4. Covers design token extraction, HTML/CSS prototyping, Tailwind conversion, component decomposition, and responsive implementation. Use when translating visual designs to code, setting up design tokens, or breaking mockups into component hierarchy."
version: "1.0.0"
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Design-to-Code Pipeline

Bridge design specifications (Figma, ClaudeDesign, OpenDesign) to production Next.js React components using Tailwind v4. This skill covers the full 5-stage workflow: token extraction, prototyping, Tailwind conversion, component decomposition, and dynamic implementation.

## When to use this skill

- Translating Figma/ClaudeDesign/OpenDesign specs into React components
- Setting up design tokens from a visual design specification
- Breaking a static mockup into a component hierarchy
- Converting raw HTML/CSS design output to Tailwind utility classes
- Integrating copied third-party HTML/CSS while keeping project-owned markup and avoiding prebuilt UI controls
- Implementing responsive layouts from desktop/mobile design specs
- Deciding server vs client component boundaries for a page

## Third-Party CSS Copy Rules

Copied HTML/CSS is acceptable input. Prebuilt UI control libraries are not the default implementation path.

**Do NOT:**

- Do NOT install or import MUI, Ant Design, Chakra, Mantine, Bootstrap JS components, DaisyUI, Flowbite, shadcn/ui components, or similar controls for standard UI.
- Do NOT install a component library to recreate copied CSS.
- Do NOT paste third-party CSS globally without scoping it under a feature root or CSS Module.
- Do NOT import remote CDN CSS, external resets, external font CSS, or vendor JavaScript behavior casually.
- Do NOT solve copied CSS conflicts with `!important`, broad selectors, or higher-specificity overrides.
- Do NOT convert every one-off copied value into global `@theme`; only repeated semantic values become tokens.
- Do NOT replace semantic HTML with div-only custom widgets.
- Do NOT ship copied controls without responsive, keyboard, focus-visible, disabled, loading, empty, and error states.

Use `third-party-css-integration` when the source includes usable CSS snippets, demos, templates, or copied component styles.

## The 5-Stage Pipeline

Every design-to-code conversion follows these stages. Skipping a stage creates defects that compound in later stages.

### Stage 1: Design Token Extraction

Read the design specification and extract visual properties into semantic tokens defined in a Tailwind v4 `@theme` block.

**Process:**

1. Read design spec output (HTML/CSS, Figma export, etc.) — see `design-tool-reference`
2. Identify all distinct colors, font sizes/weights, spacing values, border radii, shadows
3. Normalize values: convert hex colors to OKLCH, round spacing to a 4px scale, align font sizes to the type scale
4. Define semantic tokens in `@theme` block in `app/globals.css`

**Token definition in `app/globals.css`:**

```css
@import "tailwindcss";

@theme {
  /* Colors — always OKLCH format */
  --color-primary: oklch(0.55 0.18 250);
  --color-primary-hover: oklch(0.48 0.18 250);
  --color-surface: oklch(0.98 0.01 250);
  --color-surface-elevated: oklch(1.0 0 0);
  --color-text: oklch(0.22 0.02 250);
  --color-text-secondary: oklch(0.45 0.02 250);
  --color-border: oklch(0.88 0.01 250);
  --color-error: oklch(0.55 0.22 25);
  --color-success: oklch(0.55 0.17 145);

  /* Typography — reference by semantic name */
  --font-family-sans: "Inter", system-ui, sans-serif;
  --font-size-heading-1: 2.25rem;
  --font-size-heading-2: 1.5rem;
  --font-size-heading-3: 1.125rem;
  --font-size-body: 0.875rem;
  --font-size-caption: 0.75rem;
  --font-weight-heading: 700;
  --font-weight-body: 400;

  /* Spacing — 4px scale */
  --spacing-1: 0.25rem;
  --spacing-2: 0.5rem;
  --spacing-3: 0.75rem;
  --spacing-4: 1rem;
  --spacing-6: 1.5rem;
  --spacing-8: 2rem;
  --spacing-12: 3rem;
  --spacing-16: 4rem;

  /* Border radius */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 0.75rem;
  --radius-xl: 1rem;
  --radius-full: 9999px;

  /* Shadows */
  --shadow-sm: 0 1px 2px oklch(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px oklch(0 0 0 / 0.07);
  --shadow-lg: 0 10px 15px oklch(0 0 0 / 0.1);
}
```

> For detailed token extraction and hex-to-OKLCH conversion, see `references/token-extraction-guide`.

### Stage 2: HTML/CSS Prototyping

Build a static HTML page using Tailwind classes that matches the design spec visually. Do not componentize yet — verify visual fidelity first.

**Why prototype first:**
- Catch layout/spacing/color mismatches before component logic obscures them
- A single file is easy to tweak until pixel-perfect
- Prototyping reveals which patterns repeat and should become components

**Process:**

1. Create a single HTML file (or a Next.js page returning raw JSX) with all sections laid out
2. Apply Tailwind classes using `@theme` token references (`bg-[--color-primary]`, `text-[--font-size-heading-1]`)
3. Verify against the design spec at each breakpoint (mobile, tablet, desktop)
4. Iterate until visual fidelity is confirmed

**When starting from third-party CSS:** keep the copied CSS scoped in one feature file during the prototype. Convert repeated design values and simple layout utilities first; leave complex animations, media queries, and low-churn visual effects in scoped CSS until fidelity is stable.

**Prototype page structure:**

```tsx
// app/prototype/page.tsx — temporary, for visual verification only
export default function PrototypePage() {
  return (
    <div className="min-h-screen bg-[--color-surface] text-[--color-text]">
      {/* Navigation */}
      <nav className="flex items-center justify-between px-[--spacing-8] py-[--spacing-4]">
        <div className="text-[--font-size-heading-3] font-[--font-weight-heading]">Brand</div>
        <div className="flex gap-[--spacing-6] text-[--font-size-body]">
          <a href="#" className="text-[--color-text-secondary] hover:text-[--color-primary]">Products</a>
          <a href="#" className="text-[--color-text-secondary] hover:text-[--color-primary]">About</a>
          <a href="#" className="bg-[--color-primary] text-[--color-surface-elevated] px-[--spacing-4] py-[--spacing-2] rounded-[--radius-md]">Sign Up</a>
        </div>
      </nav>

      {/* Hero */}
      <section className="flex flex-col items-center py-[--spacing-16] px-[--spacing-8]">
        <h1 className="text-[--font-size-heading-1] font-[--font-weight-heading] text-center">
          Build faster with modern tools
        </h1>
        <p className="text-[--font-size-body] text-[--color-text-secondary] mt-[--spacing-4] max-w-prose text-center">
          Streamline your workflow with our integrated platform.
        </p>
        <button className="bg-[--color-primary] hover:bg-[--color-primary-hover] text-[--color-surface-elevated]
          px-[--spacing-8] py-[--spacing-3] rounded-[--radius-md] mt-[--spacing-8]
          text-[--font-size-body] font-[--font-weight-heading]">
          Get Started
        </button>
      </section>
    </div>
  )
}
```

> For layout pattern examples, see `references/html-prototyping-patterns`.

### Stage 3: Tailwind Conversion

Map the prototype's inline styles and custom CSS to Tailwind utility classes. Replace hardcoded values with `@theme` token references.

**Conversion rules:**

| CSS Property | Tailwind Utility | Token Reference Pattern |
|---|---|---|
| `background-color: #3366CC` | `bg-[--color-primary]` | Semantic token, not hex |
| `color: #333333` | `text-[--color-text]` | Semantic token |
| `font-size: 36px` | `text-[--font-size-heading-1]` | Type scale token |
| `font-weight: 700` | `font-[--font-weight-heading]` | Weight token |
| `padding: 16px` | `p-[--spacing-4]` | Spacing scale token |
| `margin-top: 24px` | `mt-[--spacing-6]` | Spacing scale token |
| `border-radius: 8px` | `rounded-[--radius-lg]` | Radius token |
| `box-shadow: ...` | `shadow-[--shadow-md]` | Shadow token |
| `display: flex` | `flex` | Standard utility |
| `gap: 24px` | `gap-[--spacing-6]` | Spacing token |
| `width: 100%` | `w-full` | Standard utility |
| `max-width: 640px` | `max-w-prose` | Container utility |

**Responsive variants — apply at the prototype stage:**

```tsx
<div className="
  flex flex-col            /* mobile: stacked */
  md:flex-row md:gap-[--spacing-8]  /* tablet+: side-by-side */
  lg:max-w-[--spacing-16]          /* desktop: wider */
">
```

**Key rule:** Do not use repeated hardcoded pixel values in Tailwind classes. If a value appears more than once or carries semantic meaning, add a new token to `@theme`. Keep true one-off copied values local when tokenizing them would add noise.

### Stage 4: Component Decomposition

Break the verified prototype into a React component tree. Identify visual boundaries, define props interfaces, and decide server vs client boundaries.

**Process:**

1. Identify visual boundaries in the prototype — each distinct section becomes a component candidate
2. Define component hierarchy — page composition at top, leaf components at bottom
3. Decide props interface for each component — what data flows in, what callbacks flow out
4. Mark server vs client boundary — default to server; only add `"use client"` when interactivity requires it
5. Extract shared patterns into composition components (slots, wrappers)

**Component tree from a typical page prototype:**

```
Page (Server Component)
├── Navbar (Client — has mobile menu toggle; CSS hover alone does not require Client)
│   ├── NavbarBrand (Server — static link)
│   ├── NavbarLinks (Server — static links)
│   └── NavbarAction (Server — button, but parent toggles mobile menu)
├── HeroSection (Server — static content)
│   ├── HeroHeading (Server)
│   ├── HeroDescription (Server)
│   └── HeroCta (Server — CSS hover/focus animation only)
├── FeatureGrid (Server — maps over data)
│   └── FeatureCard (Server — receives props)
└── Footer (Server — static content)
```

**Boundary correction:** CSS-only hover, focus, active, transition, and animation states do not require a Client Component. Add `"use client"` only for event handlers, React state/effects, browser APIs, imperative measurements, or third-party client-only code.

> For detailed decomposition walkthrough, see `references/component-decomposition-guide`.

### Stage 5: Dynamic Implementation

Replace static prototype content with props, state, and interactions. Add loading states, error boundaries, and accessibility attributes.

**Process:**

1. Replace hardcoded text/images with props
2. Add state management for interactive elements
3. Implement event handlers (click, submit, toggle)
4. Add loading and error states
5. Add ARIA attributes for accessibility
6. Delete the prototype page

**Static to dynamic transition example:**

```tsx
// BEFORE: Prototype (Stage 2)
<section className="flex flex-col items-center py-[--spacing-16] px-[--spacing-8]">
  <h1 className="text-[--font-size-heading-1] font-[--font-weight-heading] text-center">
    Build faster with modern tools
  </h1>
  <p className="text-[--font-size-body] text-[--color-text-secondary] mt-[--spacing-4]">
    Streamline your workflow with our integrated platform.
  </p>
</section>

// AFTER: Dynamic (Stage 5)
interface HeroSectionProps {
  heading: string
  description: string
  ctaLabel: string
  ctaHref: string
}

export default function HeroSection({ heading, description, ctaLabel, ctaHref }: HeroSectionProps) {
  return (
    <section
      className="flex flex-col items-center py-[--spacing-16] px-[--spacing-8]"
      aria-labelledby="hero-heading"
    >
      <h1 id="hero-heading" className="text-[--font-size-heading-1] font-[--font-weight-heading] text-center">
        {heading}
      </h1>
      <p className="text-[--font-size-body] text-[--color-text-secondary] mt-[--spacing-4] max-w-prose text-center">
        {description}
      </p>
      <a
        href={ctaHref}
        className="bg-[--color-primary] hover:bg-[--color-primary-hover] text-[--color-surface-elevated]
          px-[--spacing-8] py-[--spacing-3] rounded-[--radius-md] mt-[--spacing-8]
          text-[--font-size-body] font-[--font-weight-heading]"
        aria-label={ctaLabel}
      >
        {ctaLabel}
      </a>
    </section>
  )
}
```

## Decision Guides

### When to prototype vs componentize directly

| Situation | Approach |
|---|---|
| New page from full design spec | Always prototype first (Stage 2) |
| Single small component (button, badge) | Skip prototype, build component directly |
| Modifying existing component | Skip prototype, edit component directly |
| Complex layout with multiple breakpoints | Always prototype first |
| Unsure about spacing/alignment | Prototype the tricky section only |

### Variant vs separate component

| Situation | Approach |
|---|---|
| Same structure, different visual style | Single component with `variant` prop |
| Same structure, different data shape | Single component with generic props |
| Different structure, similar purpose | Separate components |
| Card with vs without image | Variant prop: `variant: "default" | "image"` |
| Primary vs secondary button | Variant prop: `variant: "primary" | "secondary"` |
| Navbar vs Sidebar | Separate components (different DOM structure) |

### Server vs client component boundary

| Situation | Component Type |
|---|---|
| Static content display | Server |
| Data fetching from server | Server (use async/await) |
| CSS hover/focus/active/transition only | Server |
| Interactive (click, toggle, form events) | Client |
| Uses browser APIs (window, localStorage) | Client |
| Uses React hooks (useState, useEffect) | Client |
| Maps over server-fetched data | Server |
| Wraps client children | Server (passes children as props) |

**Rule: Start with server. Add `"use client"` only when you must.** Server components reduce bundle size and enable streaming. Push the client boundary as far down the tree as possible — make the leaf interactive component a client component, keep its parent server.

## Anti-patterns

| Anti-pattern | Why | Correct |
|---|---|---|
| Skipping prototype stage | Visual mismatches compound when hidden behind component logic | Always prototype full pages first |
| Hardcoding pixel values (`p-[32px]`) | Drifts from design system, inconsistent spacing | Add a token to `@theme` and reference it |
| One monolithic page component | Hard to test, reuse, or refactor | Decompose into focused components |
| Everything as client components | Larger bundle, no streaming, slower TTI | Default to server; client only for interactivity |
| Copying Figma hex colors directly | No semantic meaning, impossible to theme | Define semantic tokens in `@theme` |
| Using `style={{ }}` for one-off values | Breaks Tailwind consistency | Add a theme token |
| Mixing Tailwind tokens with arbitrary values | `bg-[--color-primary]` next to `text-[#333]` | Consistent: all values via `@theme` tokens |
| Building components before verifying layout | Visual bugs discovered after props/state added | Prototype first, componentize second |
| Installing a UI library for copied CSS | Library DOM and theme APIs make later edits harder | Own the markup; scope and adapt the copied CSS |
| Global copied selectors | Leaks styles into unrelated components | Namespace or CSS Module before import |

## Component Scaffold

Use `templates/component-scaffold.tsx` as the starting point for every new component. It includes TypeScript interface, Tailwind `@theme` token references, ARIA attributes, and server/client declaration.

## Related Skills

- `tailwind-v4` — Tailwind v4 `@theme` configuration, utility classes, responsive design, custom variants
- `react-composition` — Component composition patterns, slots, compound components, children patterns
- `web-design-audit` — Auditing implemented pages against design specs for visual fidelity
- `nextjs-app-router` — App Router conventions, server/client component boundaries, data fetching

## Keywords

design-to-code, figma to react, design tokens, html prototyping, tailwind conversion, component decomposition, responsive implementation, design specification, mockup to component, OKLCH tokens
