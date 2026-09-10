<#
.SYNOPSIS
    Compares planned execution dates with actual execution dates.

.DESCRIPTION
    Identifies whether executed test runs were completed on time,
    early, or later than their planned execution date.

    The report also compares planned execution volume with actual
    execution volume for each calendar date.

    For this project:
        Executed = Passed + Failed

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
Write-Host " PLANNED VS ACTUAL EXECUTION VARIANCE"
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
    $Run.PlannedDate   = ([string]$Run.PlannedDate).Trim()
    $Run.ExecutionDate = ([string]$Run.ExecutionDate).Trim()
}

# ------------------------------------------------------------
# Executed population
# ------------------------------------------------------------

$ExecutedRuns = @(
    $TestRuns |
        Where-Object {
            $_.Status -in @("Passed", "Failed") -and
            -not [string]::IsNullOrWhiteSpace($_.ExecutionDate)
        }
)

# ------------------------------------------------------------
# Record-level timing analysis
# ------------------------------------------------------------

$TimingAnalysis = foreach ($Run in $ExecutedRuns) {

    $PlannedDate =
        [datetime]::ParseExact(
            $Run.PlannedDate,
            "yyyy-MM-dd",
            $null
        )

    $ExecutionDate =
        [datetime]::ParseExact(
            $Run.ExecutionDate,
            "yyyy-MM-dd",
            $null
        )

    $VarianceDays =
        ($ExecutionDate - $PlannedDate).Days

    $Timing =
        if ($VarianceDays -gt 0) {
            "Delayed"
        }
        elseif ($VarianceDays -lt 0) {
            "Early"
        }
        else {
            "On Time"
        }

    [pscustomobject]@{
        TestRunId     = $Run.TestRunId
        TestCaseId    = $Run.TestCaseId
        Status        = $Run.Status
        PlannedDate   = $Run.PlannedDate
        ExecutionDate = $Run.ExecutionDate
        VarianceDays  = $VarianceDays
        Timing        = $Timing
    }
}

Write-Host "EXECUTION TIMING DETAIL"
Write-Host ""

$TimingAnalysis |
    Sort-Object PlannedDate, TestRunId |
    Format-Table -AutoSize

# ------------------------------------------------------------
# Timing summary
# ------------------------------------------------------------

$OnTimeCount =
    @(
        $TimingAnalysis |
            Where-Object {
                $_.Timing -eq "On Time"
            }
    ).Count

$DelayedCount =
    @(
        $TimingAnalysis |
            Where-Object {
                $_.Timing -eq "Delayed"
            }
    ).Count

$EarlyCount =
    @(
        $TimingAnalysis |
            Where-Object {
                $_.Timing -eq "Early"
            }
    ).Count

Write-Host ""
Write-Host "============================================================"
Write-Host " TIMING SUMMARY"
Write-Host "============================================================"
Write-Host ""

[pscustomobject]@{
    TotalExecuted = $TimingAnalysis.Count
    OnTime        = $OnTimeCount
    Delayed       = $DelayedCount
    Early         = $EarlyCount
} |
    Format-List

# ------------------------------------------------------------
# Daily planned vs actual volume
# ------------------------------------------------------------

$AllDates =
    @(
        (
            $ExecutedRuns.PlannedDate +
            $ExecutedRuns.ExecutionDate
        ) |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            } |
            Sort-Object -Unique
    )

$DailyVariance = foreach ($Date in $AllDates) {

    $PlannedExecuted =
        @(
            $ExecutedRuns |
                Where-Object {
                    $_.PlannedDate -eq $Date
                }
        ).Count

    $ActualExecuted =
        @(
            $ExecutedRuns |
                Where-Object {
                    $_.ExecutionDate -eq $Date
                }
        ).Count

    [pscustomobject]@{
        Date            = $Date
        PlannedExecuted = $PlannedExecuted
        ActualExecuted  = $ActualExecuted
        Variance        = $ActualExecuted - $PlannedExecuted
    }
}

Write-Host ""
Write-Host "============================================================"
Write-Host " DAILY PLANNED VS ACTUAL"
Write-Host "============================================================"
Write-Host ""

$DailyVariance |
    Format-Table -AutoSize

# ------------------------------------------------------------
# Delayed execution detail
# ------------------------------------------------------------

$DelayedRuns =
    @(
        $TimingAnalysis |
            Where-Object {
                $_.Timing -eq "Delayed"
            }
    )

Write-Host ""
Write-Host "============================================================"
Write-Host " DELAYED EXECUTIONS"
Write-Host "============================================================"
Write-Host ""

if ($DelayedRuns.Count -gt 0) {

    $DelayedRuns |
        Format-Table `
            TestRunId,
            TestCaseId,
            Status,
            PlannedDate,
            ExecutionDate,
            VarianceDays `
            -AutoSize
}
else {

    Write-Host "No delayed executions found."
}

# ------------------------------------------------------------
# Validation
# ------------------------------------------------------------

$PlannedTotal =
    (
        $DailyVariance |
            Measure-Object `
                -Property PlannedExecuted `
                -Sum
    ).Sum

$ActualTotal =
    (
        $DailyVariance |
            Measure-Object `
                -Property ActualExecuted `
                -Sum
    ).Sum

$ExpectedTotal =
    $ExecutedRuns.Count

$ValidationResult =
    if (
        $PlannedTotal -eq $ExpectedTotal -and
        $ActualTotal -eq $ExpectedTotal
    ) {
        "PASS"
    }
    else {
        "FAIL"
    }

Write-Host ""
Write-Host "============================================================"
Write-Host " VALIDATION"
Write-Host "============================================================"
Write-Host ""

[pscustomobject]@{
    Validation = "Planned and actual totals reconcile"
    Expected   = $ExpectedTotal
    Planned    = $PlannedTotal
    Actual     = $ActualTotal
    Result     = $ValidationResult
} |
    Format-Table -AutoSize

Write-Host ""
Write-Host "Planned vs actual variance analysis completed successfully."
Write-Host ""
