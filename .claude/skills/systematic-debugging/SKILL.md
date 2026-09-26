---
name: systematic-debugging
description: 系統化除錯行為約束。Iron Law：沒找到 root cause 就不准寫 fix。4 階段流程，3 次修不好就停下來質疑架構。
---

# Systematic Debugging

## Iron Law

**NO FIXES WITHOUT ROOT CAUSE INVESTIGATION FIRST.**

Guessing at fixes wastes time and masks deeper issues.

## When to Apply

- Bug tickets
- Test failures
- Runtime crashes
- Unexpected behavior
- Any situation where "something is wrong" but the cause is unclear

## 4-Phase Process

### Phase 1: Root Cause Investigation

- Read the full error message, stack trace, and logs
- Reproduce the issue consistently (document exact steps)
- Review recent changes (`git log`, `git blame`)
- Trace data flow backward from the symptom to the source
- In multi-layer issues: add diagnostic logging at each boundary (API → Service → ViewModel → View)

**Output**: A specific hypothesis: "The bug is caused by X in file Y at line Z because..."

### Phase 2: Pattern Analysis

- Find similar **working** code in the codebase
- Study the working code completely (not superficially)
- Document differences between working and broken code
- Check if the broken code violates established patterns (MVVM, Service layer, etc.)

### Phase 3: Hypothesis Testing

- Form ONE specific hypothesis
- Test with ONE minimal change
- If test fails → abandon hypothesis, form a new one
- Do NOT make multiple changes at once

### Phase 4: Fix Implementation

1. Write a test reproducing the bug (TDD — see `skills/test-driven-development/`)
2. Apply a single targeted fix
3. Verify the test passes
4. Verify no other tests broke
5. Verify the fix follows `verification-before-completion`

## 3-Strike Rule

**After 3 unsuccessful fix attempts → STOP.**

Three failures mean you're dealing with a design problem, not a code problem. At this point:

1. Stop trying to fix
2. Document what you've tried and why it failed
3. Question the architecture — is the underlying design flawed?
4. Escalate to human with: attempted fixes, results, and architectural concern

## Red Flags — Restart Process

- Attempting a "quick fix" before investigating
- Changing multiple things at once
- Making assumptions without verification
- Suggesting fixes before tracing data flow
- "This should fix it" without explaining WHY
- Copying a fix from Stack Overflow without understanding root cause

## Impact Analysis (for Bugfix PRs)

Before submitting a bugfix, document:

1. **Root cause**: What was wrong and where
2. **Fix scope**: What files were changed and why
3. **Blast radius**: What other modules/features could be affected
4. **Regression risk**: What tests cover the affected code paths
5. **Verification**: How to verify the fix works (specific test or manual steps)

This feeds into `@code-reviewer`'s bugfix review dimension (副作用分析 / 改A不壞B).

## Integration with Project

- WORKFLOW `_bug.md` can reference this skill for the investigation phase
- `@code-reviewer` uses the Impact Analysis section when reviewing bugfix PRs
- References `skills/test-driven-development/` for the fix implementation phase
