# @theme Setup Guide

Complete guide to configuring Tailwind v4 `@theme` blocks with OKLCH palettes, semantic naming, and token hierarchy.

## @theme Directive

The `@theme` directive defines design tokens that generate both CSS variables and utility classes. Place it in your main CSS file after the Tailwind import.

```css
@import "tailwindcss";

@theme {
  /* All tokens go here */
}
```

**Key behaviors:**
- Tokens defined in `@theme` become CSS variables on `:root` and generate matching utility classes
- Namespace prefixes (`--color-*`, `--text-*`, etc.) determine which utilities are created
- Define tokens top-level — never nest under selectors or media queries
- Use `@theme inline { ... }` when referencing other variables (resolves the reference at compile time)
- Use `@theme static { ... }` to force all CSS variables into output even if unused

### Resetting defaults

Replace the entire default color palette with your own:

```css
@theme {
  --color-*: initial;  /* removes all default colors (red-500, blue-500, etc.) */

  /* Define only the colors your project uses */
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
  --color-warning: oklch(0.75 0.15 80);
}
```

Reset everything and start from scratch:

```css
@theme {
  --*: initial;  /* removes all default theme tokens */

  --spacing: 4px;
  --font-family-sans: Inter, sans-serif;
  --color-primary: oklch(0.55 0.18 250);
  /* ... only your tokens */
}
```

### Sharing across projects

Extract shared tokens into a separate CSS file for monorepo setups:

```css
/* packages/brand/theme.css */
@theme {
  --color-primary: oklch(0.55 0.18 250);
  --color-text: oklch(0.22 0.02 250);
  --font-family-sans: Inter, sans-serif;
}
```

```css
/* packages/admin/app/globals.css */
@import "tailwindcss";
@import "../brand/theme.css";
```

## OKLCH Palette Generation

OKLCH (`oklch(L C H)`) separates lightness, chroma, and hue into independent channels. This produces palettes where equal L-steps feel equally distant to human perception — unlike hex/RGB where green-to-yellow looks like a jump while navy-to-blue feels like a crawl.

### Format

```
oklch(L C H)

L: lightness  — 0 (black) to 1 (white)
C: chroma     — 0 (gray) to ~0.4 (max saturated); typical palette range 0.02-0.25
H: hue angle  — 0-360 (0=red, 120=green, 250=blue, etc.)
```

### Generating a palette from a base color

1. Start with your base color (the "500" level). Convert from hex if needed.
2. Lock the hue (H) constant across all shades.
3. Step lightness (L) in even increments across the 50-950 range.
4. Taper chroma (C) — peak at mid-range (400-600), reduce at extremes.

**Example: Blue palette (H=250)**

| Step | L | C | Result |
|---|---|---|---|
| 50 | 0.97 | 0.02 | `oklch(0.97 0.02 250)` — near-white tint |
| 100 | 0.93 | 0.05 | `oklch(0.93 0.05 250)` |
| 200 | 0.85 | 0.10 | `oklch(0.85 0.10 250)` |
| 300 | 0.75 | 0.15 | `oklch(0.75 0.15 250)` |
| 400 | 0.65 | 0.18 | `oklch(0.65 0.18 250)` |
| 500 | 0.55 | 0.18 | `oklch(0.55 0.18 250)` — base |
| 600 | 0.48 | 0.18 | `oklch(0.48 0.18 250)` |
| 700 | 0.40 | 0.15 | `oklch(0.40 0.15 250)` |
| 800 | 0.32 | 0.10 | `oklch(0.32 0.10 250)` |
| 900 | 0.25 | 0.06 | `oklch(0.25 0.06 250)` — near-black shade |

### Hex-to-OKLCH conversion

Use one of these methods:
- Browser DevTools color picker (select OKLCH display mode)
- oklch.com web tool
- PostCSS plugin `@csstools/postcss-oklch` for automatic conversion
- JavaScript: `new CSSColorValue("oklch", ...)` or colorjs.io library

**Manual conversion heuristic** (approximate, for quick prototyping):

```
For a color like #3366CC (medium blue):
1. Estimate hue: blue ≈ H 250
2. Estimate lightness: medium ≈ L 0.55
3. Estimate chroma: moderate saturation ≈ C 0.18
4. Refine by comparing with oklch.com or DevTools
Result: oklch(0.55 0.18 250)
```

### Palette naming conventions

For semantic-first naming (recommended):

```css
@theme {
  --color-primary: oklch(0.55 0.18 250);        /* base action color */
  --color-primary-hover: oklch(0.48 0.18 250);   /* hover state */
  --color-primary-light: oklch(0.85 0.10 250);   /* light variant for badges/banners */
  --color-primary-dark: oklch(0.32 0.10 250);    /* dark variant for headers */
}
```

