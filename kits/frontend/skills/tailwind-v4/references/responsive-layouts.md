# Responsive Layouts in Tailwind v4

Mobile-first responsive patterns, breakpoint customization, container queries, and grid/flex layout patterns for Next.js + Tailwind v4 projects.

## Mobile-First Approach

Tailwind v4 uses mobile-first breakpoints. Unprefixed utilities apply at all sizes. Prefixed utilities (`sm:`, `md:`, `lg:`, etc.) override at that breakpoint and above.

```tsx
// Mobile: stacked. Tablet+: side-by-side.
<div className="flex flex-col md:flex-row md:gap-8">
  <div className="w-full md:w-1/3">Sidebar</div>
  <div className="w-full md:w-2/3">Content</div>
</div>
```

**Critical rule:** Do not use `sm:` to target mobile. Use unprefixed utilities for mobile, then override at `sm:`, `md:`, etc.

```tsx
// WRONG: sm: targets 640px+, not mobile
<div className="sm:text-center">

// RIGHT: unprefixed for mobile, sm: for 640px+
<div className="text-center sm:text-left">
```

## Default Breakpoints

| Breakpoint | Min width | Typical device |
|---|---|---|
| `sm` | 40rem (640px) | Large phones / small tablets |
| `md` | 48rem (768px) | Tablets |
| `lg` | 64rem (1024px) | Laptops |
| `xl` | 80rem (1280px) | Desktops |
| `2xl` | 96rem (1536px) | Large desktops |

## Breakpoint Customization

Override or add breakpoints in `@theme`:

```css
@theme {
  --breakpoint-xs: 30rem;    /* new breakpoint */
  --breakpoint-3xl: 120rem;  /* new breakpoint */
  --breakpoint-md: 52rem;    /* override default md */
}
```

Remove a default breakpoint:

```css
@theme {
  --breakpoint-2xl: initial;  /* removes 2xl breakpoint */
}
```

Reset all defaults and define custom breakpoints:

```css
@theme {
  --breakpoint-*: initial;
  --breakpoint-tablet: 48rem;
  --breakpoint-laptop: 64rem;
  --breakpoint-desktop: 80rem;
}
```

Use custom breakpoints in markup:

```html
<div class="xs:grid-cols-2 3xl:grid-cols-6">
```

## Max-Width Breakpoint Ranges

Stack a breakpoint variant with `max-*` to limit styles to a specific range:

```tsx
// Only applies between md (48rem) and xl (80rem)
<div className="md:max-xl:flex">
```

Available max-width variants:

| Variant | Condition |
|---|---|
| `max-sm` | Width < 40rem |
| `max-md` | Width < 48rem |
| `max-lg` | Width < 64rem |
| `max-xl` | Width < 80rem |
| `max-2xl` | Width < 96rem |

Target a single breakpoint:

```tsx
// Only applies at md (between 48rem and 64rem)
<div className="md:max-lg:grid-cols-3">
```

## Container Queries

Container queries style elements based on their parent container's width, not the viewport. This makes components more reusable across different page layouts.

### Basic container query

Mark an element as a container with `@container`, then use `@sm:*`, `@md:*` variants on children:

```tsx
<div className="@container">
  <div className="flex flex-col @md:flex-row @md:gap-4">
    <div className="@md:w-1/2">Left</div>
    <div className="@md:w-1/2">Right</div>
  </div>
</div>
```

### Container query sizes

| Variant | Min container width |
|---|---|
| `@3xs` | 16rem (256px) |
| `@2xs` | 18rem (288px) |
| `@xs` | 20rem (320px) |
| `@sm` | 24rem (384px) |
| `@md` | 28rem (448px) |
| `@lg` | 32rem (512px) |
| `@xl` | 36rem (576px) |
| `@2xl` | 42rem (672px) |
| `@3xl` | 48rem (768px) |
| `@4xl` | 56rem (896px) |
| `@5xl` | 64rem (1024px) |
| `@6xl` | 72rem (1152px) |
| `@7xl` | 80rem (1280px) |

### Max-width container queries

```tsx
<div className="@container">
  <div className="flex flex-row @max-md:flex-col">
    <!-- switches to column when container is < 28rem -->
  </div>
</div>
```

### Container query ranges

```tsx
<div className="@container">
  <div className="flex flex-row @sm:@max-md:flex-col">
    <!-- column layout only when container is 24rem-28rem -->
  </div>
</div>
```

### Named containers

For nested container scenarios, name containers and target them specifically:

```tsx
<div className="@container/main">
  <div className="@container/sidebar">
    <!-- sidebar styles respond to sidebar container -->
    <div className="@sm/sidebar:bg-surface">
      <!-- targets @container/sidebar, not @container/main -->
    </div>
  </div>

  <!-- main content styles respond to main container -->
  <div className="@md/main:grid-cols-3">
    <!-- targets @container/main -->
  </div>
</div>
```

