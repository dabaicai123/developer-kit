# Audit Criteria

Full criteria with pass/fail examples and WCAG reference numbers.

## Visual Hierarchy

### VH-01: Single focal point per section

**Criterion**: Each visible section has one primary focal point that draws the eye first.

| Result | Example |
|---|---|
| **Pass** | Hero section: large headline + single CTA button. Card: title is largest, action is primary-colored. |
| **Fail** | Hero with equally-sized headline, subtitle, image, and two buttons competing for attention. Card with title, subtitle, badge, and action all at same visual weight. |

**Fix**: Reduce competing elements. Make primary content 2x larger or bolder than secondary. Use color only for the primary action.

### VH-02: Primary action visually distinct

**Criterion**: The main action on each page/screen is immediately identifiable through size, color, or position.

| Result | Example |
|---|---|
| **Pass** | "Submit" button: filled blue, 48px height, right-aligned. "Cancel": outlined gray, smaller, left-aligned. |
| **Fail** | Submit and Cancel buttons same size, same color (just different text). |

**Fix**: Primary button = filled, high contrast color, larger. Secondary = outlined or text-only.

### VH-03: Heading hierarchy logical

**Criterion**: Heading levels follow a strict h1 > h2 > h3 hierarchy. No skipping levels.

| Result | Example |
|---|---|
| **Pass** | h1 (page title), h2 (section titles), h3 (subsection titles). |
| **Fail** | h1 then h3 (skip h2). Two h1 on a single page. h4 without h3 parent. |

**Fix**: Use exactly one h1 per page. Follow strict descending order.

## Layout

### LA-01: Consistent spacing scale

**Criterion**: Spacing uses a defined scale (e.g., 4, 8, 16, 24, 32, 48, 64px). No arbitrary values.

| Result | Example |
|---|---|
| **Pass** | All gaps and paddings use `gap-4`, `p-6`, `mt-8` (Tailwind scale). |
| **Fail** | `margin-top: 13px`, `padding: 7px 11px` (arbitrary pixel values). |

**Fix**: Use Tailwind spacing utilities exclusively. Map custom values to the nearest scale step.

### LA-02: Alignment consistency

**Criterion**: All elements within a group align to the same axis (left, center, right, or grid lines).

| Result | Example |
|---|---|
| **Pass** | All card content left-aligned. Form labels aligned on the same grid column. |
| **Fail** | Some labels left-aligned, some centered. Button group with mixed alignment. |

**Fix**: Pick one alignment per group. Stick to it.

### LA-03: Content width readability

**Criterion**: Body text columns are 45-75 characters wide (roughly 600-800px at 16px font).

| Result | Example |
|---|---|
| **Pass** | Article content in `max-w-prose` (65ch). Form inputs reasonable width. |
| **Fail** | Full-width text spanning 1200px. Tiny 200px column for paragraph text. |

**Fix**: Use `max-w-prose` or `max-w-2xl` for body text. Restrict form widths with `max-w-md`.

## Typography

### TY-01: Minimum font size

**Criterion**: Body text is at least 16px (1rem). No text below 12px (0.75rem), and small text only for labels/captions.

| Result | Example |
|---|---|
| **Pass** | Body: 16px. Captions/labels: 14px. Minimum: 12px only for timestamps or metadata. |
| **Fail** | Body text at 14px. Navigation labels at 11px. Any text below 12px. |

**WCAG Ref**: 1.4.4 Resize Text (AA) - text must be resizable to 200% without loss of content.

### TY-02: Line height

**Criterion**: Body text line height is 1.5-1.8. Headings line height is 1.1-1.3.

| Result | Example |
|---|---|
| **Pass** | Body: `leading-relaxed` (1.625). Headings: `leading-tight` (1.25). |
| **Fail** | Body: `leading-none` (1.0) - lines overlap. Headings: `leading-loose` (2.0) - excessive spacing. |

**WCAG Ref**: 1.4.12 Text Spacing (AA) - users must be able to increase line height to 1.5.

