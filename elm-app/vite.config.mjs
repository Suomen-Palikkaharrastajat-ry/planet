import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import elmTailwind from 'elm-tailwind-classes/vite'
import elm from 'vite-plugin-elm'

export default defineConfig({
  publicDir: 'public',
  plugins: [
    elmTailwind(),
    elm(),
    tailwindcss(),
  ],
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  },
  base: '/',
})
