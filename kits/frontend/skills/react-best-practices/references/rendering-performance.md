# Rendering Performance

Rules for optimizing DOM rendering, layout stability, and visual performance. DOM rendering costs compound quickly with long lists and layout instability.

---

## Rule 1: Virtualization for Long Lists

Rendering 1000 DOM nodes when only 20 are visible wastes layout, paint, and memory. Use virtualization for lists over 100 items.

**Bad (renders all 1000 items as DOM nodes):**

```tsx
function UserList({ users }: { users: User[] }) {
  return (
    <div className="overflow-y-auto h-screen">
      {users.map(user => (
        <div key={user.id} className="p-4 border-b">
          <img src={user.avatar} className="w-12 h-12 rounded-full" />
          <div>
            <p className="font-semibold">{user.name}</p>
            <p className="text-sm text-gray-500">{user.email}</p>
          </div>
        </div>
      ))}
    </div>
  )
}
```

1000 users = 1000 DOM nodes, 1000 layout calculations, 1000 paint operations. Most are off-screen.

**Good (virtualizes with @tanstack/react-virtual):**

```tsx
import { useVirtualizer } from '@tanstack/react-virtual'

function UserList({ users }: { users: User[] }) {
  const parentRef = useRef<HTMLDivElement>(null)

  const virtualizer = useVirtualizer({
    count: users.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 80, // Estimated row height
    overscan: 5, // Render 5 extra rows above/below viewport
  })

  return (
    <div ref={parentRef} className="overflow-y-auto h-screen">
      <div
        style={{
          height: `${virtualizer.getTotalSize()}px`,
          width: '100%',
          position: 'relative',
        }}
      >
        {virtualizer.getVirtualItems().map(virtualItem => (
          <div
            key={virtualItem.key}
            style={{
              position: 'absolute',
              top: 0,
              left: 0,
              width: '100%',
              height: `${virtualItem.size}px`,
              transform: `translateY(${virtualItem.start}px)`,
            }}
          >
            <div className="p-4 border-b">
              <img
                src={users[virtualItem.index].avatar}
                className="w-12 h-12 rounded-full"
              />
              <div>
                <p className="font-semibold">
                  {users[virtualItem.index].name}
                </p>
                <p className="text-sm text-gray-500">
                  {users[virtualItem.index].email}
                </p>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
```

Only ~25 DOM nodes exist at any time (visible + overscan). Layout/paint cost drops from 1000 to 25.

---

## Rule 2: content-visibility: auto for Non-Virtualized Lists

When virtualization is not feasible (simple lists, card grids), use CSS `content-visibility: auto` to defer off-screen rendering.

**Tailwind v4 custom utility:**

```css
/* In your CSS file (Tailwind v4 @theme or app.css) */
.content-auto {
  content-visibility: auto;
  contain-intrinsic-size: 0 80px; /* Estimated height */
}
```

**Usage:**

```tsx
function MessageList({ messages }: { messages: Message[] }) {
  return (
    <div className="overflow-y-auto h-screen">
      {messages.map(msg => (
        <div key={msg.id} className="content-auto p-4 border-b">
          <Avatar user={msg.author} />
          <div>{msg.content}</div>
        </div>
      ))}
    </div>
  )
}
```

For 1000 messages, the browser skips layout/paint for ~990 off-screen items. `contain-intrinsic-size: 0 80px` tells the browser the estimated height so the scrollbar is correct.

This is simpler than virtualization but less effective. Use it when: lists are moderate length (50-500), items have consistent height, virtualization setup is too complex for the use case.

---

## Rule 3: Prevent Layout Shifts with Explicit Dimensions

Layout shifts (CLS) occur when content appears and pushes other content down. Always reserve space for async content and images.

**Bad (images without dimensions cause shifts):**

```tsx
function Article({ article }: { article: Article }) {
  return (
    <div>
      <img src={article.imageUrl} alt={article.title} />
      {/* Image loads, pushes text down — CLS spike */}
      <h2>{article.title}</h2>
      <p>{article.excerpt}</p>
    </div>
  )
}
```

