---
name: web-design-audit
description: Audit categories for visual hierarchy, layout, typography, color, interaction, accessibility, and responsive design. Checklist-based approach for reviewing web UIs.
version: "1.0.0"
type: skill
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# Web Design Audit

Structured checklist for auditing web UI quality across 7 categories.

## When to Use This Skill

- Reviewing a page or component before shipping
- Auditing an existing UI for quality issues
- Creating a design quality checklist for a team
- Evaluating designs against accessibility standards

## Audit Categories

| Category | Key Checks |
|---|---|
| **Visual hierarchy** | Clear heading structure, emphasis on primary actions, no competing focal points |
| **Layout** | Consistent spacing, alignment, grid adherence, no orphan elements |
| **Typography** | Font size scale, line height, contrast, no wall-of-text |
| **Color** | Sufficient contrast ratios, consistent palette, semantic use of color |
| **Interaction** | Clear affordances, hover/focus states, loading feedback, error states |
| **Accessibility** | WCAG 2.1 AA compliance, keyboard navigation, screen reader support |
| **Responsive** | Mobile-first, no broken layouts at breakpoints, touch targets |

## Quick Checklist

### Visual Hierarchy
- [ ] One clear focal point per section
- [ ] Primary action is visually distinct (size, color, position)
- [ ] Heading levels follow a logical hierarchy (h1 > h2 > h3)
- [ ] Important content is above the fold
- [ ] No more than 3 levels of visual emphasis on a single page

### Layout
- [ ] Consistent spacing scale (4/8/16/24/32px)
- [ ] All elements aligned to grid lines
- [ ] No orphan elements (labels without inputs, buttons without context)
- [ ] Content width respects readability limits (45-75 characters)
- [ ] Adequate whitespace between sections

### Typography
- [ ] Base font size at least 16px
- [ ] Line height 1.5-1.8 for body text
- [ ] Font weight used for hierarchy (regular body, bold headings)
- [ ] No more than 2 font families
- [ ] Short paragraphs (3-5 lines max)

### Color
- [ ] Text contrast ratio at least 4.5:1 (WCAG AA)
- [ ] Large text contrast ratio at least 3:1
- [ ] Color is not the only indicator of state (use icons/text too)
- [ ] Consistent palette with semantic colors (success=green, error=red)
- [ ] Dark mode contrast also meets minimum ratios

### Interaction
- [ ] All interactive elements have hover/focus/active states
- [ ] Buttons and links are visually distinguishable
- [ ] Loading states shown for async operations
- [ ] Error states near the relevant element, not generic
- [ ] Disabled states clearly different from enabled states

### Accessibility
- [ ] All images have alt text (decorative images: alt="")
- [ ] Form inputs have associated labels
- [ ] Focus order follows logical reading order
- [ ] Keyboard users can reach all interactive elements
- [ ] aria-live regions for dynamic content updates
- [ ] No auto-playing media without user control

### Responsive
- [ ] Mobile layout works at 320px width
- [ ] Touch targets at least 44x44px
- [ ] No horizontal scroll on mobile
- [ ] Content reflows at breakpoints, not just shrinks
- [ ] Navigation adapts (hamburger or bottom nav on mobile)

## Audit Process

1. **Open the page** at multiple widths (320px, 768px, 1024px, 1440px)
2. **Run axe-core** or Lighthouse accessibility audit
3. **Check each category** against the checklist above
4. **Document issues** with: category, severity (critical/major/minor), location, recommendation
5. **Prioritize**: critical (blocks users) > major (degrades experience) > minor (polish)

## Severity Definitions

| Severity | Definition | Example |
|---|---|---|
| **Critical** | Blocks a user group from completing a task | No keyboard access to main action, contrast 2:1 |
| **Major** | Significantly degrades experience for some users | Missing focus styles, no loading indicator on 3s+ action |
| **Minor** | Polish issue, doesn't block or degrade | Inconsistent spacing, slightly below contrast ratio |

## Related Skills

- **design-to-code**: Translating designs to code with audit criteria baked in
- **tailwind-v4**: Spacing, typography, and color utilities
- **react-composition**: Building accessible compound components

## References

- [audit-criteria](references/audit-criteria.md) - Full criteria with pass/fail examples and WCAG references