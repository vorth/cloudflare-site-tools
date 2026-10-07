# Website tools

This folder holds one or more websites and the tools for checking them and publishing them to Cloudflare.
Nothing needs to be installed: the tools use PowerShell, which comes with Windows.

```
cloudflare-site-tools\
  Test Site 1\      <- one website
    index.html         home page
    about.html         a second page
    style.css          colors and fonts
    Preview.cmd        see this site in your browser
    Publish.cmd        put this site on the internet
    site.json          this site's name on Cloudflare
  Test Site 2\      <- another website, laid out the same way
  tools\            <- shared by all sites
    Setup.cmd          one time: connect this computer to Cloudflare
    *.ps1              the PowerShell code behind the buttons. No need to open.
```

To use a tool, **double-click** its `.cmd` file in File Explorer.
Publish uploads only the web files. It never uploads `site.json` or the `.cmd` buttons.

## Everyday use

1. Open the folder of the site you want to change.
2. **Edit** a page with Notepad and save it.
   Change only the text between tags, like the words inside `<p>` and `</p>`.
3. **Preview**: double-click `Preview.cmd` in that folder. A small window opens and the
   site appears in your browser at an address like `http://localhost:8787`.
   After more edits, refresh the browser page to see them.
   Close the small window when you're finished.
4. **Publish**: double-click `Publish.cmd` in that folder and type `y` to confirm.
   It shows the web address when it's done.

## One-time setup (done by whoever manages the Cloudflare account)

1. In the Cloudflare dashboard, open **Workers & Pages** once, so the account has a
   `workers.dev` address.
2. Create an API token: **My Profile > API Tokens > Create Token**, use the
   **Edit Cloudflare Workers** template, and limit it to this account.
3. Double-click `tools\Setup.cmd` and paste the token when asked. Setup finds the
   account the token belongs to. If it can't, it asks for the account ID, which is the long
   code after `dash.cloudflare.com/` in the browser's address bar.
   The token is saved encrypted for this Windows user only, not in this folder.

All sites publish to this one Cloudflare account.

## Adding a site

1. Copy an existing site folder and rename the copy (for example `Bakery`).
2. Open its `site.json` in Notepad and change `"name"`. Use lowercase letters, digits
   and dashes only. It becomes part of the address:
   `https://<name>.<account-subdomain>.workers.dev`
3. Replace the pages with the new site's content.

Site folders must sit next to the `tools` folder, because their buttons look for `..\tools`.

## Adding a page

Copy `about.html`, rename the copy (for example `contact.html`), edit it, and add a link to it in the `<nav>` line of each page.

## If something goes wrong

- *"isn't connected to Cloudflare yet"*: do the one-time setup above.
- *"Cloudflare request failed ... Authentication error"*: the token is wrong or expired. Make a new one and run Setup again.
- A page looks broken: check that every tag you opened, like `<p>`, still has its closing `</p>`.

## For maintainers

`tools\Publish.ps1 -SiteFolder <folder>` follows Cloudflare's
[direct upload API](https://developers.cloudflare.com/workers/static-assets/direct-upload/):
it hashes each web file, opens an upload session, uploads only the files Cloudflare asks for,
then deploys a tiny Worker that points at those files.
Add `-DryRun` to see what would be uploaded without contacting Cloudflare.