**Good (next/image enforces dimensions):**

```tsx
import Image from 'next/image'

function Article({ article }: { article: Article }) {
  return (
    <div>
      <Image
        src={article.imageUrl}
        alt={article.title}
        width={800}
        height={400}
        sizes="(max-width: 768px) 100vw, 50vw"
        priority={article.isFeatured}
      />
      <h2>{article.title}</h2>
      <p>{article.excerpt}</p>
    </div>
  )
}
```

`next/image` reserves exact space. The image loads into its reserved slot without pushing content.

### Skeleton Fallbacks for Async Content

**Bad (content appears, pushes other content):**

```tsx
function Dashboard() {
  const { data, isLoading } = useQuery({ queryKey: ['stats'], queryFn: fetchStats })

  return (
    <div>
      {isLoading ? null : <StatsPanel data={data} />}
      {/* Stats appears suddenly, pushes everything below */}
      <OtherContent />
    </div>
  )
}
```

**Good (skeleton reserves exact space):**

```tsx
function Dashboard() {
  const { data, isLoading } = useQuery({ queryKey: ['stats'], queryFn: fetchStats })

  return (
    <div>
      {isLoading ? (
        <div className="animate-pulse h-24 bg-gray-200 rounded-lg" />
      ) : (
        <StatsPanel data={data} />
      )}
      <OtherContent />
    </div>
  )
}
```

The skeleton reserves the exact height (h-24) that `StatsPanel` will occupy. No shift when data loads.

---

## Rule 4: Explicit Conditional Rendering

Use ternaries for conditional rendering when the condition can be `0`, `NaN`, or other falsy values that render as text. Never use `&&` with numeric conditions.

**Bad (renders "0" when count is 0):**

```tsx
function Badge({ count }: { count: number }) {
  return (
    <div>
      {count && <span className="badge">{count}</span>}
    </div>
  )
}
// When count = 0: renders <div>0</div>
// When count = 5: renders <div><span class="badge">5</span></div>
```

`0` is falsy but React renders it as the text "0". `NaN` renders as "NaN".

**Good (renders nothing when count is 0):**

```tsx
function Badge({ count }: { count: number }) {
  return (
    <div>
      {count > 0 ? <span className="badge">{count}</span> : null}
    </div>
  )
}
// When count = 0: renders <div></div>
// When count = 5: renders <div><span class="badge">5</span></div>
}
```

---

## Rule 5: Use React DOM Resource Hints

React DOM provides APIs to hint the browser about resources it will need. These are especially useful in server components to start loading before the client receives HTML.

**Preconnect to third-party APIs:**

```tsx
import { preconnect, prefetchDNS } from 'react-dom'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  prefetchDNS('https://analytics.example.com')
  preconnect('https://api.example.com')

  return (
    <html>
      <body>{children}</body>
    </html>
  )
}
```

**Preload critical fonts and styles:**

```tsx
import { preload, preinit } from 'react-dom'

export default function RootLayout({ children }: { children: React.ReactNode }) {
  preload('/fonts/inter.woff2', {
    as: 'font',
    type: 'font/woff2',
    crossOrigin: 'anonymous',
  })

  preinit('/styles/critical.css', { as: 'style' })

  return (
    <html>
      <body>{children}</body>
    </html>
  )
}
```

| API | Use case |
|-----|----------|
| `prefetchDNS` | Third-party domains you will connect to later |
| `preconnect` | APIs or CDNs you will fetch from immediately |
| `preload` | Critical resources needed for the current page |
| `preloadModule` | JS modules for likely next navigation |
| `preinit` | Stylesheets/scripts that must execute early |
| `preinitModule` | ES modules that must execute early |

---

## Rule 6: Hoist Static JSX Outside Components

Extract large static elements (SVGs, skeletons, separators) to module-level constants to avoid re-creation on every render.

**Bad (recreates static SVG every render):**

