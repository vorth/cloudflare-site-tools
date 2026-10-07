# One-time step: save the Cloudflare API token (and the account it belongs to) on this computer.
# Every site folder uses this account.

. "$PSScriptRoot\Common.ps1"

try {
    Write-Host "Cloudflare setup" -ForegroundColor Cyan
    Write-Host ""

    $token = Read-Host "Cloudflare API token (typing is hidden)" -AsSecureString
    $plain = ConvertTo-PlainText $token
    if (-not $plain) { throw "An API token is required." }

    # Find the account this token can use, so nobody has to look up the account ID.
    Write-Host "Looking up your Cloudflare account..."
    $accounts = @()
    try { $accounts = @(Invoke-Cloudflare -Method GET -Path '/accounts' -Token $plain) } catch { }

    if ($accounts.Count -eq 1) {
        $accountId = $accounts[0].id
        Write-Host "Using account: $($accounts[0].name)"
    } elseif ($accounts.Count -gt 1) {
        for ($i = 0; $i -lt $accounts.Count; $i++) { Write-Host "  $($i + 1)) $($accounts[$i].name)" }
        $choice = [int](Read-Host "Which account should the websites use? (number)")
        if ($choice -lt 1 -or $choice -gt $accounts.Count) { throw "That isn't one of the listed numbers." }
        $accountId = $accounts[$choice - 1].id
    } else {
        Write-Host "The token couldn't list accounts, so the account ID is needed."
        Write-Host "It's the long code after dash.cloudflare.com/ in the browser's address bar."
        $accountId = (Read-Host "Cloudflare account ID").Trim()
        if (-not $accountId) { throw "An account ID is required." }
    }

    Write-Host "Checking the token..."
    # Listing this account's Workers proves the token and account ID work together.
    Invoke-Cloudflare -Method GET -Path "/accounts/$accountId/workers/scripts" -Token $plain | Out-Null

    Save-CloudflareAccount $accountId $token
    Write-Host ""
    Write-Host "Setup complete. You can now use Publish in each site's folder." -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "Setup failed: $($_.Exception.Message)" -ForegroundColor Red
}
Wait-ForEnter
