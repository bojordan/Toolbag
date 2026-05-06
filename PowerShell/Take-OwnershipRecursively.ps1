function Test-AllSubFolders{
    # Recursively visit all subfolders of $Folder
    # and if you get Access Denied error on any of them
    # call Take-OwnershipOfOneFolder on it
    param(
        [String]$Folder,
        [String]$MyDomain,
        [String]$MyAdmin
    )
    $error.Clear()
    $ErrorArray = @()
    (Get-ChildItem $Folder -Directory -Recurse -ErrorAction SilentlyContinue | Select FullName) > $null
    if ($error) {
        $ErrorArray = $error + $ErrorArray # '+$ErrorArray' seems silly but not sure
        foreach ($err in $ErrorArray) {
            if ($err.FullyQualifiedErrorId -eq "DirUnauthorizedAccessError,Microsoft.PowerShell.Commands.GetChildItemCommand") {
                $FailedFolder = $err.TargetObject
                echo "Access Error on '$FailedFolder', attempting to fix" 
                Take-OwnershipOfOneFolder  $FailedFolder $MyDomain $MyAdmin
                if ($FailedFolder -ne $Folder) {
                    Test-AllSubFolders       $FailedFolder $MyDomain $MyAdmin
                } else {
                    echo "FAILED for $FailedFolder"
                }
}}}}

function Take-OwnershipOfOneFolder {
    # Take ownership of $Folder (takeown.exe /A /F) and also
    # give Full Control with "ContainerInherit,ObjectInherit" to 
    # $MyDomain\$MyAdmin and SYSTEM which result in also giving 
    # full control to files/folders under $Folder
    # IT DOES NOT RECURSE TO SUB-SUBFOLDERS OF $Folder
    param(
        [String]$Folder,
        [String]$MyDomain,
        [String]$MyAdmin
    )
    echo "    Calling: takeown.exe /A /F $Folder"
    $out = (takeown.exe /A /F $Folder)
    if ($out -notlike 'SUCCESS*') {
        echo "    FAILED takeown for '$Folder' (output of takeown follows)"
        echo $out
        return
    }

    echo "    Reading ACLs"
    $CurrentACL = Get-Acl $Folder
    
    echo "    Adding ACL: FullControll to NT Authority\SYSTEM"
    $SystemACLPermission = "NT AUTHORITY\SYSTEM","FullControl","ContainerInherit,ObjectInherit","None","Allow"
    $SystemAccessRule = new-object System.Security.AccessControl.FileSystemAccessRule $SystemACLPermission
    $CurrentACL.AddAccessRule($SystemAccessRule)
    
    echo "    Adding ACL: FullControll to $MyDomain\$MyAdmin for $Folder"
    $AdminACLPermission = "$MyDomain\$MyAdmin","FullControl","ContainerInherit,ObjectInherit","None","Allow"
    $SystemAccessRule = new-object System.Security.AccessControl.FileSystemAccessRule $AdminACLPermission
    $CurrentACL.AddAccessRule($SystemAccessRule)
    
    echo "    Setting ACL"
    Set-Acl -Path $Folder -AclObject $CurrentACL
}

function Take-OwnershipRecursively() {
    # Run this from an elevated powershell as user $MyDomain\$MyAdmin and it will
    # give ownership of $Folder and all its subfolders recursively to SYSTEM and 
    # $MyDomain\$MyAdmin and it will also give Full Control to $MyDomain\$MyAdmin
    # SYSTEM on any folders where it gets Access Denied and their files and subfolders
    # (It gives "FullControl","ContainerInherit,ObjectInherit")
   param(
        [String]$Folder,
        [String]$MyDomain,
        [String]$MyAdmin,
        [String]$LogFile
    )
    Start-Transcript $LogFile
    Take-OwnershipOfOneFolder $Folder $MyDomain $MyAdmin
    Test-AllSubFolders $Folder $MyDomain $MyAdmin
    Stop-Transcript
}

param(
    [String]$Folder,
    [String]$MyDomain,
    [String]$MyAdmin,
    [String]$LogFile
)

Take-OwnershipRecursively $Folder $MyDomain $MyAdmin $LogFile