param(
    [string]$PreviousFile = (Join-Path $PSScriptRoot "../sample-data/previous-test-runs.csv"),
    [string]$CurrentFile  = (Join-Path $PSScriptRoot "../sample-data/current-test-runs.csv"),
    [string]$OutputFile   = (Join-Path $PSScriptRoot "../output/QE-Execution-Intelligence-Dashboard.html")
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "============================================================"
Write-Host " QE EXECUTION INTELLIGENCE"
Write-Host " DASHBOARD GENERATOR"
Write-Host "============================================================"
Write-Host ""

if (-not (Test-Path $PreviousFile)) {
    throw "Previous snapshot not found: $PreviousFile"
}

if (-not (Test-Path $CurrentFile)) {
    throw "Current snapshot not found: $CurrentFile"
}

$outputDirectory = Split-Path -Parent $OutputFile

if (-not (Test-Path $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$previous = @(Import-Csv $PreviousFile)
$current  = @(Import-Csv $CurrentFile)

# ------------------------------------------------------------
# CURRENT SNAPSHOT METRICS
# ------------------------------------------------------------

$totalPlanned = $current.Count

$executedRows = @(
    $current | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.ExecutionDate)
    }
)

$executed    = $executedRows.Count
$passed      = @($current | Where-Object Status -eq "Passed").Count
$failed      = @($current | Where-Object Status -eq "Failed").Count
$blocked     = @($current | Where-Object Status -eq "Blocked").Count
$notExecuted = @($current | Where-Object Status -eq "Not Executed").Count

$completionRate = if ($totalPlanned -gt 0) {
    [math]::Round(($executed / $totalPlanned) * 100, 1)
}
else {
    0
}

$passRate = if ($executed -gt 0) {
    [math]::Round(($passed / $executed) * 100, 1)
}
else {
    0
}

# ------------------------------------------------------------
# PLANNED VS ACTUAL / DELAY ANALYSIS
# ------------------------------------------------------------

$delayedRows = @(
    $executedRows | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.PlannedDate) -and
        ([datetime]$_.ExecutionDate).Date -gt ([datetime]$_.PlannedDate).Date
    }
)

$delayedCount = $delayedRows.Count

$allDates = @(
    ($current.PlannedDate + $current.ExecutionDate) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique
)

$dailyRows = foreach ($date in $allDates) {

    $plannedCount = @(
        $current | Where-Object {
            $_.PlannedDate -eq $date
        }
    ).Count

    $actualCount = @(
        $current | Where-Object {
            $_.ExecutionDate -eq $date
        }
    ).Count

    [PSCustomObject]@{
        Date     = $date
        Planned  = $plannedCount
        Executed = $actualCount
        Variance = $actualCount - $plannedCount
    }
}

# ------------------------------------------------------------
# SNAPSHOT CHANGE ANALYSIS
# ------------------------------------------------------------

$previousById = @{}

foreach ($row in $previous) {
    $previousById[$row.TestRunId] = $row
}

$changes = @()
$newExecutions = 0
$statusChanges = 0
$statusOnlyChanges = 0

foreach ($row in $current) {

    if (-not $previousById.ContainsKey($row.TestRunId)) {

        $changes += [PSCustomObject]@{
            TestRunId = $row.TestRunId
            Previous  = "Not present"
            Current   = $row.Status
            Insight   = "New test run appeared"
        }

        continue
    }

    $old = $previousById[$row.TestRunId]

    $insights = @()

    $oldExecuted = -not [string]::IsNullOrWhiteSpace($old.ExecutionDate)
    $newExecuted = -not [string]::IsNullOrWhiteSpace($row.ExecutionDate)

    if (-not $oldExecuted -and $newExecuted) {
        $newExecutions++
        $insights += "Newly observed execution"
    }

    if ($old.Status -ne $row.Status) {

        $statusChanges++

        $insights += "Status changed: $($old.Status) → $($row.Status)"

        if (
            $oldExecuted -and
            $newExecuted -and
            $old.ExecutionDate -eq $row.ExecutionDate
        ) {
            $statusOnlyChanges++
        }
    }

    if (
        $oldExecuted -and
        $newExecuted -and
        $old.ExecutionDate -ne $row.ExecutionDate
    ) {
        $insights += "Execution date changed"
    }

    if ($insights.Count -gt 0) {

        $previousText =
            "$($old.Status)" +
            $(if ($old.ExecutionDate) { " | $($old.ExecutionDate)" } else { "" })

        $currentText =
            "$($row.Status)" +
            $(if ($row.ExecutionDate) { " | $($row.ExecutionDate)" } else { "" })

        $changes += [PSCustomObject]@{
            TestRunId = $row.TestRunId
            Previous  = $previousText
            Current   = $currentText
            Insight   = ($insights -join "; ")
        }
    }
}

