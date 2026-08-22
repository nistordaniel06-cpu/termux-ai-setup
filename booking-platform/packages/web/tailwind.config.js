/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{js,ts,jsx,tsx,mdx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#0b0b0d",
          accent: "#f2c14e",
        },
      },
    },
  },
  plugins: [],
};
