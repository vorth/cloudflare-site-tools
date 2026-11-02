// The web pages live in the public folder. Nothing else in this folder is published.
import { defineWranglerConfig } from "wrangler/experimental-config";

export default defineWranglerConfig({
  assetsDirectory: "./public",
});
