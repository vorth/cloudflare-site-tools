// Cloudflare settings for this site. "name" becomes part of the web address:
//   https://<name>.<account-subdomain>.workers.dev
// Use lowercase letters, digits and dashes only.
import { defineConfig } from "cf/config";

export default defineConfig({
  worker: {
    name: "test-site-1",
    compatibilityDate: "2026-09-01",
    assets: {
      // /about serves about.html, /news/ serves news/index.html
      htmlHandling: "auto-trailing-slash",
    },
  },
});
