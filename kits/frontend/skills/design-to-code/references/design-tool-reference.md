# Design Tool Reference

Quick reference for reading and interpreting output from Figma, ClaudeDesign, and OpenDesign. Each tool produces design specifications in a different format - this guide explains how to read each format and map properties to Tailwind v4 tokens.

## Figma

### Output Formats

Figma provides design data through several channels. The most common for design-to-code workflows:

**1. Figma Dev Mode - CSS Export**

Figma's Dev Mode panel shows CSS properties for selected elements. Copy values directly:

```css
/* Figma CSS export example */
.frame-123 {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 80px 32px 80px 32px;
  gap: 16px;
  background-color: #F9FAFB;
  border-radius: 12px;
}

.heading-1 {
  font-family: "Inter";
  font-size: 36px;
  font-weight: 700;
  line-height: 120%;
  letter-spacing: -0.02em;
  color: #111827;
}
```

**2. Figma Tailwind Plugin**

The Figma-to-Tailwind plugin (community plugin) attempts direct Tailwind class mapping. However, it often produces suboptimal output and may not align with your custom `@theme` tokens. Use it as a reference, not as the final output.

```html
<!-- Plugin output example - USE AS REFERENCE ONLY -->
<div class="flex flex-col items-center p-[80px_32px] gap-4 bg-gray-50 rounded-xl">
  <h1 class="font-Inter text-[36px] font-bold leading-[120%] tracking-tight text-gray-900">
```

Issues with plugin output:
- Uses default Tailwind color names (`gray-50`) instead of semantic tokens
- May use arbitrary values instead of scale tokens
- Doesn't account for responsive variants
- Doesn't distinguish between server/client needs

**3. Design Spec Documents (PDF/Notion)**

Design teams often export annotated specs with measurements, colors, and component states. These require manual reading - map each value to a `@theme` token.

### Figma Property Mapping

| Figma Property | Tailwind @theme Token | Tailwind Class |
|---|---|---|
| `Fill: #2563EB` | `--color-primary: oklch(0.55 0.18 250)` | `bg-primary` |
| `Stroke: 1px #E5E7EB` | `--color-border: oklch(0.88 0.01 250)` | `border border-border` |
| `Font: Inter / 36px / Bold` | `--text-heading-1: 2.25rem` + `--font-weight-heading: 700` | `text-heading-1 font-heading` |
| `Line height: 120%` | `--line-height-heading: 1.2` | `leading-heading` |
| `Letter spacing: -0.02em` | `--tracking-tight: -0.02em` | `tracking-tight` |
| `Spacing: 80px (top)` | `--spacing-20: 5rem` | `pt-20` |
| `Gap: 16px` | `--spacing-4: 1rem` | `gap-4` |
| `Border radius: 12px` | `--radius-lg: 0.75rem` | `rounded-lg` |
| `Effect: Drop shadow 4px 6px rgba(0,0,0,0.1)` | `--shadow-md` | `shadow-md` |
| `Opacity: 50%` | Use `oklch(0 0 0 / 0.5)` in shadow/color tokens | `bg-text/50` or token with opacity baked in |
| `Auto layout -> horizontal` | Flex row | `flex flex-row` |
| `Auto layout -> vertical` | Flex column | `flex flex-col` |
| `Auto layout -> gap: 16` | Gap | `gap-4` |
| `Auto layout -> padding: 24` | Padding | `p-6` |
| `Constraints: center` | Flex alignment | `items-center` / `justify-center` |
| `Fill container (width)` | Width | `w-full` |

### Figma-Specific Considerations

- **Auto Layout** maps directly to flexbox. Figma's "Auto Layout" panel is your flex reference - direction, gap, padding, alignment all translate to Tailwind flex utilities.
- **Components** in Figma represent reusable elements. Each Figma component variant should map to a React component with a `variant` prop.
- **Responsive** - Figma may have separate frames for each breakpoint. Read each frame independently and combine with responsive Tailwind prefixes.
- **Design tokens** - if the Figma team has defined design tokens in the Figma Tokens plugin, they map directly to `@theme` definitions. Token names may need renaming to match your semantic naming convention.

