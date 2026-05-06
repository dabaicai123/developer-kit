# v3 to v4 Migration Guide

Key changes when migrating from Tailwind CSS v3 to v4. The automated upgrade tool handles most of this, but understanding the changes helps with edge cases.

## Automated Migration

Run the official upgrade tool first. It handles dependency updates, config migration, and template file changes:

```bash
npx @tailwindcss/upgrade@latest
```

After running, review the output for any cases the tool could not automatically migrate.

## Key Changes

### 1. CSS-first configuration (no JS config)

v3 used `tailwind.config.js` (or `.ts`). v4 uses `@theme` blocks in CSS.

**Before (v3):**

```js
// tailwind.config.js
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx}"],
  theme: {
    extend: {
      colors: {
        primary: "#3366CC",
        surface: "#F5F5F5",
      },
      fontFamily: {
        sans: ["Inter", "system-ui", "sans-serif"],
      },
    },
  },
  plugins: [],
};
```

**After (v4):**

```css
/* app/globals.css */
@import "tailwindcss";

@theme {
  --color-primary: oklch(0.55 0.18 250);
  --color-surface: oklch(0.98 0.01 250);
  --font-family-sans: Inter, system-ui, sans-serif;
}
```

**Legacy JS config** — if you cannot fully migrate, you can still load a JS config via the `@config` directive:

```css
@import "tailwindcss";
@config "./tailwind.config.js";
```

This is for backward compatibility only. New projects should use `@theme`.

### 2. Import syntax change

**Before (v3):**

```css
@tailwind base;
@tailwind components;
@tailwind utilities;
```

**After (v4):**

```css
@import "tailwindcss";
```

The single import includes base styles (preflight), the default theme, and all utility generators.

### 3. Content detection is automatic

v3 required a `content` array in the config to tell Tailwind which files to scan. v4 detects source files automatically based on your project structure. Remove the `content` config entirely.

### 4. PostCSS changes

v3 shipped as a PostCSS plugin (`tailwindcss`). v4 separates the PostCSS plugin into `@tailwindcss/postcss`:

**Before (v3):**

```js
// postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
};
```

**After (v4):**