# ------------------------------------------------------------
# HTML TABLE BUILDERS
# ------------------------------------------------------------

$dailyHtml = ""

foreach ($row in $dailyRows) {

    $varianceText = if ($row.Variance -gt 0) {
        "+$($row.Variance)"
    }
    else {
        "$($row.Variance)"
    }

    $dailyHtml += @"
<tr>
    <td>$($row.Date)</td>
    <td>$($row.Planned)</td>
    <td>$($row.Executed)</td>
    <td>$varianceText</td>
</tr>
"@
}

$changeHtml = ""

if ($changes.Count -eq 0) {

    $changeHtml = @"
<tr>
    <td colspan="4">No meaningful changes detected between snapshots.</td>
</tr>
"@
}
else {

    foreach ($change in $changes) {

        $changeHtml += @"
<tr>
    <td>$($change.TestRunId)</td>
    <td>$($change.Previous)</td>
    <td>$($change.Current)</td>
    <td>$($change.Insight)</td>
</tr>
"@
    }
}

# ------------------------------------------------------------
# EXECUTIVE INSIGHTS
# ------------------------------------------------------------

$insightItems = @()

$insightItems += "Execution completion is <strong>$completionRate%</strong> with $executed of $totalPlanned planned tests executed."

$insightItems += "Current pass rate is <strong>$passRate%</strong> based on executed tests."

if ($delayedCount -gt 0) {
    if ($delayedCount -eq 1) {
    $insightItems += "<strong>1</strong> execution occurred after its planned execution date."
}
else {
    $insightItems += "<strong>$delayedCount</strong> executions occurred after their planned execution dates."
}
}

if ($newExecutions -gt 0) {
    if ($newExecutions -eq 1) {
    $insightItems += "<strong>1</strong> newly observed execution appeared between the previous and current snapshots."
}
else {
    $insightItems += "<strong>$newExecutions</strong> newly observed executions appeared between the previous and current snapshots."
}
}

if ($statusOnlyChanges -gt 0) {
    if ($statusOnlyChanges -eq 1) {
    $insightItems += "<strong>1</strong> already-executed test changed status without increasing the executed count."
}
else {
    $insightItems += "<strong>$statusOnlyChanges</strong> already-executed tests changed status without increasing the executed count."
}
}

if ($blocked -gt 0) {
    if ($blocked -eq 1) {
    $insightItems += "<strong>1</strong> test remains blocked and may affect release readiness."
}
else {
    $insightItems += "<strong>$blocked</strong> tests remain blocked and may affect release readiness."
}
}

if ($notExecuted -gt 0) {
    if ($notExecuted -eq 1) {
    $insightItems += "<strong>1</strong> planned test is still not executed."
}
else {
    $insightItems += "<strong>$notExecuted</strong> planned tests are still not executed."
}
}

$insightsHtml = ""

foreach ($item in $insightItems) {
    $insightsHtml += "<li>$item</li>"
}

$generatedAt = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ------------------------------------------------------------
# HTML DASHBOARD
# ------------------------------------------------------------

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">

<title>QE Execution Intelligence</title>

<style>

body {
    font-family: Arial, Helvetica, sans-serif;
    margin: 0;
    background: #f5f7fa;
    color: #1f2937;
}

.header {
    background: #111827;
    color: white;
    padding: 28px 40px;
}

.header h1 {
    margin: 0;
    font-size: 30px;
}

.header p {
    margin: 8px 0 0 0;
    color: #d1d5db;
}