## ClaudeDesign

### Output Format

ClaudeDesign produces complete HTML/CSS as output. The format is production-quality HTML with embedded CSS styles, designed for direct browser rendering.

```html
<!-- ClaudeDesign output example -->
<div style="max-width: 1200px; margin: 0 auto; padding: 32px;">
  <nav style="display: flex; justify-content: space-between; align-items: center; padding: 16px 0;">
    <div style="font-size: 18px; font-weight: 700;">Acme Corp</div>
    <div style="display: flex; gap: 24px;">
      <a href="#" style="color: #4B5563; font-size: 14px;">Home</a>
      <a href="#" style="color: #4B5563; font-size: 14px;">Services</a>
      <a href="#" style="background-color: #2563EB; color: white; padding: 8px 16px; border-radius: 6px; font-size: 14px; font-weight: 600;">Contact</a>
    </div>
  </nav>
  <section style="text-align: center; padding: 96px 0;">
    <h1 style="font-size: 48px; font-weight: 700; color: #111827; letter-spacing: -0.02em;">Build Something Great</h1>
    <p style="font-size: 16px; color: #6B7280; margin-top: 16px; max-width: 600px; margin-left: auto; margin-right: auto;">
      Create applications faster with our platform.
    </p>
  </section>
</div>
```

### How to Read ClaudeDesign Output

ClaudeDesign output uses inline `style` attributes on every element. To convert:

1. **Extract each CSS property value** from inline styles
2. **Map to semantic tokens** using the token extraction guide
3. **Replace inline styles with Tailwind classes** referencing `@theme` tokens
4. **Add responsive variants** where the design implies responsive behavior

**ClaudeDesign conventions:**
- Colors are always in hex format (`#2563EB`, `#111827`) - convert to OKLCH
- Spacing values are in px (`32px`, `16px`) - convert to rem with spacing scale tokens
- Font sizes are in px (`48px`, `14px`) - convert to rem with typography scale tokens
- Layout uses flexbox (`display: flex`, `justify-content`, `gap`) - maps directly to Tailwind flex utilities
- `max-width` + `margin: 0 auto` - maps to `max-w-*` + `mx-auto` container utilities

### ClaudeDesign Conversion Example

```html
<!-- BEFORE: ClaudeDesign output -->
<section style="text-align: center; padding: 96px 0;">
  <h1 style="font-size: 48px; font-weight: 700; color: #111827; letter-spacing: -0.02em;">Build Something Great</h1>
  <p style="font-size: 16px; color: #6B7280; margin-top: 16px; max-width: 600px; margin-left: auto; margin-right: auto;">
    Create applications faster with our platform.
  </p>
</section>
```

```tsx
// AFTER: Tailwind prototype with @theme tokens
<section className="text-center py-24">
  <h1 className="text-heading-1 md:text-[3rem] font-heading
    text-text tracking-tight">Build Something Great</h1>
  <p className="text-body-large text-text-muted
    mt-4 max-w-[600px] mx-auto">
    Create applications faster with our platform.
  </p>
</section>
```

## OpenDesign

### Output Format

OpenDesign follows structured conventions for design specification output. The format combines CSS properties with design intent annotations.

```css
/* OpenDesign output example - structured CSS with design annotations */
/* @section: hero */
/* @responsive: mobile-stack / desktop-center */
.hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: var(--spacing-xl) var(--spacing-md);
  gap: var(--spacing-md);
  background: var(--color-surface-subtle);
}

.hero-title {
  font-size: var(--font-heading-1);
  font-weight: var(--font-weight-bold);
  color: var(--color-text-primary);
  text-align: center;
  max-width: var(--max-width-content);
}

.hero-actions {
  display: flex;
  gap: var(--spacing-sm);
  flex-wrap: wrap;
  justify-content: center;
}
```

### How to Read OpenDesign Output

