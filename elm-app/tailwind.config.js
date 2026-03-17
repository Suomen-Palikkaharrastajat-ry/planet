/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./src/**/*.{elm,js,ts,jsx,tsx,html}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ['Outfit', 'system-ui', 'sans-serif'],
      },
      colors: {
        // Brand core colors
        brand: '#05131D',
        'brand-yellow': '#F2CD37',
        'brand-red': '#C91A09',
        // Nougat palette
        'nougat-light': '#F6D7B3',
        nougat: '#D09168',
        'nougat-dark': '#AD6140',
        // Semantic aliases (background)
        'bg-page': '#FFFFFF',
        'bg-subtle': '#F9FAFB',
        'bg-accent': '#F2CD37',
        'bg-dark': '#05131D',
        // Semantic aliases (border)
        'border-brand': '#05131D',
        'border-default': '#E5E7EB',
        // Semantic aliases (text)
        'text-primary': '#05131D',
        'text-muted': '#6B7280',
        'text-subtle': '#9CA3AF',
        'text-on-dark': '#FFFFFF',
      },
      transitionDuration: {
        fast: '150ms',
        base: '300ms',
      },
    },
  },
  plugins: [],
}
