---
name: agent-learning-loop
description: Repo-owned learning loop for recurring agent questions, blockers, review misses, QA escapes, and production incidents. Reduces repeated questions by turning human answers into reusable, generic rules.
---

# Agent Learning Loop

## Purpose

讓 agent 越跑越懂、越問越少。

This skill turns repeated clarification, blockers, RD answers, review misses, QA escapes, and production incidents into reusable repo-owned memory.

The learning source of truth is:

```
.claude/evaluation/agent-learning-log.md
```

The local orchestrator (pipeline/server.py) remains dispatcher-only. Learning rules live in this repo so changes are versioned, reviewable, and portable across agent runs.

## What Gets Captured

Capture more than P0/P1 issues:

| Event | Capture? | Rule |
|-------|----------|------|
| Agent asked a question and RD answered with reusable project knowledge | Yes | Add or update learning entry |
| Same clarification appears twice | Yes | Promote to learning entry |
| Agent was blocked by missing test account/deep link/feature flag/seed data | Yes, if recurring | Add detection + prerequisite rule |
| Spec review requested changes because agent missed a source or state | Yes | Add source/state discovery rule |
| PR review caught a serious miss | Yes | Add review/test rule |
| QA escape / production issue | Yes | Add immediately |
| One-off detail only relevant to a single ticket | No | Keep in handoff/workpad |

## Before Asking A Human

Before writing `.pipeline/discussion_request.json`, the agent must check:

1. Jira description/comments/remote links.
2. Downloaded attachments and PRD.
3. Figma scope, annotations, states, variants (when a Figma source and tool exist).
4. Existing codebase patterns and module `CLAUDE.md`.
5. `.claude/evaluation/agent-learning-log.md`.

Only ask if the answer is still unavailable or conflicting and the decision materially affects implementation or validation.

When asking, include:
- what was checked,
- why existing knowledge is insufficient,
- concrete options when possible,
- exact missing prerequisite if blocked.

## After Human Answers

After every discussion/spec review response, classify it:

| Classification | Action |
|----------------|--------|
| One-off answer | Apply to current spec/workpad only |
| Reusable rule | Add/update `agent-learning-log.md` |
| Prompt/workflow gap | Update relevant agent/skill/workflow file |
| Validation gap | Add scenario/test/review rule |
| Environment prerequisite | Add blocker prerequisite rule |

If the agent adds or updates the learning log, it must keep the entry generic and cite the source ticket/PR only if safe.

## Learning Entry Format

Use this format in `.claude/evaluation/agent-learning-log.md`:

```markdown
### LEARN-YYYYMMDD-001 — {short reusable title}

- **Date**: YYYY-MM-DD
- **Category**: Clarification / Blocker / Figma / API / UI State / Testing / Review Miss / QA Escape / Production Incident / Workflow
- **Severity**: Learning / P2 / P1 / P0 / N/A
- **Source**: Spec review / RD comment / Jira / PR review / QA / Production / Agent blocker
- **Affected area**: Module / feature / screen / API / workflow stage
- **Original agent question or miss**: ...
- **Human answer / observed truth**: ...
- **Generalizable lesson**: ...
- **Detection rule**: ...
- **Validation rule**: ...
- **Where to apply**: requirement-analyzer / architecture-advisor / testing-expert / code-reviewer / feature workflow / bug workflow / skill
- **Status**: Active / Superseded / Obsolete
```

## Handoff Requirement

Feature and bug handoff should include:

```markdown
### Learning Loop
- Existing lessons applied:
  - LEARN-YYYYMMDD-001 — covered by Scenario X / Test Y / Review check Z
- New learning candidates:
  - {question or blocker that should become reusable if repeated}
- Learning log updates:
  - Added/updated: LEARN-...
  - None
```

## Anti-Patterns

- Do not use private chat memory as the only source of learning.
- Do not add every small ticket-specific detail to the learning log.
- Do not overfit to one PM, one Figma file, one experiment project, or one wording style.
- Do not let a learning entry bypass validation. A lesson should create better checks, not assumptions.

## Tooling Roadmap

Prompt-only learning has a ceiling. Use tools where they turn instructions into checkable artifacts.

### Phase 1: Markdown + `rg` (now)

No extra runtime tool is required.

- Keep learning in `.claude/evaluation/agent-learning-log.md`.
- Agents use `rg` and normal file reading to find relevant lessons.
- All changes are visible in git.

### Phase 2: Lightweight repo scripts

Add small scripts when the log starts growing:

| Tool | Purpose |
|------|---------|
| `agent-learning-log check` | Validate entry schema and required fields |
| `agent-learning-log search <keywords>` | Return compact relevant lessons for a module/API/UI pattern |
| `feature-spec check <requirement-spec.md>` | Verify required sections exist: Spec ↔ Figma Conflicts, State / Variant Matrix, Acceptance Scenarios, Traceability |
| `validation-evidence check <handoff.md>` | Verify build/test/screenshot evidence is present before handoff |

### Phase 3: Retrieval only if needed

Use SQLite/FTS or embeddings only when markdown search becomes noisy.

Do not start with a vector database. The first bottleneck is usually missing structure and missing evidence, not retrieval technology.
