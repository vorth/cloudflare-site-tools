# Shared helpers for the site tools. You don't need to run this file directly.

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$CredentialFile = Join-Path $env:APPDATA 'cloudflare-site-tools\cloudflare.xml'
$ApiBase        = 'https://api.cloudflare.com/client/v4'

# Files in a site folder that belong to the tools, not the website. Never published.
$ToolFiles = @('site.json', 'Preview.cmd', 'Publish.cmd')

$MimeTypes = @{
    '.html' = 'text/html'; '.htm' = 'text/html'; '.css' = 'text/css'
    '.js' = 'text/javascript'; '.json' = 'application/json'; '.txt' = 'text/plain'
    '.xml' = 'application/xml'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'
    '.jpg' = 'image/jpeg'; '.jpeg' = 'image/jpeg'; '.gif' = 'image/gif'
    '.webp' = 'image/webp'; '.ico' = 'image/x-icon'; '.pdf' = 'application/pdf'
    '.woff' = 'font/woff'; '.woff2' = 'font/woff2'; '.mp4' = 'video/mp4'
}

function Get-ContentType([string]$Extension) {
    $mime = $MimeTypes[$Extension.ToLower()]
    if ($mime) { $mime } else { 'application/octet-stream' }
}

# A site folder holds the web pages plus site.json, which names the site on Cloudflare.
function Get-SiteSettings([string]$SiteFolder) {
    $file = Join-Path $SiteFolder 'site.json'
    if (-not (Test-Path $file)) { throw "This folder has no site.json, so it isn't set up as a website: $SiteFolder" }
    $settings = Get-Content $file -Raw | ConvertFrom-Json
    if ($settings.name -notmatch '^[a-z0-9][a-z0-9-]{0,62}$') {
        throw "The name in site.json must use only lowercase letters, digits and dashes (found '$($settings.name)')."
    }
    $settings
}

function ConvertTo-PlainText([securestring]$secure) {
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
}

# The account ID and API token are stored encrypted, readable only by this Windows user on this computer.
function Save-CloudflareAccount([string]$AccountId, [securestring]$Token) {
    New-Item -ItemType Directory -Force (Split-Path $CredentialFile) | Out-Null
    @{ AccountId = $AccountId; Token = $Token } | Export-Clixml $CredentialFile
}

function Get-CloudflareAccount {
    if (-not (Test-Path $CredentialFile)) {
        throw "This computer isn't connected to Cloudflare yet. Run Setup in the tools folder first."
    }
    $saved = Import-Clixml $CredentialFile
    [pscustomobject]@{ AccountId = $saved.AccountId; Token = (ConvertTo-PlainText $saved.Token) }
}

# Call the Cloudflare API and return the "result" part of the response.
function Invoke-Cloudflare {
    param(
        [string]$Method,
        [string]$Path,
        $Body,
        [string]$ContentType = 'application/json',
        [string]$Token
    )
    if (-not $Token) { $Token = (Get-CloudflareAccount).Token }
    $params = @{
        Method  = $Method
        Uri     = "$ApiBase$Path"
        Headers = @{ Authorization = "Bearer $Token" }
    }
    if ($null -ne $Body) {
        if ($Body -is [string] -or $Body -is [byte[]]) { $params.Body = $Body }
        else { $params.Body = ($Body | ConvertTo-Json -Depth 10 -Compress) }
        $params.ContentType = $ContentType
    }
    try {
        $response = Invoke-RestMethod @params
    } catch {
        $detail = $_.ErrorDetails.Message
        if (-not $detail) { $detail = $_.Exception.Message }
        throw "Cloudflare request failed ($Method $Path): $detail"
    }
    if ($response.PSObject.Properties.Name -contains 'success' -and -not $response.success) {
        throw "Cloudflare reported an error ($Method $Path): $($response.errors | ConvertTo-Json -Compress)"
    }
    $response.result
}

# Build a multipart/form-data body by hand (Windows PowerShell 5.1 has no -Form option).
# Each part is a hashtable: Name, Value (text), and optionally FileName and ContentType.
function New-MultipartBody([object[]]$Parts) {
    $boundary = '----SiteTools' + [Guid]::NewGuid().ToString('N')
    $sb = New-Object System.Text.StringBuilder
    foreach ($p in $Parts) {
        [void]$sb.Append("--$boundary`r`n")
        $disposition = "Content-Disposition: form-data; name=`"$($p.Name)`""
        if ($p.FileName) { $disposition += "; filename=`"$($p.FileName)`"" }
        [void]$sb.Append("$disposition`r`n")
        if ($p.ContentType) { [void]$sb.Append("Content-Type: $($p.ContentType)`r`n") }
        [void]$sb.Append("`r`n$($p.Value)`r`n")
    }
    [void]$sb.Append("--$boundary--`r`n")
    @{
        Bytes       = [Text.Encoding]::UTF8.GetBytes($sb.ToString())
        ContentType = "multipart/form-data; boundary=$boundary"
    }
}

function Wait-ForEnter {
    Write-Host ""
    Read-Host "Press Enter to close" | Out-Null
}
