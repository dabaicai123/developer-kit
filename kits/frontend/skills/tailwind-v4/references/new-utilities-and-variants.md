# New Utilities and Variants in Tailwind v4

Reference guide for new CSS-native features: `@starting-style`, `not-*`, `in-*`, `nth-*`, `field-sizing`, `color-scheme`, and 3D transforms.

## @starting-style

The `starting` variant maps to the CSS `@starting-style` feature, enabling transitions on elements that are first rendered or become visible. This eliminates the need for JavaScript animation libraries for enter/exit transitions.

### Enter transitions

Set the initial state with `starting:` and the final state without. Combined with `transition-discrete`, the browser animates from the starting state to the final state on entry.

```tsx
// Popover with fade-in + scale-up
<div popover id="menu" className="
  opacity-100 scale-100
  transition-discrete
  starting:open:opacity-0 starting:open:scale-95
">
  Menu content
</div>
```

How it works:
- `starting:open:opacity-0` — defines the initial opacity (0) before the popover opens
- `opacity-100` — defines the final opacity (100%) after opening
- `transition-discrete` — enables transitions for discrete properties (opacity, transform)
- The browser transitions from `starting:` state to the final state

### Dialog enter transitions

```tsx
<dialog id="confirm-dialog" className="
  opacity-100 scale-100
  transition-discrete duration-300
  starting:open:opacity-0 starting:open:scale-95
  backdrop:bg-black/50
  backdrop:starting:open:bg-transparent
">
  Confirm action?
</dialog>
```

### Exit transitions

For exit transitions, apply `@starting-style` on the open state to define where the transition starts when the element closes:

```tsx
<div popover id="tooltip" className="
  opacity-100 scale-100
  transition-discrete duration-200
  starting:open:opacity-0 starting:open:scale-95
  open:starting:opacity-0 open:starting:scale-95
">
  Tooltip text
</div>
```

### Custom transition definitions

Define reusable transition patterns in `@theme`:

```css
@theme {
  --animate-fade-in: fade-in 0.3s ease-out;
  --animate-slide-up: slide-up 0.3s ease-out;

  @keyframes fade-in {
    0% { opacity: 0; }
    100% { opacity: 1; }
  }

  @keyframes slide-up {
    0% { transform: translateY(10px); opacity: 0; }
    100% { transform: translateY(0); opacity: 1; }
  }
}
```

Then use them in components:

```tsx
<div className="animate-fade-in">Content</div>
```

### Browser support

`@starting-style` is supported in Chrome 117+, Safari 17.4+, Firefox pending. For unsupported browsers, the element will still appear but without the transition.

## not-* Variant

Negates any variant condition. Style elements that do NOT match a given state, selector, or media query.

### Negating interactive states

```tsx
// Hover color, but not when focused (prevent hover + focus clash)
<button className="hover:not-focus:bg-primary-hover">
  Action
</button>

// Opacity reduction when NOT hovered
<div className="not-hover:opacity-80 hover:opacity-100 transition-opacity">

// Show text only when input is NOT disabled
<input className="peer" disabled={isDisabled} />
<span className="peer-not-disabled:inline hidden">Required</span>
```

### Negating structural pseudo-classes

```tsx
// Underline all list items except the last
<ul>
  <li className="not-last:border-b not-last:pb-2">Item 1</li>
  <li className="not-last:border-b not-last:pb-2">Item 2</li>
  <li>Item 3</li>  {/* last item: no border */}
</ul>

// Remove margin from first child
<div className="not-first:mt-4">Block 1</div>
<div className="not-first:mt-4">Block 2</div>

// Style elements that are NOT the active tab
<button className="not-active:bg-surface not-active:text-text-secondary">
  Tab
</button>
```

### Negating custom selectors

```tsx
// Style elements that are NOT inside a specific container
<div className="not-[.special_*]:bg-surface">

// Style elements that are NOT matching a media query
<div className="not-[@supports_(display:grid)]:block">
```

### Common patterns

```tsx
// Separator between items: add border to every item EXCEPT last
{items.map((item, i) => (
  <div key={i} className="not-last:border-b not-last:pb-4">
    {item}
  </div>
))}
```

## in-* Variant

