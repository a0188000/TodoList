## Bug Flow: Investigate → Fix → PR

> AI reads the bug ticket, investigates root cause, applies a minimal fix, and creates a PR with detailed analysis for RD review.
> There is no SA/SD phase. If the ticket is unexpectedly in `SA/SD`, routing transitions it to `In Development` first.
> Learning posture: use `/agent-learning-loop`. Investigation posture: use `/systematic-debugging` (no fix without root cause; 3-strike rule).

### Step 1: Gather info

1. Read the full ticket: `jira summary {{ issue.identifier }}`, `jira attachments {{ issue.identifier }}`, `jira remotelinks {{ issue.identifier }}`.
2. If the ticket includes URLs (Figma, API docs, Confluence) and a tool to read them is available, read them.
3. Read `.claude/evaluation/agent-learning-log.md`; identify lessons relevant to the area, reproduction condition, or validation gap.
4. If the ticket contains a crash report / stack trace, treat it as the primary evidence.
5. Record in the workpad: reproduction steps, expected vs actual behavior, affected code path (initial hypothesis), learning entries applied (or `None`).

### Step 2: Investigate & analyze

> Produces the **problem analysis** that goes into the PR.

1. Read every file referenced by the stack trace / reproduction path.
2. Trace the code path from the entry point (ViewController, scene delegate, notification handler) through the call chain to the bug site. Use `git blame -L <start>,<end> <file>` for context.
3. List up to 5 root cause candidates and critique each against the evidence.
4. Choose the most likely root cause and document it in the workpad:

```md
### Problem Analysis

#### Cause
<Description of the root cause>
- **Fault**: this codebase / dependent library / backend API
- **Complexity**: simple / moderate / hard
- **Confidence**: high / medium / low

#### Code Trace
1. `{File1.swift}:{line}` — {function} — {what happens here}
2. `{File2.swift}:{line}` — {function} — **root cause here**: {explanation}

#### Reproduction Steps
1. {precondition or navigation}
2. {action that triggers the bug}
3. {observe the incorrect behavior}

#### Other Potential Causes
1. {Alternative cause — why it was ruled out}
```

5. If there is **not enough information** to determine a root cause, document what was investigated and why it is inconclusive, write `.pipeline/blocked.json` with the exact information needed, and stop. Do not guess.

---

### Step 3: Fix

#### 3.1 Sync and branch

> **Branch prefix (MANDATORY)**: bug fixes MUST use `fix/`. Never reuse a stray `feature/{{ issue.identifier }}` branch — note it for cleanup in the workpad.

```bash
git fetch origin
git checkout -b fix/{{ issue.identifier }} origin/{{ base_branch }}   # or check out the existing fix branch
```

Record HEAD sha in workpad Notes.

**Duplicate PR check** (before any work, and again right before creating the PR):

```bash
gh pr list --search "{{ issue.identifier }} in:title" --state all --json number,headRefName,state,title
```

- An OPEN PR for `{{ issue.identifier }}` exists → STOP, record it in the workpad, write `.pipeline/handoff.json` with that PR url, shut down.
- Only CLOSED/MERGED PRs → continue (re-open scenario).

#### 3.2 Implement the fix

1. Make the **minimal change** that fixes the root cause.
2. Do NOT refactor surrounding code unless directly required by the fix.
3. New code follows `CLAUDE.md` (Swift + Combine, async/await, MVVM).
4. If the proper fix needs structural change beyond minimal scope, fix minimally and file a separate Backlog ticket.

#### 3.3 Test the fix

1. If a test target exists: write a test that reproduces the bug (it must fail before the fix), then run the **Test** command from "Project commands" — see `/test-driven-development`.
2. If the ticket has a **Validation / Test Plan** section, execute it and record results.
3. For UI bugs, capture a simulator screenshot of the fixed behavior under `RefDoc_Temp/{{ issue.identifier }}/validation/` (same `xcrun simctl` steps as the feature Validation Gate).

