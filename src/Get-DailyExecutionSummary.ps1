<#
.SYNOPSIS
    Generates daily test execution analytics from synthetic execution data.

.DESCRIPTION
    Groups test runs by PlannedDate and calculates daily Planned,
    Passed, Failed, Blocked, Not Executed, Executed, and Execution
    Percentage.

    For this project:
        Executed = Passed + Failed

    Blocked and Not Executed are not counted as Executed.

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
Write-Host " DAILY EXECUTION ANALYTICS"
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
    $Run.Status      = ([string]$Run.Status).Trim()
    $Run.PlannedDate = ([string]$Run.PlannedDate).Trim()
}

$DailyGroups =
    $TestRuns |
    Group-Object PlannedDate |
    Sort-Object Name

$DailySummary = foreach ($Group in $DailyGroups) {

    $Rows = @($Group.Group)

    $Planned = $Rows.Count

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

    $Blocked = @(
        $Rows |
        Where-Object {
            $_.Status -eq "Blocked"
        }
    ).Count

    $NotExecuted = @(
        $Rows |
        Where-Object {
            $_.Status -eq "Not Executed"
        }
    ).Count

    $Executed =
        $Passed +
        $Failed

    if ($Planned -gt 0) {

        $ExecutionPercentage =
            [math]::Round(
                ($Executed / $Planned) * 100,
                2
            )
    }
    else {

        $ExecutionPercentage = 0
    }

    [pscustomobject]@{
        Date                = $Group.Name
        Planned             = $Planned
        Passed              = $Passed
        Failed              = $Failed
        Blocked             = $Blocked
        NotExecuted         = $NotExecuted
        Executed            = $Executed
        ExecutionPercentage = "$ExecutionPercentage%"
    }
}

$DailySummary |
    Format-Table -AutoSize

Write-Host ""
Write-Host "============================================================"
Write-Host " DAILY VALIDATION"
Write-Host "============================================================"
Write-Host ""

$ValidationResults = foreach ($Day in $DailySummary) {

    $StatusTotal =
        $Day.Passed +
        $Day.Failed +
        $Day.Blocked +
        $Day.NotExecuted

    [pscustomobject]@{
        Date       = $Day.Date
        Validation = "Daily status totals equal Planned"
        Expected   = $Day.Planned
        Actual     = $StatusTotal
        Result     = if (
            $StatusTotal -eq $Day.Planned
        ) {
            "PASS"
        }
        else {
            "FAIL"
        }
    }
}

$ValidationResults |
    Format-Table -AutoSize

$TotalExecuted =
    (
        $DailySummary |
        Measure-Object `
            -Property Executed `
            -Sum
    ).Sum

Write-Host ""
Write-Host "Total Executed across all days: $TotalExecuted"
Write-Host ""
Write-Host "Daily execution analytics completed successfully."
Write-Host ""