### TY-03: Font family count

**Criterion**: Maximum 2 font families (one for headings, one for body). Maximum 4 weight variations.

| Result | Example |
|---|---|
| **Pass** | Inter for body (400, 600), Playfair Display for headings (700). |
| **Fail** | 4 different fonts: one for body, one for headings, one for nav, one for quotes. |

**Fix**: Choose one sans-serif for body + UI, optionally one display font for headings only.

## Color

### CO-01: Text contrast ratio

**Criterion**: Normal text contrast ratio >= 4.5:1 against background. Large text (>= 18pt or 14pt bold) >= 3:1.

| Result | Example |
|---|---|
| **Pass** | Dark gray (#1F2937) on white: 15.4:1. Blue (#2563EB) on white: 6.7:1. |
| **Fail** | Light gray (#9CA3AF) on white: 2.9:1 (below 4.5:1). Medium gray (#6B7280) on light gray (#F3F4F6): 3.1:1 (borderline). |

**WCAG Ref**: 1.4.3 Contrast (Minimum) (AA) - 4.5:1 for normal text, 3:1 for large text.

**Testing**: Use browser dev tools or https://webaim.org/resources/contrastchecker/

### CO-02: Color not sole indicator

**Criterion**: State, status, or meaning is conveyed through more than color alone. Use icons, text, patterns, or shape as secondary indicators.

| Result | Example |
|---|---|
| **Pass** | Error state: red border + error icon + "Error" text. Required field: red asterisk + "(required)" label. |
| **Fail** | Error state: only red text. Required field: only red border. Success: only green background. |

**WCAG Ref**: 1.4.1 Use of Color (A) - color must not be the only visual means of conveying information.

### CO-03: Semantic color consistency

**Criterion**: Colors are used semantically and consistently across the entire application.

| Result | Example |
|---|---|
| **Pass** | Red always means error/danger. Green always means success. Blue always means primary action/information. Yellow always means warning. |
| **Fail** | Red for error on one page, red for "popular" on another. Blue for primary here, blue for "inactive" there. |

**Fix**: Define a color semantic map and enforce it via Tailwind theme tokens.

## Interaction

### IN-01: Hover and focus states

**Criterion**: Every interactive element (links, buttons, inputs) has visible hover and focus states.

| Result | Example |
|---|---|
| **Pass** | Button: hover shows background change, focus shows blue ring (`focus-visible:ring-2`). Link: hover shows underline. |
| **Fail** | Button: no visual change on hover. Link: no focus indicator. Input: no focus ring. |

**WCAG Ref**: 2.4.7 Focus Visible (AA) - all interactive elements must have a visible focus indicator.

**Fix**: Use `focus-visible:ring-2 ring-blue-500 ring-offset-2` on all interactive elements.

### IN-02: Loading feedback

**Criterion**: Actions that take more than 200ms show a loading indicator. Actions over 1s show progress or skeleton.

| Result | Example |
|---|---|
| **Pass** | Submit button: shows spinner after 200ms. Page load: skeleton placeholders. Data fetch: "Loading..." text or spinner. |
| **Fail** | Submit button stays static for 3s. No feedback during data fetch. Blank space during page transition. |

**Fix**: Button: `disabled + spinner` during pending state. Page: Suspense fallback with skeleton. Data: TanStack Query `isLoading` state.

### IN-03: Error states near context

**Criterion**: Error messages appear near the relevant element, not in a generic location.

| Result | Example |
|---|---|
| **Pass** | Form field error below the input. Toast for background errors. Inline error next to the failed action. |
| **Fail** | All errors in a banner at the top. Error modal for a single field issue. Error summary without field highlighting. |

**WCAG Ref**: 3.3.1 Error Identification (A) - errors must be identified in text and associated with the element.

**Fix**: Use React Hook Form's field-level errors. Use `aria-describedby` to link error text to the input.

## Accessibility

### AC-01: Image alt text

**Criterion**: Every meaningful image has descriptive alt text. Decorative images have `alt=""`.

| Result | Example |
|---|---|
| **Pass** | `<img alt="Product photo: blue running shoes on white background">`. Decorative pattern: `<img alt="" role="presentation">`. |
| **Fail** | `<img>` (no alt). `<img alt="image">` (non-descriptive). `<img alt="Product">` (too vague). |

**WCAG Ref**: 1.1.1 Non-text Content (A).

### AC-02: Form labels

**Criterion**: Every form input has an associated label (via `<label>` + `for`, `aria-label`, or `aria-labelledby`).

| Result | Example |
|---|---|
| **Pass** | `<label for="email">Email</label><input id="email" />`. `<input aria-label="Search" />` for icon-only search. |
| **Fail** | `<input placeholder="Email" />` (placeholder is not a label). Input with no label at all. |

**WCAG Ref**: 1.3.1 Info and Relationships (A), 4.1.2 Name, Role, Value (A).

### AC-03: Keyboard navigation

**Criterion**: All interactive elements are reachable via keyboard. Tab order follows logical reading order. No keyboard traps.

| Result | Example |
|---|---|
| **Pass** | Tab through page reaches all links, buttons, inputs in reading order. Modal traps focus correctly (tab stays inside). Escape closes modal. |
| **Fail** | Dropdown opens on hover only (no keyboard trigger). Modal with no way to close via keyboard. Tab order jumps randomly. |

**WCAG Ref**: 2.1.1 Keyboard (A), 2.1.2 No Keyboard Trap (A), 2.4.3 Focus Order (A).

### AC-04: aria-live for dynamic content

**Criterion**: Dynamic content updates (notifications, search results, form errors) use `aria-live` regions.

| Result | Example |
|---|---|
| **Pass** | `<div aria-live="polite">3 results found</div>` for search results count. `<div aria-live="assertive">Form submitted successfully</div>` for critical updates. |
| **Fail** | Search results update visually but no aria announcement. Error message appears with no screen reader notification. |

**WCAG Ref**: 4.1.3 Status Messages (AA).

## Responsive

### RE-01: Mobile layout at 320px

**Criterion**: The layout works correctly at 320px viewport width (smallest common mobile). No horizontal overflow.

| Result | Example |
|---|---|
| **Pass** | Single column layout at 320px. Navigation collapses to hamburger. Tables become card lists. |
| **Fail** | 3-column grid at 320px (columns too narrow). Fixed-width sidebar at 200px causing overflow. Text overflowing container. |

**Fix**: Use responsive breakpoints (`md:grid-cols-3` defaults to single column). Use `overflow-x-auto` for tables. Set `max-w-full` on images.

### RE-02: Touch targets

**Criterion**: All interactive elements have a minimum touch target of 44x44px (WCAG) or 48x48dp (Material).

| Result | Example |
|---|---|
| **Pass** | Button: `px-4 py-2` (48px+ height). Icon button: `p-3` (48px padding around 24px icon). Link in text: `py-2` padding. |
| **Fail** | Icon-only button with `p-1` (24px total). Small text link with no padding. Checkbox at native size (16x16px). |

**WCAG Ref**: 2.5.5 Target Size (AAA) - minimum 44x44px. 2.5.8 Target Size (Minimum) (AA) - minimum 24x24px with spacing.

**Fix**: Add padding to reach minimum size. Use `min-h-[44px] min-w-[44px]` on icon buttons.

### RE-03: Content reflows, not shrinks

**Criterion**: At breakpoints, content reorganizes layout (stack columns, change navigation) rather than just scaling down.

| Result | Example |
|---|---|
| **Pass** | Desktop: 3-column grid. Mobile: single column stack. Desktop: sidebar + main. Mobile: collapsed nav + full-width main. |
| **Fail** | Same 3-column grid at 320px, just smaller text and narrower columns. Sidebar shrinks to 100px instead of collapsing. |

**Fix**: Use `grid-cols-1 md:grid-cols-2 lg:grid-cols-3`. Hide sidebar on mobile with `hidden md:block`.