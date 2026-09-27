import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        background: "var(--background)",
        foreground: "var(--foreground)",
      },
      keyframes: {
        shrink: {
          from: { width: "100%" },
          to:   { width: "0%" },
        },
      },
      animation: {
        "shrink-8s": "shrink 8s linear forwards",
      },
    },
  },
  plugins: [],
};
export default config;