```tsx
function Logo() {
  return (
    <svg viewBox="0 0 100 100" className="w-8 h-8">
      <path d="M10 10 L90 90 M90 10 L10 90" stroke="currentColor" strokeWidth="2" />
      {/* ... 50 more paths */}
    </svg>
  )
}
```

**Good (reuses same element):**

```tsx
const logoSvg = (
  <svg viewBox="0 0 100 100" className="w-8 h-8">
    <path d="M10 10 L90 90 M90 10 L10 90" stroke="currentColor" strokeWidth="2" />
    {/* ... 50 more paths */}
  </svg>
)

function Logo() {
  return logoSvg
}
```

The JSX element is created once at module level. Every render reuses the same reference. This is most impactful for large static SVGs and skeleton elements.

React Compiler handles this automatically for most cases. Only hoist manually when the Compiler is not available or when dealing with very large static structures.

---

## Rule 7: Key List Rendering Correctly

Always use stable, unique keys for list rendering. Index keys cause bugs when items are reordered, inserted, or removed.

**Bad (index keys cause re-order bugs):**

```tsx
function TodoList({ items }: { items: Todo[] }) {
  return (
    <ul>
      {items.map((item, index) => (
        <li key={index}>
          <input defaultValue={item.text} />
          <button onClick={() => removeItem(item.id)}>Delete</button>
        </li>
      ))}
    </ul>
  )
}
```

When an item is deleted, React reuses DOM nodes by index position. The input values from deleted items shift into remaining items.

**Good (stable unique keys):**

```tsx
function TodoList({ items }: { items: Todo[] }) {
  return (
    <ul>
      {items.map(item => (
        <li key={item.id}>
          <input defaultValue={item.text} />
          <button onClick={() => removeItem(item.id)}>Delete</button>
        </li>
      ))}
    </ul>
  )
}
```

Each item's DOM node is tied to its `id`. Deleting one item removes only its own DOM node without affecting others.

---

## Rule 8: Image Optimization with next/image

Always use `next/image` for automatic optimization, lazy loading, and responsive sizing.

**Good (optimized images):**

```tsx
import Image from 'next/image'

function HeroBanner({ hero }: { hero: HeroData }) {
  return (
    <div className="relative h-[400px]">
      <Image
        src={hero.imageUrl}
        alt={hero.title}
        fill
        sizes="100vw"
        priority // Preload above-the-fold images
        className="object-cover"
      />
      <div className="absolute inset-0 flex items-center justify-center">
        <h1 className="text-4xl font-bold text-white">{hero.title}</h1>
      </div>
    </div>
  )
}
```

Key configuration:
- `priority` for above-the-fold images (preloads, no lazy loading)
- `sizes` for responsive images (helps generate correct srcsets)
- `fill` for fluid-width images within a sized container
- `width`/`height` for fixed-size images (prevents layout shift)

---

## Rule 9: CSS Transitions Over JavaScript Animations

Use Tailwind transition and animation classes instead of JavaScript-driven animations. CSS transitions run on the compositor thread and don't block the main thread.

**Bad (JavaScript-driven animation blocks main thread):**

```tsx
function ExpandablePanel({ isOpen }: { isOpen: boolean }) {
  const ref = useRef<HTMLDivElement>(null)

  useEffect(() => {
    if (isOpen) {
      ref.current.style.height = `${ref.current.scrollHeight}px`
    } else {
      ref.current.style.height = '0px'
    }
  }, [isOpen])

  return <div ref={ref}>Content</div>
}
```

**Good (CSS transition, compositor thread):**

```tsx
function ExpandablePanel({ isOpen }: { isOpen: boolean }) {
  return (
    <div
      className={`transition-all duration-300 ${
        isOpen ? 'max-h-[500px] opacity-100' : 'max-h-0 opacity-0'
      } overflow-hidden`}
    >
      Content
    </div>
  )
}
```

The transition runs on the GPU compositor. The main thread stays free for user interactions and React rendering.