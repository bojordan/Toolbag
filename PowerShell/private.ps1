# Loader for work-specific profile functions.
#
# The actual functions live in a peer repo cloned beside this one (the public
# Toolbag repo). We resolve that peer generically as a sibling directory named
# "Toolbag_*" so no specific repo name is hardcoded here, then dot-source its
# ps\profile.private.ps1. This resolves on any machine where the two repos are
# cloned side by side; it silently no-ops where the peer is not present.

$reposParent = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)  # ...\Toolbag -> repos root
$peer = Get-ChildItem -LiteralPath $reposParent -Directory -Filter 'Toolbag_*' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne 'Toolbag' } |
    Select-Object -First 1

if ($peer) {
    $privateFns = Join-Path $peer.FullName 'ps\profile.private.ps1'
    if (Test-Path $privateFns) {
        . $privateFns
    } else {
        Write-Verbose "Peer private profile not found at $privateFns"
    }
} else {
    Write-Verbose "No peer 'Toolbag_*' repo found beside $reposParent; skipping private functions."
}
