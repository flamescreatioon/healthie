import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Healthie — Personal Vitals & Health Companion',
    short_name: 'Healthie',
    description:
      'Local-first blood pressure, weight, and vitals tracker with offline storage and opt-in encrypted cloud sync.',
    start_url: '/home',
    display: 'standalone',
    background_color: '#f8fafc',
    theme_color: '#3b60e4',
    orientation: 'portrait-primary',
    icons: [
      {
        src: '/icons/icon-192.svg',
        sizes: '192x192',
        type: 'image/svg+xml',
        purpose: 'any',
      },
      {
        src: '/icons/icon-512.svg',
        sizes: '512x512',
        type: 'image/svg+xml',
        purpose: 'any',
      },
      {
        src: '/icons/icon-maskable.svg',
        sizes: '512x512',
        type: 'image/svg+xml',
        purpose: 'maskable',
      },
    ],
  };
}
