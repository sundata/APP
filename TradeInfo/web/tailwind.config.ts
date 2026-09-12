import type { Config } from "tailwindcss";
export default {
  content: ["./src/**/*.{ts,tsx}"],
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        up: "var(--color-up)",
        down: "var(--color-down)",
      },
    },
  },
  plugins: [],
} satisfies Config;
