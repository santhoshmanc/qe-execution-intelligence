# QE Execution Intelligence

A lightweight Quality Engineering portfolio project that transforms synthetic test-execution data into an automated HTML dashboard with execution metrics, planned-vs-actual analysis, and snapshot change intelligence.

> This repository uses synthetic data only. It contains no proprietary employer, client, or production information.

## Overview

QE Execution Intelligence demonstrates how raw test execution data can be transformed into simple, stakeholder-friendly quality insights.

The dashboard answers practical QA reporting questions such as:

- How many tests were planned and executed?
- What are the Passed, Failed, Blocked, and Not Executed counts?
- What is the execution completion percentage?
- What is the current pass rate?
- Did execution happen according to plan?
- Which executions occurred later than planned?
- Did any test change status between reporting snapshots?
- Did a newly observed execution appear in the latest snapshot?

## How It Works

```text
Previous Test Execution Snapshot
                +
Current Test Execution Snapshot
                |
                v
        PowerShell Analytics
                |
                v
   Planned vs Actual Analysis
                |
                v
      Snapshot Change Detection
                |
                v
      HTML Quality Dashboard