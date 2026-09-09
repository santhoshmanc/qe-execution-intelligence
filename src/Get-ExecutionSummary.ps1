<#
.SYNOPSIS
    Generates a test execution summary from synthetic execution data.

.DESCRIPTION
    Reads test execution records from the sample dataset and calculates
    Planned, Passed, Failed, Blocked, Not Executed, Executed, and
    Execution Percentage.

    For this project:
        Executed = Passed + Failed

    Blocked and Not Executed test runs are not counted as Executed.

.NOTES
    Project: QE Execution Intelligence
    Author : Santhosh
#>

[CmdletBinding()]
param(
    [string]$InputFile = (
        Join-Path `
            (Split-Path $PSScriptRoot -Parent) `
            "sample-data/test-runs.csv"
    )
)

Write-Host ""
Write-Host "============================================================"
Write-Host " QE EXECUTION INTELLIGENCE"
Write-Host " TEST EXECUTION SUMMARY"
Write-Host "============================================================"
Write-Host ""

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: $InputFile"
}

$TestRuns = @(
    Import-Csv -LiteralPath $InputFile
)

if ($TestRuns.Count -eq 0) {
    throw "No test execution records were found in the input file."
}

# ------------------------------------------------------------
# Normalize execution statuses
# ------------------------------------------------------------

foreach ($Run in $TestRuns) {

    $Run.Status = ([string]$Run.Status).Trim()
}

# ------------------------------------------------------------
# Calculate execution metrics
# ------------------------------------------------------------

$Planned = $TestRuns.Count

$Passed = @(
    $TestRuns |
        Where-Object {
            $_.Status -eq "Passed"
        }
).Count

$Failed = @(
    $TestRuns |
        Where-Object {
            $_.Status -eq "Failed"
        }
).Count

$Blocked = @(
    $TestRuns |
        Where-Object {
            $_.Status -eq "Blocked"
        }
).Count

$NotExecuted = @(
    $TestRuns |
        Where-Object {
            $_.Status -eq "Not Executed"
        }
).Count

# Project execution definition:
# Executed = Passed + Failed

$Executed = $Passed + $Failed

if ($Planned -gt 0) {

    $ExecutionPercentage = [math]::Round(
        ($Executed / $Planned) * 100,
        2
    )
}
else {

    $ExecutionPercentage = 0
}

# ------------------------------------------------------------
# Display summary
# ------------------------------------------------------------

$Summary = [pscustomobject]@{

    Planned             = $Planned
    Passed              = $Passed
    Failed              = $Failed
    Blocked             = $Blocked
    NotExecuted         = $NotExecuted
    Executed            = $Executed
    ExecutionPercentage = "$ExecutionPercentage%"
}

$Summary |
    Format-List

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

Write-Host ""
Write-Host "============================================================"
Write-Host " VALIDATION"
Write-Host "============================================================"
Write-Host ""

$StatusTotal =
    $Passed +
    $Failed +
    $Blocked +
    $NotExecuted

$UniqueTestRunCount =
    @(
        $TestRuns.TestRunId |
            Sort-Object -Unique
    ).Count

$DuplicateTestRunCount =
    $Planned - $UniqueTestRunCount

$ValidationResults = @(

    [pscustomobject]@{
        Validation = "Executed equals Passed + Failed"
        Expected   = $Passed + $Failed
        Actual     = $Executed
        Result     = if (
            $Executed -eq ($Passed + $Failed)
        ) {
            "PASS"
        }
        else {
            "FAIL"
        }
    }

    [pscustomobject]@{
        Validation = "Status totals equal Planned"
        Expected   = $Planned
        Actual     = $StatusTotal
        Result     = if (
            $StatusTotal -eq $Planned
        ) {
            "PASS"
        }
        else {
            "FAIL"
        }
    }

    [pscustomobject]@{
        Validation = "Duplicate TestRunIds"
        Expected   = 0
        Actual     = $DuplicateTestRunCount
        Result     = if (
            $DuplicateTestRunCount -eq 0
        ) {
            "PASS"
        }
        else {
            "FAIL"
        }
    }
)

$ValidationResults |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Execution summary completed successfully."
Write-Host ""
