# Image and Font Optimization

## next/image

### Why Use next/image

`next/image` provides automatic image optimization:
- Automatic format conversion (WebP, AVIF when supported)
- Responsive sizing with `srcset`
- Lazy loading by default (images below viewport load when scrolled into view)
- Placeholder support (blur, shimmer) to prevent layout shift
- Prevents layout shift by requiring `width` and `height`

### Basic Usage

```tsx
import Image from 'next/image'

export function Hero() {
  return (
    <Image
      src="/hero.jpg"          // local image from public/ directory
      alt="Hero section"
      width={1200}
      height={600}
      priority                  // load immediately, no lazy loading (for above-fold images)
    />
  )
}
```

### Local Images

Images in `public/` are referenced by path. Next.js determines width and height automatically from the file if you use a static import:

```tsx
// Static import — Next.js infers width/height from the image
import heroImage from '@/public/hero.jpg'
import Image from 'next/image'

export function Hero() {
  return (
    <Image
      src={heroImage}
      alt="Hero"
      priority
    />
  )
}
```

### Remote Images

Remote images require `width` and `height` because Next.js cannot inspect them at build time. You must also configure allowed domains in `next.config.ts`:

```tsx
// next.config.ts
const nextConfig = {
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'cdn.example.com',
        pathname: '/images/**',
      },
      {
        protocol: 'https',
        hostname: 'avatars.githubusercontent.com',
      },
    ],
  },
}

export default nextConfig
```

```tsx
import Image from 'next/image'

export function UserAvatar({ url }: { url: string }) {
  return (
    <Image
      src={url}                // remote URL from allowed domain
      alt="User avatar"
      width={48}
      height={48}
      className="rounded-full"
    />
  )
}
```

### sizes Property

The `sizes` property tells Next.js what size the image will be at different viewport widths. This determines which `srcset` entries to generate:

```tsx
// Responsive image — different sizes at different breakpoints
<Image
  src="/product.jpg"
  alt="Product photo"
  width={800}
  height={600}
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
/>
```

Always set `sizes` for responsive images. Without it, Next.js defaults to `100vw`, generating unnecessarily large images for every viewport.

### Blur Placeholders

Blur placeholders prevent layout shift by showing a blurred version of the image before the real image loads:

```tsx
// Static import with automatic blur placeholder
import productImage from '@/public/product.jpg'
import Image from 'next/image'

export function ProductPhoto() {
  return (
    <Image
      src={productImage}
      alt="Product"
      placeholder="blur"      // automatically generates blur placeholder from static import
    />
  )
}
```

For remote images, provide a `blurDataURL` manually:

```tsx
import Image from 'next/image'

export function RemoteProduct({ imageUrl, blurHash }: { imageUrl: string; blurHash: string }) {
  return (
    <Image
      src={imageUrl}
      alt="Product"
      width={800}
      height={600}
      placeholder="blur"
      blurDataURL={blurHash}   // base64-encoded tiny image or CSS color
    />
  )
}
```

Generate `blurDataURL` from a tiny base64-encoded image:

```tsx
// Create a minimal blur placeholder
const shimmer = (w: number, h: number) => `
<svg width="${w}" height="${h}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="g">
      <stop stop-color="#e5e7eb" offset="0%" />
      <stop stop-color="#f3f4f6" offset="50%" />
      <stop stop-color="#e5e7eb" offset="100%" />
    </linearGradient>
  </defs>
  <rect width="${w}" height="${h}" fill="url(#g)" />
</svg>`

const toBase64 = (str: string) =>
  typeof window === 'undefined'
    ? Buffer.from(str).toString('base64')
    : window.btoa(str)

export const shimmerBlurDataURL = `data:image/svg+xml;base64,${toBase64(shimmer(800, 600))}`
```

### Fill Mode

Use `fill` when you don't know the exact dimensions and want the image to fill its parent container:

```tsx
// Fill mode — image fills parent container
<div className="relative w-full h-64">
  <Image
    src="/background.jpg"
    alt="Background"
    fill                    // no width/height needed, fills parent
    sizes="100vw"
    className="object-cover"
  />
</div>
```

The parent element must have `position: relative` and defined dimensions.

### Image Optimization Configuration

