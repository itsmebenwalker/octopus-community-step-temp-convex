[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [string]
    $Version,
    [Parameter(Mandatory=$true)]
    [string]
    $PackageName,
    [Parameter(Mandatory=$true)]
    [string]
    $Path
)

$ArtifactsDir = Join-Path $PSScriptRoot '..' 'artifacts'
$SourcePath = Join-Path $PSScriptRoot '..' $Path
$DestinationPath = Join-Path $ArtifactsDir "$PackageName.$Version.zip"

if (-Not (Test-Path -Path $ArtifactsDir)) {
    New-Item -Path $ArtifactsDir -ItemType Directory | Out-Null
}

Compress-Archive -Path $SourcePath -DestinationPath $DestinationPath -Force
Write-Host "Created package: $DestinationPath"