Like `group-*` but without needing a `group` class on the parent. Targets the nearest ancestor that matches the variant condition. This eliminates the need to mark parent elements.

### Hover propagation from parent

```tsx
// Before (v3): required group class on parent
<div className="group bg-surface p-4">
  <span className="group-hover:text-primary">Highlighted</span>
</div>

// After (v4): no group class needed
<div className="bg-surface p-4">
  <span className="in-hover:text-primary">Highlighted</span>
</div>
```

### Focus propagation

```tsx
// Style label when parent input is focused
<div className="flex items-center gap-2">
  <input className="border-border focus:border-primary" />
  <label className="in-focus:text-primary">Search</label>
</div>
```

### Combining with other variants

```tsx
// Style when parent is both hovered and NOT disabled
<div>
  <span className="in-hover:in-not-disabled:text-primary">
    Highlighted on parent hover (unless parent is disabled)
  </span>
</div>
```

### When to use in-* vs group-*

| Situation | Approach |
|---|---|
| Single hover/focus cascade from immediate parent | `in-*` — simpler, no group class needed |
| Targeting a distant ancestor (not the nearest) | `group-*` with named groups — `group/sidebar` + `group-hover/sidebar:*` |
| Multiple different parent states on different children | `group-*` — more explicit control over which parent triggers which child |
| Simple card hover highlight | `in-hover:*` — no setup needed |

## nth-* Variant

Target elements by position using CSS `:nth-*` pseudo-classes.

### nth-even / nth-odd

```tsx
// Striped table rows
<table>
  <tr className="nth-even:bg-surface">...</tr>
  <tr>...</tr>
  <tr className="nth-even:bg-surface">...</tr>
</table>

// Alternating card colors
<div className="nth-odd:bg-primary-light nth-even:bg-surface">
  {cards.map(renderCard)}
</div>
```

### nth-first / nth-last

```tsx
// First item gets special treatment
<nav>
  <a className="nth-first:font-bold nth-first:text-primary">Home</a>
  <a>Products</a>
  <a>About</a>
</nav>
```

### Arbitrary nth patterns

```tsx
// Every 3rd item has a left border
<div className="nth-[3n+1]:border-l-primary">
  {items.map(renderItem)}
</div>

// First 3 items get extra padding
<div className="nth-[-n+3]:pb-8">
  {sections.map(renderSection)}
</div>
```

## field-sizing Utility

Auto-resize textareas based on content, without JavaScript. Sets the CSS `field-sizing` property.

```tsx
// Auto-sizing textarea — grows with content
<textarea className="field-sizing-content w-full border border-border rounded-md p-2" />

// Fixed textarea — standard fixed height
<textarea className="field-sizing-fixed w-full h-24 border border-border rounded-md p-2" />
```

`field-sizing-content` makes the textarea grow/shrink to match its content. No JavaScript resize handlers needed.

## color-scheme Utility

Control the color scheme for scrollbars, form controls, and other browser-native UI elements. This fixes the common problem of light scrollbars appearing in dark-mode pages.

```tsx
// Dark mode page with matching dark scrollbars
<div className="dark">
  <main className="scheme-dark">
    {/* Scrollbars, form controls, and native UI elements use dark theme */}
  </main>
</div>

// Light mode page
<main className="scheme-light">

// Inherit from parent
<main className="scheme-normal">
```

**Typical dark mode setup:**

```css
@custom-variant dark (&:is(.dark *));

/* In app/globals.css */
.dark {
  color-scheme: dark;
}
```

Or per-component:

```tsx
<div className="dark:bg-surface dark:scheme-dark">
  Content with dark scrollbars
</div>
```

## 3D Transform Utilities

v4 adds CSS 3D transform utilities for rotating, scaling, and translating elements in 3D space.

### Perspective

Set the perspective distance for 3D-transformed children:

```tsx
<div className="perspective-distant">   /* 1200px — subtle 3D effect */
  <div className="rotate-x-15 transform-3d">Content</div>
</div>

<div className="perspective-near">      /* 300px — dramatic 3D effect */
  <div className="rotate-y-20 transform-3d">Content</div>
</div>
```

Perspective scale:

