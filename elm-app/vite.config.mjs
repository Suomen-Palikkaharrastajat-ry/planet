import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import elmTailwind from 'elm-tailwind-classes/vite'
import elm from 'vite-plugin-elm'
import siteConfig from './packages/site-config/vite.mjs'

export default defineConfig({
  publicDir: 'public',
  plugins: [
    // config.toml → document head, site.webmanifest and virtual:site-config
    siteConfig(),
    elmTailwind(),
    elm(),
    tailwindcss(),
  ],
  build: {
    outDir: '../dist',
    emptyOutDir: true,
  },
  base: '/',
})
