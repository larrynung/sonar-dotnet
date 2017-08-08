<#

.SYNOPSIS
This script controls the analyzer build process (from buildling to creating the NuGet packages).

.DESCRIPTION
Usage: build.ps1
    -restore              Restore packages
    -build                Build the solution (based on analyzerKind)
    -test                 Run unit tests
    -pack                 Create the NuGet packages and extra metadata
    -release              Perform release build (default is debug)
    -analyzerKind         The kind of analyzer to build: Classic, VS2015 or VS2017 (default is Classic)

#>

[CmdletBinding(PositionalBinding = $false)]
param (
    # Steps to execute
    [switch]$restore = $false,
    [switch]$build = $false,
    [switch]$coverage = $false,
    [switch]$pack = $false,

    # Test options
    [switch]$test = $false,
    [switch]$its = $false,

    # Build output options
    [switch]$release = $false,
    [ValidateSet("Classic", "VS2015", "VS2017")][string]$analyzerKind = "Classic"
)

Set-StrictMode -version 2.0
$ErrorActionPreference = "Stop"

try {
    . (Join-Path $PSScriptRoot "build-utils.ps1")
    Push-Location "${PSScriptRoot}\..\..\sonaranalyzer-dotnet"

    $buildConfiguration = if ($release) { "Release" } else { "Debug" }
    $binPath = "bin\${analyzerKind}\${buildConfiguration}"
    $solutionName =
        switch ($analyzerKind) {
            "Classic" { "SonarAnalyzer.sln" }
            "VS2015" { "SonarAnalyzer.VS2015.sln" }
            "VS2017" { "SonarAnalyzer.VS2017.sln" }
        }
    $msbuildVersion =
        switch ($analyzerKind) {
            "VS2017" { "15.0" }
            Default { "14.0" }
        }

    Write-Host "Solution to build: $solutionName"
    Write-Host "Build configuration: $buildConfiguration"
    Write-Host "Bin folder to use: $binPath"
    Write-Host "MSBuild: ${msbuildVersion}"

    if ($restore) {
        Restore-Packages $solutionName
    }

    if ($build) {
        Invoke-MSBuild $msbuildVersion $solutionName `
            /v:q `
            /consoleloggerparameters:Summary `
            /m `
            /p:configuration=$buildConfiguration `
            /p:DeployExtension=false `
    }

    if ($test) {
        Invoke-UnitTests $binPath
    }

    if ($its) {
        Invoke-IntegrationTests $msbuildVersion
    }

    if ($coverage) {
        Invoke-CodeCoverage
    }

    if ($pack) {
        New-Metadata $binPath
        New-NuGetPackages $binPath
    }

    exit 0
}
catch {
    Write-Host $_
    Write-Host $_.Exception
    Write-Host $_.ScriptStackTrace
    exit 1
}
finally {
    Pop-Location
}