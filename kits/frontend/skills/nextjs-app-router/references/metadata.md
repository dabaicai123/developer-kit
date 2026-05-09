# Metadata

## Static Metadata

Define static metadata in `layout.tsx` or `page.tsx` by exporting a `Metadata` object:

```tsx
// app/layout.tsx — root metadata (applies to all pages)
import type { Metadata } from 'next'

export const metadata: Metadata = {
  title: {
    default: 'MyApp',
    template: '%s | MyApp',  // child pages override with their title
  },
  description: 'Application description',
  keywords: ['app', 'product', 'dashboard'],
  authors: [{ name: 'Team' }],
  creator: 'Team',
  metadataBase: new URL('https://app.example.com'),
  openGraph: {
    type: 'website',
    locale: 'en_US',
    siteName: 'MyApp',
  },
  twitter: {
    card: 'summary_large_image',
  },
  robots: {
    index: true,
    follow: true,
  },
}
```

### Title Templates

Title templates let child pages append their title to a prefix:

```tsx
// app/layout.tsx
export const metadata: Metadata = {
  title: {
    default: 'MyApp',
    template: '%s | MyApp',
  },
}

// app/products/page.tsx — overrides title, template fills in
export const metadata: Metadata = {
  title: 'Products',  // rendered as "Products | MyApp"
}

// app/products/[id]/page.tsx — dynamic title
export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)
  return {
    title: product.name,  // rendered as "Product Name | MyApp"
  }
}
```

## Dynamic Metadata with generateMetadata

Use `generateMetadata` for metadata that depends on route params or fetched data:

```tsx
// app/products/[id]/page.tsx
import type { Metadata, ResolvingMetadata } from 'next'

export async function generateMetadata(
  { params }: { params: Promise<{ id: string }> },
  parent: ResolvingMetadata
): Promise<Metadata> {
  const { id } = await params
  const product = await getProduct(id)

  // Access parent metadata for merging
  const previousImages = (await parent).openGraph?.images || []

  return {
    title: product.name,
    description: product.description,
    openGraph: {
      title: product.name,
      description: product.description,
      images: [product.imageUrl, ...previousImages],
    },
  }
}
```

`generateMetadata` runs on the server and can access databases, APIs, and environment variables.

### generateMetadata Rules

- Must be an async function
- Returns `Promise<Metadata>`
- Receives `params` as `Promise<Params>` (Next.js 15+)
- Receives `searchParams` as `Promise<SearchParams>` (Next.js 15+)
- Receives a `parent` resolver to access inherited metadata
- Cannot coexist with a static `metadata` export in the same file

## OG Images

### File-Based Convention (opengraph-image)

Place image files in route directories to automatically set OG images:

```
app/
├── opengraph-image.png        # OG image for /
├── products/
│   ├── opengraph-image.png    # OG image for /products
│   ├── [id]/
│   │   ├── opengraph-image.tsx  # Dynamic OG image for /products/:id
```

Supported file types: `.png`, `.jpg`, `.jpeg`, `.gif`, `.ico`, `.webp`, `.avif`, `.svg`.

### Dynamic OG Images with JSX

Use `opengraph-image.tsx` (or `.tsx` variants like `twitter-image.tsx`) to generate OG images dynamically using JSX and CSS:

```tsx
// app/products/[id]/opengraph-image.tsx
import { ImageResponse } from 'next/og'

export const alt = 'Product image'
export const size = { width: 1200, height: 630 }
export const contentType = 'image/png'

export default async function Image({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)

  return new ImageResponse(
    (
      <div style={{ display: 'flex', width: '100%', height: '100%', backgroundColor: '#1a1a2e' }}>
        <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', padding: '40px' }}>
          <h2 style={{ fontSize: 60, color: '#e94560' }}>{product.name}</h2>
          <p style={{ fontSize: 30, color: '#ffffff' }}>{product.description}</p>
        </div>
      </div>
    ),
    { ...size }
  )
}
```

### ImageResponse API

`ImageResponse` from `next/og` renders JSX to a PNG image. It uses Satori under the hood and supports:
- CSS flexbox layout
- Inline styles only (no Tailwind classes, no external CSS)
- Limited CSS properties (no gradients, animations, or pseudo-elements)
- `<img>` tags for embedding remote images

