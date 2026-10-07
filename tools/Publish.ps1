# Publish one site folder to Cloudflare Workers, using Cloudflare's direct-upload API:
#   https://developers.cloudflare.com/workers/static-assets/direct-upload/
# Run with -DryRun to list what would be uploaded without contacting Cloudflare.

param(
    [Parameter(Mandatory)][string]$SiteFolder,
    [switch]$DryRun
)

. "$PSScriptRoot\Common.ps1"

$MaxFileBytes = 25MB

# Cloudflare requires a small program alongside the files. Files are served
# before it runs, so it only answers requests for pages that don't exist.
$WorkerScript = @'
export default {
  async fetch() {
    return new Response("Page not found", { status: 404 });
  },
};
'@

# Read every web file in the site folder and work out its fingerprint (hash):
# first 32 hex characters of SHA-256 over the base64 content plus the extension.
# The tool files directly in the site folder (site.json, the .cmd buttons) are skipped.
function Get-SiteFiles([string]$root) {
    $sha = [Security.Cryptography.SHA256]::Create()
    Get-ChildItem $root -Recurse -File |
        Where-Object { -not ($_.DirectoryName -eq $root -and $ToolFiles -contains $_.Name) } |
        Where-Object { $_.Name -notin @('Thumbs.db', 'desktop.ini', '.DS_Store') } |
        ForEach-Object {
            if ($_.Length -gt $MaxFileBytes) {
                throw "$($_.Name) is larger than 25 MB, which Cloudflare does not allow."
            }
            $bytes = [IO.File]::ReadAllBytes($_.FullName)
            $base64 = [Convert]::ToBase64String($bytes)
            $ext = $_.Extension.TrimStart('.')
            $hashBytes = $sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($base64 + $ext))
            $hash = (-join ($hashBytes | ForEach-Object { $_.ToString('x2') })).Substring(0, 32)
            $mime = Get-ContentType $_.Extension
            [pscustomobject]@{
                Path        = '/' + $_.FullName.Substring($root.Length + 1).Replace('\', '/')
                Hash        = $hash
                Size        = $bytes.Length
                Base64      = $base64
                ContentType = $mime
            }
        }
}

try {
    $root = (Resolve-Path $SiteFolder).Path.TrimEnd('\')
    $name = (Get-SiteSettings $root).name

    Write-Host "Reading files for '$name'..."
    $files = @(Get-SiteFiles $root)
    if ($files.Count -eq 0) { throw "The site folder has no web pages in it." }
    $files | ForEach-Object { Write-Host "  $($_.Path)" }

    if ($DryRun) {
        Write-Host ""
        Write-Host "Dry run: $($files.Count) files would be published as '$name'. Nothing was sent." -ForegroundColor Yellow
        return
    }
    $accountId = (Get-CloudflareAccount).AccountId

    Write-Host ""
    $answer = Read-Host "Publish these $($files.Count) files to '$name' now? (y/n)"
    if ($answer -notmatch '^[Yy]') {
        Write-Host "Cancelled. Nothing was published."
        return
    }

    # Step 1: tell Cloudflare which files the site has.
    Write-Host "Starting upload..."
    $manifest = [ordered]@{}
    foreach ($f in $files) { $manifest[$f.Path] = @{ hash = $f.Hash; size = $f.Size } }
    $session = Invoke-Cloudflare -Method POST `
        -Path "/accounts/$accountId/workers/scripts/$name/assets-upload-session" `
        -Body @{ manifest = $manifest }

    # Step 2: upload the files Cloudflare doesn't already have, in the groups it asked for.
    # If nothing changed there are no groups, and the session token is already the final one.
    $completionToken = $session.jwt
    $byHash = @{}
    foreach ($f in $files) { $byHash[$f.Hash] = $f }
    $buckets = @($session.buckets | Where-Object { $_ })
    if ($buckets.Count -eq 0) { Write-Host "No file changes since the last publish." }
    foreach ($bucket in $buckets) {
        $parts = foreach ($hash in $bucket) {
            $f = $byHash[$hash]
            Write-Host "  Uploading $($f.Path)"
            @{ Name = $hash; FileName = $hash; ContentType = $f.ContentType; Value = $f.Base64 }
        }
        $body = New-MultipartBody $parts
        $result = Invoke-Cloudflare -Method POST `
            -Path "/accounts/$accountId/workers/assets/upload?base64=true" `
            -Body $body.Bytes -ContentType $body.ContentType -Token $session.jwt
        if ($result.jwt) { $completionToken = $result.jwt }
    }

    # Step 3: publish the new version of the site.
    Write-Host "Publishing..."
    $metadata = @{
        main_module        = 'worker.js'
        compatibility_date = '2026-09-01'
        assets             = @{ jwt = $completionToken; config = @{ html_handling = 'auto-trailing-slash' } }
    } | ConvertTo-Json -Depth 5 -Compress
    $body = New-MultipartBody @(
        @{ Name = 'metadata'; ContentType = 'application/json'; Value = $metadata },
        @{ Name = 'worker.js'; FileName = 'worker.js'; ContentType = 'application/javascript+module'; Value = $WorkerScript }
    )
    Invoke-Cloudflare -Method PUT -Path "/accounts/$accountId/workers/scripts/$name" `
        -Body $body.Bytes -ContentType $body.ContentType | Out-Null

    # Step 4: make sure the site is reachable at its workers.dev address.
    Invoke-Cloudflare -Method POST -Path "/accounts/$accountId/workers/scripts/$name/subdomain" `
        -Body @{ enabled = $true } | Out-Null
    $subdomain = (Invoke-Cloudflare -Method GET -Path "/accounts/$accountId/workers/subdomain").subdomain

    Write-Host ""
    Write-Host "Done. The website is live at:" -ForegroundColor Green
    Write-Host "  https://$name.$subdomain.workers.dev" -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "Publishing failed: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    if (-not $DryRun) { Wait-ForEnter }
}
