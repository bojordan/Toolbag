function which {
    param([Parameter(Mandatory=$true)][string]$Command)
    Get-Command $Command | Select -ExpandProperty Path
}

function Set-Title {
    param(
        [Parameter(position = 0, Mandatory = $True)][string] $Title
    )

    $host.UI.RawUI.WindowTitle = $Title
}

function Convert-MessageBody {
    param([Parameter(Mandatory=$true)][string]$EncodedBody)
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($EncodedBody))
}

function ConvertFrom-UnixTime {
    param([Parameter(Mandatory=$true)][long]$SecondsFromEpoch)
    return ([DateTime]'1/1/1970').AddSeconds($SecondsFromEpoch)
}

function ConvertTo-UnixTime {
    param([Parameter(Mandatory=$true)][DateTime]$DateTime)
    return Get-Date -Date ($DateTime) -UFormat %s
}

function Get-GitRemote {
    git config --get remote.origin.url
}

# Walk up from $Path looking for a .git entry (a directory in a normal repo, a
# file in a worktree/submodule) and return the repo root, or $null if the path
# isn't inside a git repo. Pure PowerShell so it doesn't spawn git on every
# directory change.
function Get-GitRepoRoot {
    param([string]$Path = (Get-Location).Path)

    $dir = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    while ($dir) {
        if (Test-Path -LiteralPath (Join-Path $dir.FullName '.git')) {
            return $dir.FullName
        }
        $dir = $dir.Parent
    }
    return $null
}

# https://stackoverflow.com/questions/5188320/how-can-i-get-a-list-of-git-branches-ordered-by-most-recent-commit
function Get-GitBranchList {
    git branch --sort=-committerdate --format='%(HEAD) %(color:yellow)%(refname:short)%(color:reset) - %(color:red)%(objectname:short)%(color:reset) - %(contents:subject) - %(authorname) (%(color:green)%(committerdate:relative)%(color:reset))'
}

# https://stackoverflow.com/questions/4147164/how-can-i-see-the-assembly-version-of-a-net-assembly-in-windows-vista-and-newer
function Get-AssemblyVersion {
    param(
        [Parameter()][string]$FileName,
        [Parameter(ValueFromPipeline)][System.IO.FileInfo]$File
    )

    if ($null -ne $File) {
        $FileName = $File.FullName
    }

    $fullFile = Get-ChildItem $FileName

    [Reflection.AssemblyName]::GetAssemblyName($fullFile.FullName).Version
}

function Decode-Clipboard {
    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String("$(Get-ClipBoard)"))
}

function Decode-Text {
    param(
        [Parameter(ValueFromPipeline)][string]$Base64EncodedValue
    )

    [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Base64EncodedValue))
}

function Decode-Jwt {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline)][string]$Token
    )
    foreach ($i in 0..1) {
        $data = $Token.Split('.')[$i].Replace('-', '+').Replace('_', '/')
        switch ($data.Length % 4) {
            0 {break}
            2 {$data += '=='}
            3 {$data += '='}
        }
        $output = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($data))
        $output = $output.Replace("{`"", "{`n  `"").Replace("`"}", "`"`n}").Replace(",`"", ",`n  `"")
        $output
    }
}

# Wrap the VS Code CLI so that launching a folder (e.g. `code .`) prefers a
# single *.code-workspace file in that folder over opening the bare folder.
# If the target directory contains exactly one workspace file, that workspace
# is opened instead; zero or multiple workspace files, non-directory targets,
# or any option/flag arguments pass straight through to code unchanged.
function code {
    $codeCmd = Get-Command code.cmd -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $codeCmd) {
        $codeCmd = Get-Command code -CommandType Application -ErrorAction SilentlyContinue |
            Select-Object -First 1
    }
    if (-not $codeCmd) {
        Write-Error 'Unable to locate the VS Code CLI (code) on PATH.'
        return
    }

    $forwardArgs = $args
    # Only special-case a single positional directory argument (e.g. `code .`).
    if ($args.Count -eq 1 -and $args[0] -is [string] -and $args[0] -notlike '-*') {
        $target = $args[0]
        if (Test-Path -LiteralPath $target -PathType Container) {
            $workspaces = @(Get-ChildItem -LiteralPath $target -Filter '*.code-workspace' -File -ErrorAction SilentlyContinue)
            if ($workspaces.Count -eq 1) {
                $forwardArgs = @($workspaces[0].FullName)
            }
        }
    }

    & $codeCmd.Source @forwardArgs
}