```tsx
import { ImageResponse } from 'next/og'

export default async function OGImage() {
  return new ImageResponse(
    (
      <div style={{
        display: 'flex',
        width: '100%',
        height: '100%',
        backgroundColor: '#0f172a',
        color: '#f8fafc',
        fontSize: 48,
        padding: 40,
      }}>
        <div style={{ display: 'flex', flexDirection: 'column' }}>
          <h1 style={{ margin: 0 }}>MyApp</h1>
          <p style={{ fontSize: 24, color: '#94a3b8' }}>Build something great</p>
        </div>
      </div>
    ),
    {
      width: 1200,
      height: 630,
    }
  )
}
```

## Sitemaps

### File-Based Convention (sitemap)

Place `sitemap.ts` in the `app/` directory to automatically generate a sitemap:

```tsx
// app/sitemap.ts
import type { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const products = await db.product.findMany()

  const productEntries: MetadataRoute.Sitemap = products.map((p) => ({
    url: `https://app.example.com/products/${p.id}`,
    lastModified: p.updatedAt,
    changeFrequency: 'weekly',
    priority: 0.8,
  }))

  return [
    {
      url: 'https://app.example.com',
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 1,
    },
    {
      url: 'https://app.example.com/products',
      lastModified: new Date(),
      changeFrequency: 'daily',
      priority: 0.9,
    },
    ...productEntries,
  ]
}
```

This produces `/sitemap.xml` automatically.

### Multiple Sitemaps

For large sites, create sitemaps in subdirectories:

```tsx
// app/products/sitemap.ts — produces /products/sitemap.xml
import type { MetadataRoute } from 'next'

export default async function sitemap(): Promise<MetadataRoute.Sitemap> {
  const products = await db.product.findMany()
  return products.map((p) => ({
    url: `https://app.example.com/products/${p.id}`,
    lastModified: p.updatedAt,
  }))
}
```

Add a root sitemap index:

```tsx
// app/sitemap.ts — index that lists all sitemaps
export default function sitemap(): MetadataRoute.Sitemap {
  return [
    { url: 'https://app.example.com/products/sitemap.xml', lastModified: new Date() },
  ]
}
```

## Robots

```tsx
// app/robots.ts
import type { MetadataRoute } from 'next'

export default function robots(): MetadataRoute.Robots {
  return {
    rules: [
      {
        userAgent: '*',
        allow: '/',
        disallow: ['/admin/', '/api/', '/settings/'],
      },
    ],
    sitemap: 'https://app.example.com/sitemap.xml',
  }
}
```

This produces `/robots.txt` automatically.

## Manifest

```tsx
// app/manifest.ts
import type { MetadataRoute } from 'next'

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'MyApp',
    short_name: 'MyApp',
    start_url: '/',
    display: 'standalone',
    background_color: '#0f172a',
    theme_color: '#3b82f6',
  }
}
```

## File-Based Conventions Summary

| File | Produces | Description |
|------|----------|-------------|
| `opengraph-image.png` | OG image for route | Static OG image |
| `opengraph-image.tsx` | Dynamic OG image | JSX-rendered OG image |
| `twitter-image.png` | Twitter card image | Static Twitter image |
| `twitter-image.tsx` | Dynamic Twitter image | JSX-rendered Twitter image |
| `favicon.ico` | `/favicon.ico` | Site favicon |
| `icon.png` | `/icon` | App icon (multiple sizes) |
| `icon.tsx` | Dynamic icon | JSX-rendered icon |
| `apple-icon.png` | `/apple-icon` | Apple touch icon |
| `apple-icon.tsx` | Dynamic Apple icon | JSX-rendered Apple touch icon |
| `sitemap.ts` | `/sitemap.xml` | Sitemap |
| `robots.ts` | `/robots.txt` | Robots file |
| `manifest.ts` | `/manifest.webmanifest` | Web app manifest |

## Merge Behavior

Metadata merges from parent layouts to child pages. Child metadata overrides parent values for the same field. Arrays (like `openGraph.images`) are merged, not replaced:

```tsx
// app/layout.tsx
export const metadata: Metadata = {
  title: 'MyApp',
  openGraph: {
    images: ['/default-og.png'],
  },
}

// app/products/[id]/page.tsx
export async function generateMetadata({ params }: { params: Promise<{ id: string }> }) {
  const { id } = await params
  const product = await getProduct(id)
  return {
    title: product.name,              // overrides parent title
    openGraph: {
      images: [product.imageUrl],     // merged with parent images
    },
  }
}
// Result: title = "Product Name", openGraph.images = ['/default-og.png', product.imageUrl]
```