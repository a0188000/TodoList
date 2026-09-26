---
name: feature-delivery-quality
description: 通用 Feature 交付品質閉環。用 traceability、驗收證據、合理假設與 blocker disclosure，提高 AI feature first-pass 完成度；不針對特定 PRD、PM、Figma 或專案客製。
---

# Feature Delivery Quality

## 目的

讓 AI 在 feature ticket 上盡量交付可接手、可驗收、可 review 的第一版，而不是只完成局部 code change。

此 skill 的目標是提高通用完成度，不是追求僵硬分數：
- 追求最高可交付完成度。
- 接受不同 PM、PRD、Figma、API 文件寫法不一致的現實。
- 不為了表面完整度硬猜需求。
- 不針對單一專案、單一 Figma、單一 PM 的寫法做特殊優化。

## 核心原則

### 0. Repo-Owned Workflow, Orchestrator-Light

品質規則屬於 repo，不屬於本機 orchestrator（pipeline/server.py）。

- Orchestrator 只負責派工、續跑、等待人類 review、呈現 dashboard 狀態。
- 需求釐清、實作流程、驗收 gate、測試策略、handoff 格式，都必須寫在 repo 內的 `WORKFLOW.md`、`workflows/`、`.claude/agents/`、`.claude/skills/`。
- 不要求 orchestrator 內建任何 feature-specific 品質判斷。
- 如果需要改善人類體驗，可以優化 dashboard 顯示、spec review UI、discussion surface，但 workflow truth 仍以 repo 文件為準。

### 1. Traceability over Guessing

每個重要需求都要能追到來源與驗收方式：

| Requirement | Source | Confidence | Implementation | Validation | Status |
|-------------|--------|------------|----------------|------------|--------|
| {需求} | Jira / PRD / Figma / API / RD comment | High / Medium / Low | {file/phase} | {test/screenshot/scenario} | Done / Blocked / RD follow-up |

規則：
- `High`: PRD/Jira/Figma/API 至少一個來源明確，且無互相矛盾。
- `Medium`: 可以從 Figma/現有 codebase 合理推導，但文字規格不完整。
- `Low`: 來源不足或互相矛盾；不可默默假設，需列 Open Question 或 blocker。
- 問人前先查 `.claude/evaluation/agent-learning-log.md`；若已有可套用 lesson，應直接引用而不是重複詢問。

### 2. Evidence over Confidence

完成聲明必須有新鮮證據：
- Build command result。
- Unit/snapshot/UI validation command result。
- Simulator screenshot / Figma screenshot / mismatch assessment。
- Code review findings and fixes。
- 每個 Acceptance Scenario 的結果。

不要用「應該可以」「看起來沒問題」替代驗收。

### 3. Useful Completion over Perfection

UI 驗收要精準，但不要鑽牛角尖：
- `<= 10%` 的非語意視覺差異可記錄為 minor difference。
- 缺元素、錯狀態、錯 flow、錯平台、無法操作，一律不是 minor。
- 不追求 pixel-perfect noise；追求可用、符合需求、可 review 的 first-pass delivery。

### 4. Blockers Must Be Actionable

遇到缺資訊或缺環境時，不可只寫「blocked」。必須寫：
- 缺什麼。
- 為什麼它阻擋實作或驗收。
- 已經嘗試過哪些 fallback。
- 人類要提供什麼具體資訊或權限。

例：
- 測試帳號：需要能進入會員等級 X 的帳號，否則無法驗證該狀態畫面。
- Deep link：沒有可用入口，已完成 isolated component/screenshot 驗收，但無法驗證 end-to-end navigation。
- Figma scope：大 node 中有兩組 mobile flow，需 RD/Designer 確認採用哪一組。

### 5. Generic Process Only

禁止把特定專案的內容寫進流程規則：
- 不寫死特定功能名稱、Figma node、API path、PM 習慣、文案。
- 只抽象成通用檢查：scope selection、state variants、traceability、validation evidence、blocker handling。

## Delivery Assessment

Handoff 前產出一段 `AI Delivery Assessment`。這不是硬性 KPI，而是讓 RD 快速判斷 AI first-pass 完成度。

```markdown
## AI Delivery Assessment

### Completion Summary
| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirement coverage | Complete / Partial / Blocked | Traceability matrix |
| UI/Figma coverage | Complete / Partial / Blocked / N/A | Screenshots + mismatch % |
| State/variant coverage | Complete / Partial / Blocked / N/A | Acceptance Scenarios |
| Build | Pass / Fail / Blocked | Command output summary |
| Tests | Pass / Partial / Blocked / N/A | Test command summary |
| Code review | Pass / Issues fixed / Remaining issues | @code-reviewer summary |

### RD Follow-up
- [ ] {specific item, why it remains}

### Blockers
- {missing prerequisite + exact human action needed}

### Learning Loop
- Existing lessons applied: `LEARN-...` / None
- New learning candidates: {reusable clarification/blocker/miss} / None
- Learning log updates: Added/updated `LEARN-...` / None
```

Interpretation:
- `Complete`: implemented and verified with evidence.
- `Partial`: useful first-pass implementation exists, but some non-critical coverage remains.
- `Blocked`: cannot complete without human-provided prerequisite.
- `N/A`: dimension does not apply to this ticket.
