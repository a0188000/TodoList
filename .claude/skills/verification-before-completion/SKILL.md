---
name: verification-before-completion
description: 完成前驗證行為約束。Iron Law：沒跑過驗證命令就不准宣稱完成。適用所有階段、所有 agent。
---

# Verification Before Completion

## Iron Law

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

Claiming work is complete without verification is dishonesty, not efficiency.

## Gate (5-Step Process)

Before ANY completion claim:

1. **IDENTIFY** — What command proves the claim?
2. **RUN** — Execute the command fresh (not from memory)
3. **READ** — Read the full output. Check exit code. Count failures.
4. **VERIFY** — Does the output actually confirm the claim?
5. **ONLY THEN** — Make the claim, citing the evidence.

Skip any step = lying, not verifying.

## Claims That Require Evidence

| Claim | Required Evidence |
|-------|-------------------|
| "Tests pass" | Test command output showing 0 failures |
| "Build succeeds" | `xcodebuild build` with exit code 0 |
| "Formatted" | `swiftformat --lint <files>` with 0 errors (or N/A — not installed) |
| "Bug fixed" | Test reproducing original symptom now passes |
| "Feature complete" | All acceptance criteria have corresponding passing tests |
| "No regressions" | Full test suite passes, not just new tests |

## Red Flags — Stop and Redo

If you catch yourself saying or thinking any of these, STOP:

- "should work" / "should be fine"
- "probably passes"
- "I'm fairly confident"
- "Done!" / "Complete!" (before running verification)
- "The changes look correct" (looking ≠ verifying)
- "I tested similar code before" (past ≠ present)

## Rationalization Prevention

| Excuse | Why It's Wrong |
|--------|---------------|
| "I'm confident it works" | Confidence without evidence is guessing |
| "It's a small change" | Small changes cause big regressions |
| "I already ran it earlier" | Earlier ≠ now. State changes between runs. |
| "Only formatting changes" | `swiftformat` may have introduced issues. Run tests. |
| "The test I wrote passes" | Did you watch it FAIL first? Did other tests still pass? |

## Enforcement

This skill applies to:
- Every agent, every task, every completion claim
- Both human-invoked and WORKFLOW-driven execution
- Build verification, test verification, format verification, deployment verification
