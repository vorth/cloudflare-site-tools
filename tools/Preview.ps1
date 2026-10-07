# Show a site in the browser through a small web server on this computer, so links
# and paths behave the way they will on Cloudflare. Close the window to stop it.
#
# Addresses are matched the way Cloudflare's "auto-trailing-slash" setting does:
#   /            -> index.html
#   /about       -> about.html
#   /news/       -> news/index.html
# The tool files (site.json, the .cmd buttons) are never served, just as they are never published.

param(
    [Parameter(Mandatory)][string]$SiteFolder,
    [int]$Port = 8787,
    [switch]$NoBrowser
)

. "$PSScriptRoot\Common.ps1"

$root = (Resolve-Path $SiteFolder).Path.TrimEnd('\')
$name = (Get-SiteSettings $root).name

# Turn a web address path into a file in the site folder, or $null if there isn't one.
function Find-SiteFile([string]$urlPath) {
    $relative = [Uri]::UnescapeDataString($urlPath).TrimStart('/').Replace('/', '\')
    if ($relative -split '\\' -contains '..') { return $null }
    if ($relative -notmatch '\\' -and $ToolFiles -contains $relative) { return $null }

    $candidates = if ($relative -eq '' -or $relative.EndsWith('\')) {
        @("${relative}index.html")
    } else {
        @($relative, "$relative.html", "$relative\index.html")
    }
    foreach ($c in $candidates) {
        $path = Join-Path $root $c
        if (Test-Path $path -PathType Leaf) { return $path }
    }
    $null
}

function Send-Response($response, [int]$status, [string]$contentType, [byte[]]$bytes) {
    $response.StatusCode = $status
    $response.ContentType = $contentType
    $response.ContentLength64 = $bytes.Length
    $response.OutputStream.Write($bytes, 0, $bytes.Length)
    $response.Close()
}

# Use the first free port, starting at $Port.
$listener = $null
for ($p = $Port; $p -lt $Port + 20 -and -not $listener; $p++) {
    $candidate = New-Object System.Net.HttpListener
    $candidate.Prefixes.Add("http://localhost:$p/")
    try { $candidate.Start(); $listener = $candidate; $url = "http://localhost:$p/" }
    catch { $candidate.Close() }
}
if (-not $listener) {
    Write-Host "Couldn't start the preview: no free port found near $Port." -ForegroundColor Red
    Wait-ForEnter
    exit 1
}

Write-Host "Previewing '$name' at $url" -ForegroundColor Green
Write-Host "Edit and save pages, then refresh the browser to see changes."
Write-Host "Close this window when you're finished."
Write-Host ""
if (-not $NoBrowser) { Start-Process $url }

try {
    while ($listener.IsListening) {
        # Wait in short steps so Ctrl+C can still stop the window.
        $pending = $listener.GetContextAsync()
        while (-not $pending.Wait(500)) { }
        $context = $pending.Result
        $request = $context.Request
        try {
            $file = Find-SiteFile $request.Url.AbsolutePath
            if ($file) {
                Send-Response $context.Response 200 (Get-ContentType ([IO.Path]::GetExtension($file))) ([IO.File]::ReadAllBytes($file))
                Write-Host "  $($request.Url.AbsolutePath)"
            } else {
                Send-Response $context.Response 404 'text/plain' ([Text.Encoding]::UTF8.GetBytes('Page not found'))
                Write-Host "  $($request.Url.AbsolutePath)  (not found)" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "  $($request.Url.AbsolutePath)  (error: $($_.Exception.Message))" -ForegroundColor Red
            try { $context.Response.Abort() } catch { }
        }
    }
} finally {
    $listener.Close()
}
