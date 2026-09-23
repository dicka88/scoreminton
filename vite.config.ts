/// <reference types="vitest/config" />
import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'
import { VitePWA } from 'vite-plugin-pwa'

export default defineConfig({
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['favicon.svg', 'apple-touch-icon.png'],
      manifest: {
        name: 'Scoreminton — Papan Skor Badminton',
        short_name: 'Scoreminton',
        description: 'Papan skor badminton: single & double, rally point & service-over.',
        lang: 'id',
        theme_color: '#f5f6fa',
        background_color: '#f5f6fa',
        display: 'fullscreen',
        orientation: 'landscape',
        start_url: '/',
        icons: [
          { src: 'icon-192.png', sizes: '192x192', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png' },
          { src: 'icon-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
        ],
      },
      workbox: {
        // self-hosted fonts: precache latin + latin-ext so names with accents render offline too
        globPatterns: ['**/*.{js,css,html,svg,png}', 'assets/*-latin*-wght-normal-*.woff2'],
      },
    }),
  ],
  test: {
    include: ['src/**/*.test.ts'],
  },
})
