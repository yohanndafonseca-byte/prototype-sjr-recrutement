/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{js,jsx}", "./lib/**/*.{js,jsx}"],
  theme: {
    extend: {
      colors: {
        sjr: {
          bg: "var(--sjr-bg)",
          surface: "var(--sjr-surface)",
          primary: "var(--sjr-primary)",
          "primary-dark": "var(--sjr-primary-dark)",
          "primary-soft": "var(--sjr-primary-soft)",
          accent: "var(--sjr-accent)",
          "accent-dark": "var(--sjr-accent-dark)",
          ink: "var(--sjr-ink)",
          muted: "var(--sjr-muted)",
          line: "var(--sjr-line)",
        },
      },
      fontFamily: {
        sans: ["ui-sans-serif", "system-ui", "-apple-system", "Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif"],
      },
      boxShadow: {
        card: "0 1px 2px rgba(16,32,52,.04), 0 4px 16px rgba(16,32,52,.06)",
        pop: "0 8px 30px rgba(16,32,52,.12)",
      },
      borderRadius: { xl2: "14px" },
    },
  },
  plugins: [],
};
