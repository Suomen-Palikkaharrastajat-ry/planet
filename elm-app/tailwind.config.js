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
        brand: '#05131D',
        'brand-yellow': '#F2CD37',
      },
      transitionDuration: {
        fast: '150ms',
        base: '300ms',
      },
    },
  },
  plugins: [],
}