For scale-based naming (when the design spec has a full palette):

```css
@theme {
  --color-primary-50: oklch(0.97 0.02 250);
  --color-primary-100: oklch(0.93 0.05 250);
  --color-primary-200: oklch(0.85 0.10 250);
  --color-primary-300: oklch(0.75 0.15 250);
  --color-primary-400: oklch(0.65 0.18 250);
  --color-primary-500: oklch(0.55 0.18 250);
  --color-primary-600: oklch(0.48 0.18 250);
  --color-primary-700: oklch(0.40 0.15 250);
  --color-primary-800: oklch(0.32 0.10 250);
  --color-primary-900: oklch(0.25 0.06 250);
}
```

Use semantic-first for most projects. Use scale-based when you need fine-grained palette access (e.g., data visualization with many shades).

## Token Hierarchy

Organize tokens in this order in your `@theme` block: colors, typography, spacing, borders, shadows. This matches the dependency direction — colors are referenced by shadows, spacing by borders, etc.

```css
@theme {
  /* 1. Colors — foundation of everything */
  --color-*: initial;
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
  --color-warning: oklch(0.75 0.15 80);

  /* 2. Typography — referenced by component text styles */
  --font-family-sans: Inter, system-ui, sans-serif;
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
  --leading-tight: 1.25;
  --leading-normal: 1.5;
  --leading-relaxed: 1.625;

  /* 3. Spacing — referenced by padding, margins, gaps */
  --spacing: 0.25rem; /* base unit = 4px; p-4 = 16px */

  /* 4. Borders — referenced by cards, inputs, dividers */
  --radius-sm: 0.25rem;
  --radius-md: 0.375rem;
  --radius-lg: 0.5rem;
  --radius-xl: 0.75rem;
  --radius-full: 9999px;

  /* 5. Shadows — referenced by cards, dropdowns, modals */
  --shadow-sm: 0 1px 2px 0 oklch(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px oklch(0 0 0 / 0.1), 0 2px 4px -2px oklch(0 0 0 / 0.1);
  --shadow-lg: 0 10px 15px -3px oklch(0 0 0 / 0.1), 0 4px 6px -4px oklch(0 0 0 / 0.1);
  --shadow-xl: 0 20px 25px -5px oklch(0 0 0 / 0.1), 0 8px 10px -6px oklch(0 0 0 / 0.1);

  /* 6. Breakpoints — referenced by responsive variants */
  --breakpoint-sm: 40rem;
  --breakpoint-md: 48rem;
  --breakpoint-lg: 64rem;
  --breakpoint-xl: 80rem;
  --breakpoint-2xl: 96rem;

  /* 7. Animations */
  --animate-fade-in: fade-in 0.3s ease-out;
  @keyframes fade-in {
    0% { opacity: 0; transform: scale(0.95); }
    100% { opacity: 1; transform: scale(1); }
  }
}
```

### Spacing scale

v4 uses a single `--spacing` variable as the base unit. All spacing utilities (`p-*`, `m-*`, `gap-*`, etc.) multiply this value:

```css
@theme {
  --spacing: 0.25rem; /* p-1 = 4px, p-4 = 16px, p-8 = 32px */
}
```

To add specific spacing values outside the default scale:

```css
@theme {
  --spacing-18: 4.5rem;   /* now p-18 = 72px */
  --spacing-88: 22rem;    /* now p-88 = 352px */
}
```

### Animation keyframes in @theme

Define keyframes inside `@theme` alongside the `--animate-*` token:

```css
@theme {
  --animate-slide-up: slide-up 0.3s ease-out;

  @keyframes slide-up {
    0% { transform: translateY(10px); opacity: 0; }
    100% { transform: translateY(0); opacity: 1; }
  }
}
```

If you need keyframes always included regardless of usage, define them outside `@theme`:

```css
@keyframes pulse-ring {
  0% { transform: scale(0.8); opacity: 0.5; }
  100% { transform: scale(1.3); opacity: 0; }
}
```

### Dark mode tokens

Define dark overrides using the `@custom-variant` directive and a separate `@theme` block:

```css
@import "tailwindcss";
@custom-variant dark (&:is(.dark *));

@theme {
  --color-text: oklch(0.22 0.02 250);
  --color-surface: oklch(0.98 0.01 250);
}

@theme dark {
  --color-text: oklch(0.90 0.01 250);
  --color-surface: oklch(0.15 0.01 250);
}
```

This generates `dark:text-text`, `dark:bg-surface`, etc. that automatically swap tokens when the `.dark` class is on a parent element.