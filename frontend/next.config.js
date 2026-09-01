/** @type {import('next').NextConfig} */
const nextConfig = {
  images: {
    unoptimized: true,
  },

  output: "standalone",

  allowedDevOrigins: ["10.0.0.2", "192.168.1.75", "localhost"],

  turbopack: {
    root: __dirname,
  },
};

module.exports = nextConfig;