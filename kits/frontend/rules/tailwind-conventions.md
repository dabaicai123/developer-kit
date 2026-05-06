---
paths:
  - "**/*.css"
  - "**/*.tsx"
---

# Rule: Tailwind v4 Conventions

Enforce consistent Tailwind CSS v4 patterns. For detailed patterns, use `tailwind-v4` skill.

## Guidelines

1. **Define tokens with `@theme` using OKLCH** — use `@theme` in CSS to define color, spacing, and typography tokens. Use OKLCH color space for perceptual uniformity. Never use `tailwind.config.js` in Tailwind v4 — the config file is removed.

2. **Use semantic token naming** — `--color-primary`, `--color-surface`, `--color-danger` not `--color-blue-500`, `--color-gray-100`, `--color-red-600`. Tokens describe purpose, not appearance. Appearance changes via theme redefinition, not code changes.

3. **Reference tokens in component classes** — `bg-[--color-primary]`, `text-[--color-on-surface]`, `border-[--color-border]`. Reference semantic tokens, never hardcoded utility values like `bg-blue-500`.

4. **Use `tv()` only for genuine variants** — `tv()` from `tailwind-variants` is for components with multiple visual variants (primary/secondary/danger button sizes). Single-variant components use plain class strings. Do not wrap every component in `tv()`.

5. **Use `@starting-style` for transitions** — use `@starting-style` for CSS entry transitions (fade-in, slide-in) since CSS transitions only animate on property changes, not initial render. This is the Tailwind v4 approach for transition-from-zero patterns.

6. **Mobile-first responsive design** — write base styles for mobile, then add `sm:`, `md:`, `lg:`, `xl:` for larger screens. Never start with desktop styles and scale down with `max-sm:` or `max-md:`.

## Anti-Patterns

- `tailwind.config.js` in Tailwind v4 — configuration lives in CSS `@theme` blocks
- Hardcoded color utilities (`bg-blue-500`, `text-gray-700`) — always use semantic token references
- Color-specific token names (`--color-blue-500`) — tokens must be semantic (`--color-primary`)
- `tv()` overuse on single-variant components — only use for genuine multi-variant components
- Desktop-first responsive design (`max-sm:`, `max-md:`) — always mobile-first
- JavaScript-based theme configuration — Tailwind v4 uses CSS-first configuration