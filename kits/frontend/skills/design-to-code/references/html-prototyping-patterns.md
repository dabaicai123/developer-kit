# HTML Prototyping Patterns

Common layout patterns for static HTML prototyping with Tailwind v4. Each pattern shows the raw design output before conversion and the Tailwind-styled prototype after.

## Navigation Bar

### Before (raw design CSS)

```html
<nav style="display: flex; justify-content: space-between; align-items: center; padding: 16px 32px; background-color: #FFFFFF; border-bottom: 1px solid #E5E7EB;">
  <div style="font-size: 18px; font-weight: 700; color: #111827;">Brand</div>
  <div style="display: flex; gap: 24px; align-items: center;">
    <a style="font-size: 14px; color: #6B7280;">Products</a>
    <a style="font-size: 14px; color: #6B7280;">About</a>
    <a style="font-size: 14px; color: #6B7280;">Blog</a>
    <button style="background-color: #2563EB; color: #FFFFFF; padding: 8px 16px; border-radius: 8px; font-size: 14px; font-weight: 700;">Sign Up</button>
  </div>
</nav>
```

### After (Tailwind prototype with theme tokens)

```tsx
<nav className="flex items-center justify-between px-[--spacing-8] py-[--spacing-4]
  bg-[--color-surface-elevated] border-b border-[--color-border]">
  <div className="text-[--font-size-heading-3] font-[--font-weight-heading] text-[--color-text]">Brand</div>
  <div className="flex items-center gap-[--spacing-6]">
    <a className="text-[--font-size-body] text-[--color-text-muted] hover:text-[--color-primary]">Products</a>
    <a className="text-[--font-size-body] text-[--color-text-muted] hover:text-[--color-primary]">About</a>
    <a className="text-[--font-size-body] text-[--color-text-muted] hover:text-[--color-primary]">Blog</a>
    <button className="bg-[--color-primary] text-[--color-surface-elevated]
      px-[--spacing-4] py-[--spacing-2] rounded-[--radius-md]
      text-[--font-size-body] font-[--font-weight-heading]
      hover:bg-[--color-primary-hover]">Sign Up</button>
  </div>
</nav>
```

### Responsive — mobile hamburger

```tsx
<nav className="flex items-center justify-between px-[--spacing-4] md:px-[--spacing-8] py-[--spacing-4]
  bg-[--color-surface-elevated] border-b border-[--color-border]">
  <div className="text-[--font-size-heading-3] font-[--font-weight-heading] text-[--color-text]">Brand</div>

  {/* Mobile menu button — visible only on small screens */}
  <button className="md:hidden text-[--color-text]"
    aria-label="Toggle navigation menu" aria-expanded="false">
    <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M4 6h16M4 12h16M4 18h16"/>
    </svg>
  </button>

  {/* Desktop links — hidden on small screens */}
  <div className="hidden md:flex items-center gap-[--spacing-6]">
    <a className="text-[--font-size-body] text-[--color-text-muted] hover:text-[--color-primary]">Products</a>
    <a className="text-[--font-size-body] text-[--color-text-muted] hover:text-[--color-primary]">About</a>
    <a className="text-[--font-size-body] text-[--color-text-muted] hover:text-[--color-primary]">Blog</a>
    <button className="bg-[--color-primary] text-[--color-surface-elevated]
      px-[--spacing-4] py-[--spacing-2] rounded-[--radius-md]
      text-[--font-size-body] font-[--font-weight-heading]
      hover:bg-[--color-primary-hover]">Sign Up</button>
  </div>
</nav>
```

## Hero Section

### Before (raw design CSS)

```html
<section style="display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 80px 32px; background-color: #F9FAFB; text-align: center;">
  <h1 style="font-size: 36px; font-weight: 700; color: #111827; max-width: 640px;">Build faster with modern tools</h1>
  <p style="font-size: 14px; color: #6B7280; margin-top: 16px; max-width: 480px;">Streamline your workflow with our integrated platform designed for speed and simplicity.</p>
  <div style="display: flex; gap: 16px; margin-top: 32px;">
    <button style="background-color: #2563EB; color: #FFFFFF; padding: 12px 32px; border-radius: 8px; font-size: 14px; font-weight: 700;">Get Started</button>
    <button style="background-color: #FFFFFF; color: #2563EB; padding: 12px 32px; border-radius: 8px; font-size: 14px; font-weight: 700; border: 1px solid #2563EB;">Learn More</button>
  </div>
</section>
```

### After (Tailwind prototype)

