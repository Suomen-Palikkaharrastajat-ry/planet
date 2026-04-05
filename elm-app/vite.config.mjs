import { defineConfig } from 'vite'
import tailwindcss from '@tailwindcss/vite'
import elmTailwind from 'elm-tailwind-classes/vite'
import elmPlugin from 'vite-plugin-elm'

export default defineConfig({
  publicDir: 'public',
  plugins: [elmTailwind(), tailwindcss(), elmPlugin()]
})