```js
// postcss.config.js
module.exports = {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

Remove `postcss-import` and `autoprefixer` — v4 handles vendor prefixing and CSS imports internally.

For Next.js, if you use the built-in PostCSS support, update `postcss.config.mjs`:

```js
// postcss.config.mjs
export default {
  plugins: {
    "@tailwindcss/postcss": {},
  },
};
```

### 5. Color format: OKLCH

v4's default color palette uses OKLCH instead of RGB. This produces more vivid colors on P3-capable displays and perceptually uniform gradients.

When defining custom colors, use OKLCH:

```css
@theme {
  --color-brand: oklch(0.55 0.18 250);  /* NOT hex #3366CC */
}
```

Hex values still work in `@theme`, but OKLCH is preferred for:
- Perceptually uniform lightness ramps
- Better gradient interpolation
- Wider gamut on modern displays

### 6. Theme variable access

v3 used `theme()` in CSS and JS. v4 exposes all theme values as CSS variables:

**Before (v3):**

```css
.bg-brand {
  background-color: theme("colors.brand");
}
```

**After (v4):**

```css
.bg-brand {
  background-color: var(--color-brand);
}
```

In utility classes, theme tokens generate utilities automatically:

```html
<div class="bg-brand"> <!-- maps to --color-brand -->
```

### 7. Renamed utilities

| v3 class | v4 class | Notes |
|---|---|---|
| `bg-gradient-to-r` | `bg-linear-to-r` | All gradient directions renamed |
| `bg-gradient-to-t` | `bg-linear-to-t` | |
| `bg-gradient-to-b` | `bg-linear-to-b` | |
| `bg-gradient-to-br` | `bg-linear-to-br` | |
| `blur-sm` (filter) | `blur-sm` | No rename, but filter utilities refactored |
| `drop-shadow-sm` | `drop-shadow-sm` | No rename, but now a dedicated utility |

### 8. Default value changes

| Property | v3 default | v4 default | Migration note |
|---|---|---|---|
| Border color | `gray-200` | `currentColor` | If your design relied on gray borders, add `--default-border-color` or use explicit `border-gray-200` |
| Ring width | `3px` | `1px` | Add `--default-ring-width: 3px` to preserve v3 behavior |
| Ring color | `blue-500` | `currentColor` | Add `--default-ring-color: var(--color-blue-500)` to preserve v3 behavior |
| Shadow default | Multiple ring shadows | Simplified | Review shadow appearance after migration |

Preserve v3 defaults:

```css
@theme {
  --default-border-color: var(--color-gray-200);
  --default-ring-width: 3px;
  --default-ring-color: var(--color-blue-500);
}
```

### 9. Container queries built-in

The `@tailwindcss/container-queries` plugin is no longer needed — container queries are built into v4.

**Before (v3):**

```js
// tailwind.config.js
plugins: [require("@tailwindcss/container-queries")],
```

**After (v4):**

Remove the plugin. Container queries work with `@container` class and `@sm:*`, `@md:*` variants out of the box.

### 10. Removed/deprecated features

| Feature | Status | Replacement |
|---|---|---|
| `@tailwind` directives | Removed | `@import "tailwindcss"` |
| `content` config array | Removed | Auto-detection |
| `theme()` function (dot notation) | Changed | Use CSS variable names: `theme(--color-primary)` instead of `theme("colors.primary")` |
| `@apply` with custom variants in Vue/Svelte | Changed | Use CSS variables directly instead |
| `important` option | Removed | Use `!important` modifier on individual utilities if needed |
| `safelist` option | Removed | Use `@source` directive or `@theme static` |
| `separator` option | Removed | Always `:` |
| `prefix` in JS config | Changed | Use `@import "tailwindcss" prefix(tw)` in CSS |

### 11. New CSS directives

| Directive | Purpose |
|---|---|
| `@theme` | Define design tokens that generate CSS variables and utilities |
| `@plugin` | Load CSS-first plugins |
| `@custom-variant` | Define custom state variants (e.g., dark mode) |
| `@utility` | Define custom utility classes |
| `@source` | Explicitly include/exclude source paths |
| `@reference` | Import Tailwind config for type checking without generating utilities |

**Custom variant example (dark mode):**

```css
@import "tailwindcss";
@custom-variant dark (&:is(.dark *));
```

**Custom utility example:**

```css
@utility content-auto {
  content-visibility: auto;
  contain-intrinsic-size: auto 500px;
}
```

### 12. The `theme()` function

Still available in v4 but prefer CSS variables. When you must use `theme()` (e.g., in media queries where CSS variables don't work), use the CSS variable name format:

**Before (v3):**

```css
@media (min-width: theme("screens.md")) { ... }
```

**After (v4):**

```css
@media (min-width: theme(--breakpoint-md)) { ... }
```

## Browser Support

v4 targets modern browsers: Safari 16.4+, Chrome 111+, Firefox 128+. It depends on CSS features like `@property`, `color-mix()`, and native cascade layers. If you need older browser support, stay on v3.4.

## Migration Checklist

- [ ] Run `npx @tailwindcss/upgrade@latest`
- [ ] Replace `@tailwind` directives with `@import "tailwindcss"`
- [ ] Convert `tailwind.config.js` to `@theme` blocks in CSS
- [ ] Remove `content` config (auto-detection)
- [ ] Remove `postcss-import` and `autoprefixer` from PostCSS config
- [ ] Switch PostCSS plugin from `tailwindcss` to `@tailwindcss/postcss`
- [ ] Update gradient class names (`bg-gradient-*` to `bg-linear-*`)
- [ ] Review border/ring defaults (changed from gray-200/blue-500 to currentColor)
- [ ] Remove `@tailwindcss/container-queries` plugin (built-in)
- [ ] Convert custom colors to OKLCH format
- [ ] Replace `theme()` dot notation with CSS variable name syntax
- [ ] Check for `@apply` usage that might need CSS variable replacement
- [ ] Remove `important`, `safelist`, `separator` options from config
- [ ] Test visual output at all breakpoints
- [ ] Update VSCode settings: add `files.associations` mapping `*.css` to `tailwindcss`