.container {
    padding: 30px 40px;
}

.cards {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
    gap: 16px;
    margin-bottom: 30px;
}

.card {
    background: white;
    border-radius: 10px;
    padding: 20px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.08);
}

.card .label {
    font-size: 13px;
    color: #6b7280;
    text-transform: uppercase;
    letter-spacing: .5px;
}

.card .value {
    font-size: 32px;
    font-weight: bold;
    margin-top: 8px;
}

.card.info {
    border-top: 4px solid #2563eb;
}

.card.pass {
    border-top: 4px solid #16a34a;
}

.card.fail {
    border-top: 4px solid #dc2626;
}

.card.blocked {
    border-top: 4px solid #d97706;
}

.card.pending {
    border-top: 4px solid #6b7280;
}

.section {
    background: white;
    border-radius: 10px;
    padding: 24px;
    margin-bottom: 24px;
    box-shadow: 0 1px 4px rgba(0,0,0,0.08);
}

.section h2 {
    margin-top: 0;
    font-size: 20px;
}

table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 15px;
}

th {
    background: #f3f4f6;
    text-align: left;
    padding: 11px;
    font-size: 13px;
}

td {
    padding: 11px;
    border-bottom: 1px solid #e5e7eb;
    font-size: 14px;
}

.insights li {
    margin-bottom: 12px;
    line-height: 1.5;
}

.footer {
    text-align: center;
    color: #6b7280;
    font-size: 12px;
    padding: 20px;
}

</style>
</head>

<body>

<div class="header">
    <h1>QE Execution Intelligence</h1>
    <p>Automated Test Execution & Quality Analytics Dashboard</p>
</div>

<div class="container">

<div class="cards">

<div class="card info">
    <div class="label">Planned</div>
    <div class="value">$totalPlanned</div>
</div>

<div class="card info">
    <div class="label">Executed</div>
    <div class="value">$executed</div>
</div>

<div class="card pass">
    <div class="label">Passed</div>
    <div class="value">$passed</div>
</div>

<div class="card fail">
    <div class="label">Failed</div>
    <div class="value">$failed</div>
</div>

<div class="card blocked">
    <div class="label">Blocked</div>
    <div class="value">$blocked</div>
</div>

<div class="card pending">
    <div class="label">Not Executed</div>
    <div class="value">$notExecuted</div>
</div>

<div class="card info">
    <div class="label">Completion</div>
    <div class="value">$completionRate%</div>
</div>

<div class="card pass">
    <div class="label">Pass Rate</div>
    <div class="value">$passRate%</div>
</div>

</div>

<div class="section">

<h2>Executive Insights</h2>

<ul class="insights">
$insightsHtml
</ul>

</div>

<div class="section">

<h2>Planned vs Actual Execution</h2>

<table>

<thead>
<tr>
<th>Date</th>
<th>Planned</th>
<th>Executed</th>
<th>Variance</th>
</tr>
</thead>

<tbody>
$dailyHtml
</tbody>

</table>

</div>

<div class="section">

<h2>Snapshot Change Intelligence</h2>

<p>
Compares the previous execution snapshot with the latest execution snapshot.
</p>

<table>

<thead>
<tr>
<th>Test Run</th>
<th>Previous</th>
<th>Current</th>
<th>Insight</th>
</tr>
</thead>

<tbody>
$changeHtml
</tbody>

</table>

</div>

</div>

<div class="footer">
Synthetic portfolio data only • Generated $generatedAt
</div>

</body>
</html>
"@

Set-Content -Path $OutputFile -Value $html -Encoding UTF8

Write-Host "Current snapshot rows : $($current.Count)"
Write-Host "Executed              : $executed"
Write-Host "Passed                : $passed"
Write-Host "Failed                : $failed"
Write-Host "Blocked               : $blocked"
Write-Host "Not Executed          : $notExecuted"
Write-Host "Delayed executions    : $delayedCount"
Write-Host "Snapshot changes      : $($changes.Count)"
Write-Host ""
Write-Host "Dashboard generated:"
Write-Host $OutputFile
Write-Host ""
Write-Host "Dashboard generation completed successfully."