OpenDesign output already uses CSS custom properties (variables) with semantic names. This makes token mapping more direct:

1. **OpenDesign variables map directly to `@theme` tokens** - the names may differ but the semantics align
2. **Design annotations** (`@section`, `@responsive`) provide decomposition and responsive guidance
3. **Responsive annotations** indicate breakpoint behavior - translate to Tailwind responsive prefixes

**OpenDesign variable mapping to @theme tokens:**

| OpenDesign Variable | @theme Token | Notes |
|---|---|---|
| `var(--color-text-primary)` | `--color-text` | Rename to shorter convention |
| `var(--color-text-secondary)` | `--color-text-secondary` | Same |
| `var(--color-surface-subtle)` | `--color-surface-subtle` | Same |
| `var(--color-surface-elevated)` | `--color-surface-elevated` | Same |
| `var(--spacing-xs)` | `--spacing-1` | Map to numeric scale |
| `var(--spacing-sm)` | `--spacing-2` | |
| `var(--spacing-md)` | `--spacing-4` | |
| `var(--spacing-lg)` | `--spacing-6` | |
| `var(--spacing-xl)` | `--spacing-8` | |
| `var(--spacing-2xl)` | `--spacing-12` | |
| `var(--font-heading-1)` | `--text-heading-1` | Rename to Tailwind text namespace |
| `var(--font-weight-bold)` | `--font-weight-heading` | Semantic name |
| `var(--radius-sm)` | `--radius-sm` | Same |
| `var(--radius-md)` | `--radius-md` | Same |

**Responsive annotation mapping:**

| OpenDesign Annotation | Tailwind Implementation |
|---|---|
| `@responsive: mobile-stack / desktop-center` | `flex flex-col lg:flex-row lg:items-center lg:justify-center` |
| `@responsive: mobile-full / desktop-half` | `w-full lg:w-1/2` |
| `@responsive: mobile-hide / desktop-show` | `hidden lg:block` |
| `@responsive: mobile-2col / desktop-3col` | `grid grid-cols-2 lg:grid-cols-3` |

### OpenDesign Conversion Example

```css
/* BEFORE: OpenDesign CSS output */
.hero {
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: var(--spacing-xl) var(--spacing-md);
  background: var(--color-surface-subtle);
}
```

```tsx
// AFTER: Tailwind prototype - OpenDesign variables map directly
<section className="flex flex-col items-center
  py-8 px-4
  bg-surface-subtle">
```

## Cross-Tool Comparison

| Aspect | Figma | ClaudeDesign | OpenDesign |
|---|---|---|---|
| Output format | CSS properties / Tailwind classes | HTML with inline styles | Structured CSS with variables |
| Color format | Hex (`#2563EB`) | Hex (`#2563EB`) | CSS variables (`var(--color-primary)`) |
| Spacing format | px values | px values | Semantic variables (`var(--spacing-md)`) |
| Layout info | Auto Layout panel | Inline flexbox CSS | Flexbox with variable references |
| Responsive info | Separate breakpoint frames | Single frame, implicit responsive | `@responsive` annotations |
| Component info | Figma Components panel | No explicit component hints | `@section` annotations |
| Token mapping | Manual: hex -> OKLCH -> semantic name | Manual: hex -> OKLCH -> semantic name | Direct: rename variables to @theme names |
| Easiest to convert | OpenDesign (already semantic) | ClaudeDesign (inline -> Tailwind) | Figma (requires reading Dev Mode) |

## Conversion Priority

When a design spec uses different naming from your `@theme` tokens:

1. **Always use your `@theme` token names** - never adopt the design tool's naming into your codebase
2. **Map values, not names** - `#2563EB` from any tool maps to your `--color-primary` token
3. **Normalize across tools** - if Figma calls it "Blue 600" and ClaudeDesign outputs `#2563EB`, both map to the same `--color-primary` token
4. **One token system, one naming convention** - your `@theme` is the canonical source, design tools are inputs that get normalized
