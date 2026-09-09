<#
.SYNOPSIS
    Calculates actual daily test execution using ExecutionDate.

.DESCRIPTION
    Determines how many test runs were actually executed on each
    calendar day.

    For this project:
        Executed = Passed + Failed

    The calculation uses ExecutionDate rather than PlannedDate.

    This distinction is important because a test may be planned for
    one date but actually executed on another date.

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
Write-Host " ACTUAL DAILY EXECUTION"
Write-Host "============================================================"
Write-Host ""

if (-not (Test-Path -LiteralPath $InputFile)) {
    throw "Input file not found: $InputFile"
}

$TestRuns = @(
    Import-Csv -LiteralPath $InputFile
)

if ($TestRuns.Count -eq 0) {
    throw "No test execution records were found."
}

foreach ($Run in $TestRuns) {
    $Run.Status        = ([string]$Run.Status).Trim()
    $Run.ExecutionDate = ([string]$Run.ExecutionDate).Trim()
}

# Only Passed and Failed are treated as executed.
$ExecutedRuns = @(
    $TestRuns |
        Where-Object {
            $_.Status -in @("Passed", "Failed") -and
            -not [string]::IsNullOrWhiteSpace($_.ExecutionDate)
        }
)

$DailyGroups =
    $ExecutedRuns |
        Group-Object ExecutionDate |
        Sort-Object Name

$DailySummary = foreach ($Group in $DailyGroups) {

    $Rows = @($Group.Group)

    $Passed = @(
        $Rows |
            Where-Object {
                $_.Status -eq "Passed"
            }
    ).Count

    $Failed = @(
        $Rows |
            Where-Object {
                $_.Status -eq "Failed"
            }
    ).Count

    $Executed =
        $Passed +
        $Failed

    [pscustomobject]@{
        ExecutionDate = $Group.Name
        Passed        = $Passed
        Failed        = $Failed
        Executed      = $Executed
    }
}

$DailySummary |
    Format-Table -AutoSize

Write-Host ""
Write-Host "============================================================"
Write-Host " VALIDATION"
Write-Host "============================================================"
Write-Host ""

$DailyExecutedTotal =
    (
        $DailySummary |
            Measure-Object `
                -Property Executed `
                -Sum
    ).Sum

$OverallExecutedTotal =
    $ExecutedRuns.Count

$ValidationResult =
    if ($DailyExecutedTotal -eq $OverallExecutedTotal) {
        "PASS"
    }
    else {
        "FAIL"
    }

$Validation = [pscustomobject]@{
    Validation = "Daily execution totals reconcile with overall executed"
    Expected   = $OverallExecutedTotal
    Actual     = $DailyExecutedTotal
    Result     = $ValidationResult
}

$Validation |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Total actual executions: $DailyExecutedTotal"
Write-Host ""
Write-Host "Actual daily execution analysis completed successfully."
Write-Host ""
