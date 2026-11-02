# Website tools

This folder holds one or more websites, with buttons to preview them and publish them to Cloudflare.
The buttons run Cloudflare's [`cf`](https://developers.cloudflare.com/cf/) tool, which needs Node.js.

```
cloudflare-site-tools\
  Test Site 1\      <- one website
    public\            the web pages. This is the only folder you edit.
      index.html         home page
      about.html         a second page
      style.css          colors and fonts
    Preview.cmd        see this site in your browser   (runs: cf dev)
    Publish.cmd        put this site on the internet   (runs: cf deploy)
    cloudflare.config.ts   this site's name on Cloudflare
    (other files)      settings for cf. No need to open.
  Test Site 2\      <- another website, laid out the same way
  tools\
    Setup.cmd          one time: install Node.js and sign in to Cloudflare
```

To use a button, **double-click** its `.cmd` file in File Explorer.
Publish uploads only the `public` folder.

## Everyday use

1. Open the `public` folder of the site you want to change.
2. **Edit** a page with Notepad and save it.
   Change only the text between tags, like the words inside `<p>` and `</p>`.
3. **Preview**: double-click `Preview.cmd` in the site's folder. When the window shows
   `http://localhost:8787`, press **b** to open the site in your browser.
   After more edits, refresh the browser page to see them. Close the window when you're finished.
   (The very first time, it spends a minute downloading the Cloudflare tools.)
4. **Publish**: double-click `Publish.cmd` in the site's folder and press **Y** to confirm.
   It shows the web address when it's done.

## One-time setup

1. In the Cloudflare dashboard, open **Workers & Pages** once, so the account has a
   `workers.dev` address.
2. Double-click `tools\Setup.cmd`. If Node.js isn't installed, Setup installs it and asks
   you to run Setup again. Then a browser window opens: sign in to Cloudflare and allow access.

## Adding a site

1. Copy an existing site folder and rename the copy (for example `Bakery`).
   Delete the copy's `node_modules` folder if it has one.
2. Open its `cloudflare.config.ts` in Notepad and change `name`. Use lowercase letters, digits
   and dashes only. It becomes part of the address:
   `https://<name>.<account-subdomain>.workers.dev`
3. Replace the pages in its `public` folder with the new site's content.

## Adding a page

In the `public` folder, copy `about.html`, rename the copy (for example `contact.html`), edit it,
and add a link to it in the `<nav>` line of each page.

## If something goes wrong

- A message about signing in or authentication: run Setup again.
- A message about the Node.js version: install the current LTS version from https://nodejs.org.
- Download errors the first time: check the internet connection, delete the site's
  `node_modules` folder, and try again.
- A page looks broken: check that every tag you opened, like `<p>`, still has its closing `</p>`.

## For maintainers

`cf` is in beta. Each site pins exact `cf` and `wrangler` versions in `package.json` and
`package-lock.json`; the buttons install them with `npm ci` and run that copy through `npx`, so a
new `cf` release changes nothing until you update the versions on purpose (and the version in
`tools\Setup.cmd`). Wrangler must be installed in the site folder because `cf` hands static sites to it.

- `cloudflare.config.ts`: Worker name, compatibility date, `htmlHandling: "auto-trailing-slash"`.
  If the Cloudflare login can see several accounts, add `accountId: "<id>"` next to `worker`.
- `wrangler.config.ts`: `assetsDirectory: "./public"`.
- To check a site without publishing it, run `npx cf deploy --dry-run` in its folder.
