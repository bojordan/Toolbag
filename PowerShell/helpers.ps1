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