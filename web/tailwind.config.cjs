const defaultTheme = require("tailwindcss/defaultTheme");

module.exports = {
  content: ["./src/**/*.{ts,tsx}", "./public/**/*.html"],
  theme: {
    extend: {
      colors: {
        orange: "#FFB978",
        pink: "#FDC9D3",
        yellow: "#ff990040",
        yellowish: "#fffcf0",
        background: "#fffffa",
      },
      fontSize: {
        giga: "6rem",
      },
      fontFamily: {
        sans: ["Source Code Pro", ...defaultTheme.fontFamily.sans],
        monoton: ["Monoton", ...defaultTheme.fontFamily.sans],
      },
      keyframes: {
        wiggle: {
          "0%, 100%": { transform: "rotate(-3deg)" },
          "50%": { transform: "rotate(3deg)" },
        },
        // anvil: {
        //   "0%": {
        //     transform: "scale(1) translateY(0px)",
        //     opacity: 0,
        //     "box-shadow": "0 0 0 rgba(241, 241, 241, 0)",
        //   },
        //   "1%": {
        //     transform: "scale(0.96) translateY(10px)",
        //     opacity: 0,
        //     "box-shadow": "0 0 0 rgba(241, 241, 241, 0)",
        //   },
        //   "100%": {
        //     transform: "scale(1) translateY(0px)",
        //     opacity: 1,
        //     "box-shadow": "0 0 500px rgba(241, 241, 241, 0)",
        //   },
        // },
      },
    },
    animation: {
      wiggle: "wiggle 1s ease-in-out infinite",
      // anvil: "anvil 1s ease-in-out infinite",
    },
  },
  plugins: [],
};