#### 3.4 Compilation Gate (MANDATORY)

Run the **Build** command; fix errors iteratively until it succeeds; record the result in workpad Notes.

#### 3.5 Code formatting

Run the **Format** command on changed Swift files (or record N/A).

---

### Step 4: Commit, PR & Handoff

#### 4.1 Commit & Push

1. Commit: `fix: <description> ({{ issue.identifier }})` — imperative, lowercase after type, no trailing period, ≤ 72 chars. Exclude `.pipeline/`, `.build/`, temp files, credentials.
2. `git push -u origin fix/{{ issue.identifier }}`
3. If rejected (non-fast-forward): `git fetch origin && git -c merge.conflictstyle=zdiff3 merge origin/{{ base_branch }}`, re-run the Compilation Gate, push again. If push fails for auth, write `.pipeline/blocked.json` and stop.

#### 4.2 Create PR

> **PR creation rules (MANDATORY)**:
> - Use the exact `gh pr create` shape below — not Claude Code's default PR template, not a conventional-commit style title, and do not translate the section headings.
> - `LAUNCH_MODE=pipeline` → include `--label ai-pipeline` (run `gh label create ai-pipeline --color 5319E7 --force` first). Manual mode → drop that line.
> - Re-run the duplicate PR check immediately before this command.

**Title**: `[{{ issue.identifier }}][iOS] {{ issue.title }}` — full Jira key, original Jira title, no `fix:` prefix.

```bash
gh pr create --base {{ base_branch }} \
  --label ai-pipeline \
  --title "[{{ issue.identifier }}][iOS] {{ issue.title }}" \
  --body "$(cat <<'PREOF'
## Issue links

- [Jira]({{ issue.url }})

## 問題分析

### Root Cause
<root cause description — from Step 2 analysis>

- **嚴重程度**: <crash / UI error / logic error>

### Code Trace
1. `File1.swift:L42` — `functionName()` — <what happens>
2. `File2.swift:L87` — `functionName()` — **root cause**: <explanation>

### 復現步驟
1. <step 1>
2. <step 2>
3. <step 3>

## 修正內容

- <what was changed and why>

## 驗證方式

- <how to verify the fix>
- Build status: ✅
- Tests: <pass / new test added / N/A — no test target>

## Learning Loop

- Existing lessons applied: `LEARN-...` / None
- New learning candidates: <reusable blocker/miss/clarification> / None
- Learning log updates: Added/updated `LEARN-...` / None

## Check list

- [x/ ] Does it have anything to do with API?
- [x/ ] Has the document been modified?
- [x/ ] Were there any changes to the tests?
PREOF
)"
```

#### 4.3 Transition Jira to Code Review

```bash
jira transitions {{ issue.identifier }}
jira transition {{ issue.identifier }} "Code Review"
```

#### 4.4 Update workpad & handoff

1. Update workpad phase to `Handoff to RD` and add:

```md
### Handoff Summary
- **Branch**: fix/{{ issue.identifier }}
- **PR**: #<number> <url>
- **Build status**: ✅ Builds
- **Root cause**: <brief description>
- **Fix**: <what was changed>
- **Tests**: <existing tests pass / new test added / manual verification / N/A>
- **Learning Loop**: existing lessons applied / new learning candidates / learning log updates
- **Pending RD verification**:
  - [reproduction steps for RD to verify the fix]
  - [regression areas to check]
```

2. Sync and tag the assignee:
   ```bash
   jira workpad {{ issue.identifier }} .pipeline/workpad.md --mention-assignee "Bug fix PR 已就緒，請 review。"
   ```
3. Signal handoff:
   ```bash
   cat > .pipeline/handoff.json << EOF
   {"phase": "Handoff to RD", "branch": "fix/{{ issue.identifier }}", "summary": "<one line root cause + fix>", "pr_url": "<PR url>"}
   EOF
   ```
4. **Shut down.** RD reviews the PR; when the ticket reaches `Code Review` the General phase takes over.