### Custom container sizes

```css
@theme {
  --container-8xl: 96rem;
}
```

```html
<div class="@container">
  <div class="@8xl:flex-row">
```

### Arbitrary container values

```tsx
<div className="@container">
  <div className="@min-[475px]:flex-row @max-[960px]:flex-col">
```

### Container query units

Reference container dimensions in other utilities using `cqw` (container query width):

```tsx
<div className="@container">
  <div className="w-[50cqw]">  <!-- 50% of container width -->
  </div>
</div>
```

## Grid Patterns

### Responsive grid with auto-fit columns

```tsx
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-4">
  {items.map((item) => (
    <Card key={item.id} {...item} />
  ))}
</div>
```

### Grid with named areas

```tsx
<div className="
  grid
  grid-cols-1
  md:grid-cols-[1fr_3fr]
  md:grid-rows-[auto_1fr_auto]
  md:grid-template-areas-[header_header sidebar_content footer_footer]
  gap-4
">
  <div className="md:[grid-area:header]">Header</div>
  <div className="md:[grid-area:sidebar]">Sidebar</div>
  <div className="md:[grid-area:content]">Content</div>
  <div className="md:[grid-area:footer]">Footer</div>
</div>
```

### Grid with arbitrary column ratios

```tsx
<div className="grid grid-cols-[2fr_1fr] gap-4">
  <div>Main (2/3)</div>
  <div>Sidebar (1/3)</div>
</div>
```

### Dashboard grid with responsive areas

```tsx
<div className="grid gap-4 p-4 md:grid-cols-2 lg:grid-cols-4">
  <div className="md:col-span-2 lg:col-span-4">Stats Overview</div>
  <div className="lg:col-span-2">Chart 1</div>
  <div className="lg:col-span-2">Chart 2</div>
  <div className="md:col-span-2">Table</div>
</div>
```

## Flex Patterns

### Responsive flex direction

```tsx
<div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
  <h2 className="text-xl">Title</h2>
  <div className="flex gap-2">
    <Button variant="outline" size="sm">Cancel</Button>
    <Button variant="primary" size="sm">Save</Button>
  </div>
</div>
```

### Flex with wrap for variable content

```tsx
<div className="flex flex-wrap gap-2">
  {tags.map((tag) => (
    <Badge key={tag}>{tag}</Badge>
  ))}
</div>
```

### Flex with grow/shrink control

```tsx
<div className="flex gap-4">
  <div className="shrink-0 w-48">Sidebar</div>
  <div className="grow min-w-0">Content</div>
</div>
```

### Sticky sidebar layout

```tsx
<div className="flex gap-6">
  <aside className="shrink-0 w-64 lg:sticky lg:top-4 lg:self-start">
    Navigation
  </aside>
  <main className="grow min-w-0">
    Content
  </main>
</div>
```

## Spacing Patterns

### Container with responsive padding

```tsx
<div className="px-4 sm:px-6 lg:px-8 max-w-7xl mx-auto">
  <section className="py-8 sm:py-12 lg:py-16">
    Content
  </section>
</div>
```

### Responsive gap scaling

```tsx
<div className="grid gap-2 sm:gap-4 lg:gap-6">
  {items.map(renderItem)}
</div>
```

### Section spacing with semantic tokens

```tsx
<section className="py-8 md:py-12 lg:py-16">
  Content
</section>
```

## Arbitrary Values for Breakpoints

For one-off breakpoint sizes not worth adding to `@theme`:

```tsx
<div className="min-[320px]:text-center max-[600px]:bg-surface">
```

## Responsive Strategy Decision Guide

| Situation | Approach |
|---|---|
| Layout changes at standard breakpoints | Use `sm:`, `md:`, `lg:` variants |
| Component adapts to parent container width | Use container queries (`@container`, `@md:*`) |
| One-off breakpoint size | Use `min-[Xpx]:` or `max-[Xpx]:` arbitrary variants |
| Target a specific breakpoint range only | Stack `md:max-lg:` variants |
| Layout for a specific context (sidebar vs full-page) | Named container queries (`@container/sidebar`) |
| Fluid scaling without breakpoints | Use `clamp()` in arbitrary values or `fluid-tailwindcss` plugin |

## Anti-patterns

| Pattern | Problem | Fix |
|---|---|---|
| Using `sm:` for mobile styles | `sm:` means 640px+, not mobile | Use unprefixed classes for mobile |
| Copying breakpoint values in multiple places | Hard to update, inconsistent | Define `--breakpoint-*` tokens in `@theme` |
| Container queries for viewport-level layouts | Container queries are for component-level adaptation | Use regular breakpoints for page-level layouts |
| `@container` on every element | Only mark elements that need their width tracked | Add `@container` only to wrapper elements whose children need size awareness |
| Mixing viewport breakpoints and container queries for the same component | Confusion about what drives responsive behavior | Use viewport breakpoints for page layout; container queries for component internals |