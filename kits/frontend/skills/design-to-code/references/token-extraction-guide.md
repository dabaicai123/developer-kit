# Design Token Extraction Guide

How to extract design tokens from design specifications and define them as semantic tokens in Tailwind v4's `@theme` block.

## Extraction Process

1. Scan the design spec for all visual property values
2. Group values by category (color, typography, spacing, etc.)
3. Normalize values to consistent formats (OKLCH for colors, rem for sizes)
4. Assign semantic names that describe purpose, not appearance
5. Define tokens in `@theme` block in `app/globals.css`

## Color Tokens

### Hex to OKLCH Conversion

Tailwind v4 recommends OKLCH for better perceptual uniformity and wider gamut support. Use a converter tool or the reference table below.

**Common hex values to OKLCH:**

| Hex | OKLCH | Semantic Name (example) |
|---|---|---|
| `#000000` | `oklch(0 0 0)` | `--color-text` |
| `#111827` | `oklch(0.22 0.02 250)` | `--color-text` (gray-900) |
| `#1F2937` | `oklch(0.27 0.02 250)` | `--color-text-secondary` (gray-800) |
| `#374151` | `oklch(0.35 0.02 250)` | `--color-text-tertiary` (gray-700) |
| `#6B7280` | `oklch(0.45 0.02 250)` | `--color-text-muted` (gray-500) |
| `#9CA3AF` | `oklch(0.55 0.02 250)` | `--color-text-placeholder` (gray-400) |
| `#E5E7EB` | `oklch(0.88 0.01 250)` | `--color-border` (gray-200) |
| `#F3F4F6` | `oklch(0.93 0.01 250)` | `--color-surface` (gray-100) |
| `#F9FAFB` | `oklch(0.96 0.01 250)` | `--color-surface-subtle` (gray-50) |
| `#FFFFFF` | `oklch(1.0 0 0)` | `--color-surface-elevated` |
| `#2563EB` | `oklch(0.55 0.18 250)` | `--color-primary` (blue-600) |
| `#3B82F6` | `oklch(0.60 0.18 250)` | `--color-primary-light` (blue-500) |
| `#1D4ED8` | `oklch(0.48 0.18 250)` | `--color-primary-hover` (blue-700) |
| `#DC2626` | `oklch(0.55 0.22 25)` | `--color-error` (red-600) |
| `#16A34A` | `oklch(0.55 0.17 145)` | `--color-success` (green-600) |
| `#CA8A04` | `oklch(0.60 0.15 85)` | `--color-warning` (yellow-600) |

**For values not in the table**, use an online OKLCH converter or the CSS `oklch()` function with calculated values. The key formula: OKLCH separates lightness (L), chroma (C), and hue (H), giving perceptually uniform color manipulation.

### Semantic Naming Rules

Name tokens by **purpose**, not by appearance:

```css
/* WRONG — appearance-based names */
--color-blue-600: oklch(0.55 0.18 250);
--color-gray-100: oklch(0.93 0.01 250);

/* RIGHT — purpose-based names */
--color-primary: oklch(0.55 0.18 250);
--color-surface: oklch(0.93 0.01 250);
```

Semantic names enable re-theming without touching component code. Change `--color-primary` from blue to purple, and every reference updates.

**Common semantic color token set:**

| Token | Purpose |
|---|---|
| `--color-primary` | Main interactive color (buttons, links) |
| `--color-primary-hover` | Hover state of primary |
| `--color-primary-light` | Background tint of primary |
| `--color-secondary` | Secondary interactive color |
| `--color-surface` | Page/card background |
| `--color-surface-elevated` | Elevated card/modal background |
| `--color-surface-subtle` | Subtle section background |
| `--color-text` | Primary text color |
| `--color-text-secondary` | Supporting/description text |
| `--color-text-muted` | Placeholder/disabled text |
| `--color-border` | Default border color |
| `--color-border-strong` | Emphasized border |
| `--color-error` | Error state |
| `--color-success` | Success state |
| `--color-warning` | Warning state |

## Typography Scale

### Token Definition

Define font sizes as semantic names matching the design's type hierarchy:

```css
@theme {
  --font-family-sans: "Inter", system-ui, sans-serif;
  --font-family-mono: "JetBrains Mono", monospace;

  /* Type scale — semantic names */
  --font-size-heading-1: 2.25rem;      /* 36px — page title */
  --font-size-heading-2: 1.5rem;       /* 24px — section title */
  --font-size-heading-3: 1.125rem;     /* 18px — card/component title */
  --font-size-body: 0.875rem;          /* 14px — default body text */
  --font-size-body-large: 1rem;        /* 16px — emphasized body */
  --font-size-caption: 0.75rem;        /* 12px — labels, metadata */
  --font-size-overline: 0.625rem;      /* 10px — tiny labels */

  /* Font weights */
  --font-weight-heading: 700;
  --font-weight-body: 400;
  --font-weight-medium: 500;
  --font-weight-bold: 700;

  /* Line heights — paired with size tokens */
  --line-height-heading: 1.2;
  --line-height-body: 1.5;
  --line-height-caption: 1.4;
}
```

### Figma/ClaudeDesign Property Mapping