| Utility | Value |
|---|---|
| `perspective-dramatic` | 100px |
| `perspective-near` | 300px |
| `perspective-normal` | 500px |
| `perspective-midrange` | 800px |
| `perspective-distant` | 1200px |

### 3D rotation

```tsx
// Rotate around X axis (tilt forward/back)
<div className="rotate-x-15 transform-3d">

// Rotate around Y axis (turn left/right)
<div className="rotate-y-20 transform-3d">

// Rotate around Z axis (spin)
<div className="rotate-z-45 transform-3d">
```

### 3D scale and translate

```tsx
// Scale in Z direction
<div className="scale-z-150 transform-3d">

// Translate in Z direction (push toward/away from viewer)
<div className="translate-z-4 transform-3d">
```

### transform-3d requirement

All 3D transform utilities require `transform-3d` on the same element to enable 3D rendering context. Without it, 3D transforms are flattened to 2D.

```tsx
// WRONG: rotate-x-15 without transform-3d will look flat
<div className="rotate-x-15">

// RIGHT: transform-3d enables the 3D rendering context
<div className="rotate-x-15 transform-3d">
```

### Card flip effect

```tsx
<div className="perspective-normal">
  <div className="group">
    <div className="relative h-64 w-48 transform-3d transition-transform duration-500 group-hover:rotate-y-180">
      {/* Front face */}
      <div className="backface-hidden absolute inset-0 bg-surface rounded-lg shadow-md">
        Front content
      </div>
      {/* Back face */}
      <div className="backface-hidden rotate-y-180 absolute inset-0 bg-surface-elevated rounded-lg shadow-md">
        Back content
      </div>
    </div>
  </div>
</div>
```

### Custom perspective values

```css
@theme {
  --perspective-100: 100px;
  --perspective-200: 200px;
}
```

Or use arbitrary values inline:

```tsx
<div className="perspective-[800px]">
```

## inert Variant

Style elements marked with the `inert` HTML attribute (non-interactive, unfocusable, hidden from accessibility tree).

```tsx
// Dim inert (disabled) sections
<section inert className="inert:opacity-50 inert:pointer-events-none">
  Disabled content
</section>
```

## descendant Variant

Style all descendant elements within a container (equivalent to `*` selector with a parent scope).

```tsx
// Set text color for all descendants
<div className="descendant:text-text-secondary">
  <p>All text here is secondary</p>
  <span>And this span too</span>
</div>
```

Use sparingly — descendant styles override specificity predictably only in simple structures. Avoid in deeply nested component trees.

## Summary: New Variants Quick Reference

| Variant | CSS equivalent | Purpose |
|---|---|---|
| `starting:` | `@starting-style` | Define initial state for enter/exit transitions |
| `not-*` | `:not()` | Negate any variant or selector |
| `in-*` | Parent state propagation without `group` class | Hover/focus cascade from nearest ancestor |
| `nth-*` | `:nth-child()`, `:nth-of-type()` | Position-based styling |
| `inert:` | `[inert]` selector | Style non-interactive elements |
| `descendant:` | Descendant `*` selector | Style all children/descendants |

## Summary: New Utilities Quick Reference

| Utility | CSS property | Purpose |
|---|---|---|
| `field-sizing-content` | `field-sizing: content` | Auto-resize textarea to match content |
| `field-sizing-fixed` | `field-sizing: fixed` | Standard fixed textarea height |
| `scheme-dark` | `color-scheme: dark` | Dark scrollbars and native controls |
| `scheme-light` | `color-scheme: light` | Light scrollbars and native controls |
| `scheme-normal` | `color-scheme: normal` | Inherit color scheme |
| `rotate-x-*` | 3D rotate around X axis | Tilt forward/back |
| `rotate-y-*` | 3D rotate around Y axis | Turn left/right |
| `rotate-z-*` | 3D rotate around Z axis | Spin |
| `scale-z-*` | 3D scale in Z direction | Depth scaling |
| `translate-z-*` | 3D translate in Z direction | Push toward/away from viewer |
| `transform-3d` | `transform-style: preserve-3d` | Enable 3D rendering context |
| `perspective-*` | `perspective` property | Set 3D perspective distance |
| `backface-hidden` | `backface-visibility: hidden` | Hide back face of 3D-transformed element |