```tsx
<section className="flex flex-col items-center justify-center
  py-[--spacing-20] px-[--spacing-8]
  bg-[--color-surface-subtle] text-center">
  <h1 className="text-[--font-size-heading-1] font-[--font-weight-heading] text-[--color-text] max-w-prose">
    Build faster with modern tools
  </h1>
  <p className="text-[--font-size-body] text-[--color-text-muted] mt-[--spacing-4] max-w-[480px]">
    Streamline your workflow with our integrated platform designed for speed and simplicity.
  </p>
  <div className="flex gap-[--spacing-4] mt-[--spacing-8]">
    <button className="bg-[--color-primary] text-[--color-surface-elevated]
      px-[--spacing-8] py-[--spacing-3] rounded-[--radius-md]
      text-[--font-size-body] font-[--font-weight-heading]
      hover:bg-[--color-primary-hover]">Get Started</button>
    <button className="bg-[--color-surface-elevated] text-[--color-primary]
      px-[--spacing-8] py-[--spacing-3] rounded-[--radius-md]
      text-[--font-size-body] font-[--font-weight-heading]
      border border-[--color-primary]
      hover:bg-[--color-primary-light]">Learn More</button>
  </div>
</section>
```

## Card Grid Layout

### Before (raw design CSS)

```html
<div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 24px; padding: 48px 32px;">
  <div style="background-color: #FFFFFF; border: 1px solid #E5E7EB; border-radius: 12px; padding: 24px; box-shadow: 0 4px 6px rgba(0,0,0,0.07);">
    <div style="width: 48px; height: 48px; background-color: #EFF6FF; border-radius: 8px; display: flex; align-items: center; justify-content: center;">
      <svg style="width: 24px; height: 24px; color: #2563EB;">...</svg>
    </div>
    <h3 style="font-size: 18px; font-weight: 700; color: #111827; margin-top: 16px;">Feature One</h3>
    <p style="font-size: 14px; color: #6B7280; margin-top: 8px;">Description of feature one goes here.</p>
  </div>
  <!-- repeat for cards 2 and 3 -->
</div>
```

### After (Tailwind prototype)

```tsx
<div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-[--spacing-6]
  px-[--spacing-8] py-[--spacing-12]">
  <div className="bg-[--color-surface-elevated] border border-[--color-border]
    rounded-[--radius-lg] p-[--spacing-6] shadow-[--shadow-md]">
    <div className="w-12 h-12 bg-[--color-primary-light] rounded-[--radius-md]
      flex items-center justify-center">
      <svg className="w-6 h-6 text-[--color-primary]">...</svg>
    </div>
    <h3 className="text-[--font-size-heading-3] font-[--font-weight-heading]
      text-[--color-text] mt-[--spacing-4]">Feature One</h3>
    <p className="text-[--font-size-body] text-[--color-text-muted] mt-[--spacing-2]">
      Description of feature one goes here.
    </p>
  </div>
  {/* repeat for cards 2 and 3 */}
</div>
```

**Responsive grid:** `grid-cols-1` (mobile) → `md:grid-cols-2` (tablet) → `lg:grid-cols-3` (desktop). Always start from mobile and scale up.

## Form Layout

### Before (raw design CSS)

```html
<form style="max-width: 480px; margin: 0 auto; padding: 32px;">
  <div style="margin-bottom: 24px;">
    <label style="font-size: 14px; font-weight: 500; color: #111827; display: block; margin-bottom: 8px;">Email</label>
    <input type="email" style="width: 100%; padding: 12px 16px; border: 1px solid #E5E7EB; border-radius: 8px; font-size: 14px; color: #111827;" placeholder="Enter your email">
  </div>
  <div style="margin-bottom: 24px;">
    <label style="font-size: 14px; font-weight: 500; color: #111827; display: block; margin-bottom: 8px;">Password</label>
    <input type="password" style="width: 100%; padding: 12px 16px; border: 1px solid #E5E7EB; border-radius: 8px; font-size: 14px; color: #111827;" placeholder="Enter your password">
  </div>
  <button style="width: 100%; background-color: #2563EB; color: #FFFFFF; padding: 12px; border-radius: 8px; font-size: 14px; font-weight: 700;">Sign In</button>
</form>
```

### After (Tailwind prototype)

```tsx
<form className="max-w-[480px] mx-auto py-[--spacing-8]">
  <div className="mb-[--spacing-6]">
    <label className="text-[--font-size-body] font-[--font-weight-medium] text-[--color-text]
      block mb-[--spacing-2]">Email</label>
    <input type="email" placeholder="Enter your email"
      className="w-full px-[--spacing-4] py-[--spacing-3]
        border border-[--color-border] rounded-[--radius-md]
        text-[--font-size-body] text-[--color-text]
        focus:border-[--color-primary] focus:ring-1 focus:ring-[--color-primary]" />
  </div>
  <div className="mb-[--spacing-6]">
    <label className="text-[--font-size-body] font-[--font-weight-medium] text-[--color-text]
      block mb-[--spacing-2]">Password</label>
    <input type="password" placeholder="Enter your password"
      className="w-full px-[--spacing-4] py-[--spacing-3]
        border border-[--color-border] rounded-[--radius-md]
        text-[--font-size-body] text-[--color-text]
        focus:border-[--color-primary] focus:ring-1 focus:ring-[--color-primary]" />
  </div>
  <button className="w-full bg-[--color-primary] text-[--color-surface-elevated]
    py-[--spacing-3] rounded-[--radius-md]
    text-[--font-size-body] font-[--font-weight-heading]
    hover:bg-[--color-primary-hover]">Sign In</button>
</form>
```