```tsx
// next.config.ts
const nextConfig = {
  images: {
    // Device sizes for srcset generation
    deviceSizes: [640, 750, 828, 1080, 1200, 1920, 2048],

    // Image sizes for srcset generation
    imageSizes: [16, 32, 48, 64, 96, 128, 256, 384],

    // Allowed formats (AVIF requires more CPU)
    formats: ['image/avif', 'image/webp'],

    // Minimum cache TTL for optimized images (seconds)
    minimumCacheTTL: 60,

    // Disable static image import optimization
    disableStaticImages: false,

    // Allowed remote patterns
    remotePatterns: [
      { protocol: 'https', hostname: 'cdn.example.com' },
    ],
  },
}
```

## next/font

### Why Use next/font

`next/font` provides:
- Zero layout shift — fonts are loaded at build time, not at runtime
- Self-hosted — no external network requests to Google or font CDN
- Automatic `font-display: swap` — text is visible immediately
- CSS variables — integrates with Tailwind CSS

### Google Fonts

```tsx
// app/layout.tsx
import { Inter, Roboto_Mono } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',           // CSS variable for Tailwind
})

const robotoMono = Roboto_Mono({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-roboto-mono',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${robotoMono.variable}`}>
      <body className="font-sans">{children}</body>
    </html>
  )
}
```

### Local Fonts

```tsx
// app/layout.tsx
import localFont from 'next/font/local'

const myFont = localFont({
  src: [
    {
      path: '../fonts/my-font-regular.woff2',
      weight: '400',
      style: 'normal',
    },
    {
      path: '../fonts/my-font-bold.woff2',
      weight: '700',
      style: 'normal',
    },
  ],
  display: 'swap',
  variable: '--font-my',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={myFont.variable}>
      <body>{children}</body>
    </html>
  )
}
```

### Tailwind CSS Integration

Combine `next/font` CSS variables with Tailwind v4:

```css
/* app/globals.css — Tailwind v4 */
@import "tailwindcss";

@theme {
  --font-sans: var(--font-inter);
  --font-mono: var(--font-roboto-mono);
}
```

Then use Tailwind classes directly:

```tsx
export function Article() {
  return (
    <div>
      <h1 className="font-sans text-2xl">Heading</h1>
      <code className="font-mono text-sm">console.log('hello')</code>
    </div>
  )
}
```

### Font Options

| Option | Description | Example |
|--------|-------------|---------|
| `subsets` | Character subsets to include | `['latin', 'latin-ext']` |
| `weight` | Specific weights to load | `'400'` or `['400', '700']` |
| `style` | Font styles to load | `'normal'` or `['normal', 'italic']` |
| `display` | Font-display strategy | `'swap'` (recommended) |
| `variable` | CSS variable name | `'--font-inter'` |
| `preload` | Preload the font | `true` (default) |
| `fallback` | Fallback font families | `['system-ui', 'arial']` |
| `adjustFontFallback` | Adjust fallback metrics | `'normal'` or `false` |

### Font Loading Anti-patterns

```tsx
// BAD: Importing font CSS from external CDN — causes layout shift and network request
import '@fontsource/inter/400.css'  // no optimization, network dependency

// GOOD: Use next/font — self-hosted, zero layout shift
import { Inter } from 'next/font/google'
```

Do not use `@fontsource`, Google Fonts CDN `<link>` tags, or `font-face` declarations in CSS. Use `next/font` exclusively.

### Using Font Without Tailwind

Apply the font directly via `className`:

```tsx
const inter = Inter({ subsets: ['latin'] })

export function Page() {
  return <p className={inter.className}>This text uses Inter</p>
}
```

Or use the CSS variable approach for more flexibility:

```tsx
const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })

// In CSS:
// .custom-text { font-family: var(--font-inter); }

// In JSX:
export function Page() {
  return <p style={{ fontFamily: 'var(--font-inter)' }}>Custom text</p>
}
```

## Combined Pattern: Layout with Font and Image

```tsx
// app/layout.tsx — complete root layout with fonts and metadata
import type { Metadata } from 'next'
import { Inter, Roboto_Mono } from 'next/font/google'
import Image from 'next/image'

const inter = Inter({ subsets: ['latin'], variable: '--font-inter' })
const robotoMono = Roboto_Mono({ subsets: ['latin'], variable: '--font-roboto-mono' })

export const metadata: Metadata = {
  title: { default: 'MyApp', template: '%s | MyApp' },
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${robotoMono.variable}`}>
      <body className="font-sans antialiased">
        <header className="flex items-center gap-2">
          <Image
            src="/logo.svg"
            alt="MyApp logo"
            width={32}
            height={32}
            priority
          />
          <span className="font-sans font-bold">MyApp</span>
        </header>
        <main>{children}</main>
      </body>
    </html>
  )
}
```