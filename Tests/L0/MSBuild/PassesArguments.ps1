[cmdletbinding()]
param()

# Arrange.
. $PSScriptRoot\..\..\lib\Initialize-Test.ps1
Register-Mock Trace-VstsEnteringInvocation
Register-Mock Trace-VstsLeavingInvocation
Register-Mock Import-VstsLocStrings
$variableSets = @(
    @{ Clean = $false ; RestoreNugetPackages = $false ; LogProjectEvents = $false ; CreateLogFile = $false }
    @{ Clean = $false ; RestoreNugetPackages = $false ; LogProjectEvents = $false ; CreateLogFile = $true }
    @{ Clean = $false ; RestoreNugetPackages = $false ; LogProjectEvents = $true ; CreateLogFile = $false }
    @{ Clean = $false ; RestoreNugetPackages = $true ; LogProjectEvents = $false ; CreateLogFile = $false }
    @{ Clean = $true ; RestoreNugetPackages = $false ; LogProjectEvents = $false ; CreateLogFile = $false }
)
foreach ($variableSet in $variableSets) {
    Unregister-Mock Get-VstsInput
    Unregister-Mock Get-SolutionFiles
    Unregister-Mock Format-MSBuildArguments
    Unregister-Mock Select-MSBuildLocation
    Unregister-Mock Invoke-BuildTools
    Register-Mock Get-VstsInput { 'Some input method' } -- -Name MSBuildLocationMethod
    Register-Mock Get-VstsInput { 'Some input location' } -- -Name MSBuildLocation
    Register-Mock Get-VstsInput { 'Some input arguments' } -- -Name MSBuildArguments
    Register-Mock Get-VstsInput { 'Some input solution' } -- -Name Solution -Require
    Register-Mock Get-VstsInput { 'Some input platform' } -- -Name Platform
    Register-Mock Get-VstsInput { 'Some input configuration' } -- -Name Configuration
    Register-Mock Get-VstsInput { $variableSet.Clean } -- -Name Clean -AsBool
    Register-Mock Get-VstsInput { $variableSet.RestoreNuGetPackages } -- -Name RestoreNuGetPackages -AsBool
    Register-Mock Get-VstsInput { $variableSet.LogProjectEvents } -- -Name LogProjectEvents -AsBool
    Register-Mock Get-VstsInput { $variableSet.CreateLogFile } -- -Name CreateLogFile -AsBool
    Register-Mock Get-VstsInput { 'Some input version' } -- -Name MSBuildVersion
    Register-Mock Get-VstsInput { 'Some input architecture' } -- -Name MSBuildArchitecture
    Register-Mock Get-SolutionFiles { 'Some solution 1', 'Some solution 2' } -- -Solution 'Some input solution'
    Register-Mock Format-MSBuildArguments { 'Some formatted arguments' } -- -MSBuildArguments 'Some input arguments' -Platform 'Some input platform' -Configuration 'Some input configuration'
    Register-Mock Select-MSBuildLocation { 'Some location' } -- -Method 'Some input method' -Location 'Some input location' -Version 'Some input version' -Architecture 'Some input architecture'
    Register-Mock Invoke-BuildTools { 'Some build output line 1', 'Some build output line 2' }

    # Act.
    $output = & $PSScriptRoot\..\..\..\Tasks\MSBuild\MSBuild.ps1

    # Assert.
    Assert-AreEqual ('Some build output line 1', 'Some build output line 2') $output
    Assert-WasCalled Invoke-BuildTools -- -NuGetRestore: $variableSet.RestoreNuGetPackages -SolutionFiles @('Some solution 1', 'Some solution 2') -MSBuildLocation 'Some location' -MSBuildArguments 'Some formatted arguments' -Clean: $variableSet.Clean -NoTimelineLogger: $(!$variableSet.LogProjectEvents) -CreateLogFile: $variableSet.CreateLogFile
}
