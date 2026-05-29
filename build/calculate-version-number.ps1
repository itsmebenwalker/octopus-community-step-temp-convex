[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $RunNumber,
    [Parameter()]
    [string]
    $Branch
)

# Sometimes the branch will be a full path, e.g., 'refs/heads/master'.
# If so we'll base our logic just on the last part.
if ($Branch.Contains("/"))
{
    $Branch = $Branch.substring($Branch.lastIndexOf("/")).trim("/")
}

# Filter out illegal characters, replace with '-'
$Branch = ($Branch -replace '[/\\ _\.]','-')

$Version = "1.$RunNumber.0"
$Channel = "Full"
if($Branch -ine "main") {
    $Version = "$Version-$Branch"
    $Channel = "Development"
}

echo "VERSION=$Version" >> $env:GITHUB_ENV
echo "CHANNEL=$Channel" >> $env:GITHUB_ENV