## Flexbox Dashboard Sidebar + Main

### Before (raw design CSS)

```html
<div style="display: flex; min-height: 100vh;">
  <aside style="width: 240px; background-color: #111827; padding: 24px; display: flex; flex-direction: column;">
    <div style="font-size: 18px; font-weight: 700; color: #FFFFFF; margin-bottom: 32px;">Dashboard</div>
    <a style="font-size: 14px; color: #E5E7EB; padding: 8px; border-radius: 8px; margin-bottom: 4px;">Overview</a>
    <a style="font-size: 14px; color: #E5E7EB; padding: 8px; border-radius: 8px; margin-bottom: 4px; background-color: #1F2937;">Analytics</a>
    <a style="font-size: 14px; color: #E5E7EB; padding: 8px; border-radius: 8px; margin-bottom: 4px;">Settings</a>
  </aside>
  <main style="flex: 1; padding: 32px; background-color: #F9FAFB;">
    <h2 style="font-size: 24px; font-weight: 700; color: #111827;">Analytics Overview</h2>
    <p style="font-size: 14px; color: #6B7280; margin-top: 8px;">Your performance metrics for this month.</p>
  </main>
</div>
```

### After (Tailwind prototype)

```tsx
<div className="flex min-h-screen">
  {/* Sidebar */}
  <aside className="hidden lg:flex lg:w-[240px] lg:flex-col
    bg-[--color-text] p-[--spacing-6]">
    <div className="text-[--font-size-heading-3] font-[--font-weight-heading]
      text-[--color-surface-elevated] mb-[--spacing-8]">Dashboard</div>
    <a className="text-[--font-size-body] text-[--color-border]
      px-[--spacing-2] py-[--spacing-2] rounded-[--radius-md] mb-[--spacing-1]
      hover:bg-[--color-text-secondary]">Overview</a>
    <a className="text-[--font-size-body] text-[--color-border]
      px-[--spacing-2] py-[--spacing-2] rounded-[--radius-md] mb-[--spacing-1]
      bg-[--color-text-secondary]">Analytics</a>
    <a className="text-[--font-size-body] text-[--color-border]
      px-[--spacing-2] py-[--spacing-2] rounded-[--radius-md] mb-[--spacing-1]
      hover:bg-[--color-text-secondary]">Settings</a>
  </aside>

  {/* Main content */}
  <main className="flex-1 p-[--spacing-8] bg-[--color-surface-subtle]">
    <h2 className="text-[--font-size-heading-2] font-[--font-weight-heading] text-[--color-text]">
      Analytics Overview
    </h2>
    <p className="text-[--font-size-body] text-[--color-text-muted] mt-[--spacing-2]">
      Your performance metrics for this month.
    </p>
  </main>
</div>
```

**Mobile responsive:** Sidebar is `hidden lg:flex` — only visible on desktop. On mobile, use a slide-out overlay or bottom tab bar (implemented in Stage 5 with client component state).

## Responsive Breakpoint Strategy

| Breakpoint | Tailwind Prefix | Target |
|---|---|--- |
| < 640px | (default, no prefix) | Mobile phones |
| 640px+ | `sm:` | Large phones |
| 768px+ | `md:` | Tablets |
| 1024px+ | `lg:` | Laptops |
| 1280px+ | `xl:` | Desktops |

**Design for mobile first** — write base classes for mobile, then add responsive variants for larger screens:

```tsx
// Mobile: stacked layout, small padding
// Tablet: side-by-side, medium padding
// Desktop: wider, large padding
<div className="flex flex-col p-[--spacing-4] md:flex-row md:gap-[--spacing-6] md:p-[--spacing-8] lg:max-w-[1200px]">
```

## Common Responsive Pattern Transformations

| Mobile Layout | Desktop Layout | Tailwind Classes |
|---|---|---|
| Stack vertically | Side-by-side row | `flex flex-col md:flex-row` |
| Full-width cards | 2-col grid | `grid grid-cols-1 md:grid-cols-2` |
| 2-col grid | 3-col grid | `grid grid-cols-2 lg:grid-cols-3` |
| Hidden sidebar | Visible sidebar | `hidden lg:block` |
| Small padding | Large padding | `p-[--spacing-4] md:p-[--spacing-8]` |
| Small heading | Large heading | `text-[--font-size-heading-3] md:text-[--font-size-heading-1]` |
| Truncated text | Full text | `truncate md:whitespace-normal` |