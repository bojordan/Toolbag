# Node.js version management via fnm (https://github.com/Schniz/fnm).
#
# Install fnm with:  winget install Schniz.fnm
# Then a Node version with:  fnm install --lts
#
# Version pinning is driven by a committed .nvmrc (or .node-version, or an
# "engines.node" range in package.json) so that every machine and CI agent
# resolves the same Node version from the same file.

if (-not (Get-Command fnm -ErrorAction SilentlyContinue)) {
    Write-Verbose "fnm not found; skipping Node version management (winget install Schniz.fnm)"
    return
}

# Deliberately NOT using fnm's own --use-on-cd hook. Upstream implements it by
# installing an AllScope alias over 'cd', which (a) only fires for 'cd' and
# misses Set-Location/pushd/popd, and (b) collides with this profile's existing
# LocationChangedAction. Driving the switch from LocationChangedAction instead
# covers every form of directory change with no alias shadowing.
#
# --version-file-strategy recursive: also searches parent directories, so a
# single .nvmrc at a repo root covers Node projects that live in nested
# subdirectories (e.g. src/Foo/ClientApp). Without this, jumping straight into
# a nested folder silently falls back to the default version.
fnm env --version-file-strategy recursive --shell powershell | Out-String | Invoke-Expression

function global:Update-FnmNodeVersion {
    # Cheap guard: only shell out to fnm when this directory or one of its
    # ancestors actually declares a Node version. Walking up is a few Test-Path
    # calls and keeps fnm off the hot path for unrelated directory changes.
    $dir = (Get-Location).ProviderPath
    if (-not $dir) { return }

    while ($dir) {
        foreach ($f in '.nvmrc', '.node-version', 'package.json') {
            if (Test-Path -LiteralPath (Join-Path $dir $f) -PathType Leaf) {
                # --silent-if-unchanged keeps this quiet when already correct,
                # so it only announces an actual version switch.
                fnm use --silent-if-unchanged
                $script:FnmProjectVersionActive = $true
                return
            }
        }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }

    # No version file anywhere up the tree. If a project version is still
    # applied from a previous directory, drop back to the machine default so a
    # shell that wandered out of a pinned repo doesn't silently keep that
    # repo's Node. The flag means this costs nothing on repeated navigation
    # through unpinned directories.
    if ($script:FnmProjectVersionActive) {
        fnm use default --silent-if-unchanged
        $script:FnmProjectVersionActive = $false
    }
}