| Design Tool Property | Tailwind @theme Token | Tailwind Class |
|---|---|---|
| `font-size: 36px` | `--font-size-heading-1: 2.25rem` | `text-[--font-size-heading-1]` |
| `font-weight: Bold (700)` | `--font-weight-heading: 700` | `font-[--font-weight-heading]` |
| `font-family: Inter` | `--font-family-sans: "Inter", ...` | `font-[--font-family-sans]` |
| `line-height: 120%` | `--line-height-heading: 1.2` | `leading-[--line-height-heading]` |
| `letter-spacing: -0.02em` | `--tracking-tight: -0.02em` | `tracking-[--tracking-tight]` |

## Spacing Scale

Define spacing tokens on a **4px base unit** (0.25rem). This aligns with Tailwind's default scale and ensures visual consistency.

```css
@theme {
  /* Spacing — 4px grid */
  --spacing-0: 0;
  --spacing-1: 0.25rem;    /* 4px */
  --spacing-2: 0.5rem;     /* 8px */
  --spacing-3: 0.75rem;    /* 12px */
  --spacing-4: 1rem;       /* 16px */
  --spacing-5: 1.25rem;    /* 20px */
  --spacing-6: 1.5rem;     /* 24px */
  --spacing-8: 2rem;       /* 32px */
  --spacing-10: 2.5rem;    /* 40px */
  --spacing-12: 3rem;      /* 48px */
  --spacing-16: 4rem;      /* 64px */
  --spacing-20: 5rem;      /* 80px */
  --spacing-24: 6rem;      /* 96px */
  --spacing-32: 8rem;      /* 128px */
}
```

**When a design value falls between scale points**, pick the nearest scale value. If the visual difference is noticeable, add a new spacing token rather than using an arbitrary value.

| Design Value | Nearest Token | If Gap Is Too Large |
|---|---|---|
| 14px | `--spacing-3` (12px) or `--spacing-4` (16px) | Add `--spacing-3.5: 0.875rem` |
| 22px | `--spacing-5` (20px) or `--spacing-6` (24px) | Add `--spacing-5.5: 1.375rem` |
| 28px | `--spacing-6` (24px) or `--spacing-8` (32px) | Add `--spacing-7: 1.75rem` |

## Border Radius

```css
@theme {
  --radius-none: 0;
  --radius-sm: 0.25rem;     /* 4px — small elements */
  --radius-md: 0.5rem;      /* 8px — buttons, inputs */
  --radius-lg: 0.75rem;     /* 12px — cards */
  --radius-xl: 1rem;        /* 16px — modals, large cards */
  --radius-2xl: 1.5rem;     /* 24px — hero sections */
  --radius-full: 9999px;    /* circular — avatars, pills */
}
```

| Design Value | Token | Tailwind Class |
|---|---|---|
| 4px | `--radius-sm` | `rounded-[--radius-sm]` |
| 8px | `--radius-md` | `rounded-[--radius-md]` |
| 12px | `--radius-lg` | `rounded-[--radius-lg]` |
| 16px | `--radius-xl` | `rounded-[--radius-xl]` |
| circle/pill | `--radius-full` | `rounded-[--radius-full]` |

## Shadows

Define shadows using OKLCH for the shadow color, ensuring they adapt to theme changes:

```css
@theme {
  --shadow-none: none;
  --shadow-sm: 0 1px 2px oklch(0 0 0 / 0.05);
  --shadow-md: 0 4px 6px -1px oklch(0 0 0 / 0.07), 0 2px 4px -2px oklch(0 0 0 / 0.05);
  --shadow-lg: 0 10px 15px -3px oklch(0 0 0 / 0.1), 0 4px 6px -4px oklch(0 0 0 / 0.05);
  --shadow-xl: 0 20px 25px -5px oklch(0 0 0 / 0.1), 0 8px 10px -6px oklch(0 0 0 / 0.05);
  --shadow-inner: inset 0 2px 4px oklch(0 0 0 / 0.05);
}
```

| Design Value | Token | Tailwind Class |
|---|---|---|
| Subtle card elevation | `--shadow-sm` | `shadow-[--shadow-sm]` |
| Standard card elevation | `--shadow-md` | `shadow-[--shadow-md]` |
| Dropdown/popover elevation | `--shadow-lg` | `shadow-[--shadow-lg]` |
| Modal overlay elevation | `--shadow-xl` | `shadow-[--shadow-xl]` |

## Token Naming Convention

Follow these naming rules for all tokens:

1. **Prefix by category:** `--color-*`, `--font-*`, `--spacing-*`, `--radius-*`, `--shadow-*`
2. **Use semantic names:** `--color-primary` not `--color-blue-600`
3. **Use kebab-case:** `--color-text-secondary` not `--colorTextSecondary`
4. **Suffix states:** `--color-primary-hover`, `--color-primary-active`, `--color-primary-disabled`
5. **Suffix size levels:** `--font-size-heading-1`, `--font-size-heading-2` (numbered hierarchy)
6. **Suffix intensity:** `--color-border`, `--color-border-strong`, `--color-surface-subtle`

## Verification Checklist

After defining tokens, verify:

- [ ] Every color in the design spec has a corresponding semantic token
- [ ] All colors are in OKLCH format (no hex, no rgb)
- [ ] Font sizes cover the entire type hierarchy from the spec
- [ ] Spacing tokens follow the 4px grid (or have explicit intermediate values)
- [ ] Border radius tokens cover all component types in the spec
- [ ] Shadow tokens cover all elevation levels in the spec
- [ ] No hardcoded values remain in Tailwind class usage — all reference tokens
- [ ] Token names are semantic (purpose-based), not appearance-based