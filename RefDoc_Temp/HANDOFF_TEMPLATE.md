# ${Ticket_Key} Handoff Document

> **⚠️ 接手前必讀**：請先檢查下方「最後一筆 Commit」的 SHA 是否與目前分支的 HEAD 一致。
> 若不一致，代表 RD 在交接後有額外修改，**請先與 RD 確認變更內容後再繼續作業**，避免覆蓋 RD 的修改。

## 驗證指令

```bash
EXPECTED_SHA="<填入下方記錄的 commit SHA>"
CURRENT_SHA=$(git rev-parse HEAD)
if [ "$EXPECTED_SHA" != "$CURRENT_SHA" ]; then
  echo "⚠️ WARNING: HEAD ($CURRENT_SHA) 與紀錄的 commit ($EXPECTED_SHA) 不一致！請先與 RD 確認。"
  exit 1
else
  echo "✅ Commit 一致，可以繼續作業。"
fi
```

---

# For RD

## 做了什麼

${2-3 段摘要}

## 還差什麼

- [ ] ${remaining_item}

## 要注意什麼

- ${caveat}

## Acceptance Criteria 對應狀態

| # | Acceptance Criteria | 狀態 | 備註 |
|---|-------------------|------|------|
| 1 | ${criteria} | ✅ / ⚠️ / ❌ | ${note} |

## 怎麼測

1. ${步驟}

---

# For AI Agent

## 基本資訊

| 欄位 | 值 |
|------|-----|
| **Ticket** | ${Ticket_Key} |
| **Ticket URL** | ${Jira_URL} |
| **Branch** | feature/${Ticket_Key} |
| **Base Branch** | ${base_branch} |
| **最後一筆 Commit** | `${commit_sha}` — ${commit_message} |
| **Commit 時間** | ${commit_date} |
| **Build 狀態** | ✅ Builds / ❌ Build failed |
| **Format** | ✅ swiftformat / N/A — not installed |
| **Spec Review** | 本機 dashboard，Round ${n} approve by ${reviewer} @ ${time} |

## Spec 文件位置

| 文件 | 路徑 |
|------|------|
| 需求規格 | `RefDoc_Temp/${Ticket_Key}/requirement-spec.md` |
| Codebase 分析 | `RefDoc_Temp/${Ticket_Key}/codebase-analysis.md` |
| 執行 Ledger | `RefDoc_Temp/${Ticket_Key}/feature-execution-ledger.md` |
| 驗證截圖 | `RefDoc_Temp/${Ticket_Key}/validation/` |

## 架構決策

- ${摘要 codebase-analysis.md 的 Architecture Decisions 與設計意圖}

## 關鍵 Code Path

```
${Entry point} → ${ViewController} → ${ViewModel} → ${Service} → ${資料來源}
```

## Implementation Phases

- [ ] Phase 1: ${phase_description}

## 變更檔案清單

> `git diff --name-only origin/${base_branch}...${commit_sha}`

| 類型 | 檔案 |
|------|------|
| 新增 | |
| 修改 | |
| 刪除 | |

## 驗證證據

| Scenario | 方式 | 結果 | 證據 |
|----------|------|------|------|
| AS-01 | unit test / screenshot | PASS / FAIL / BLOCKED-* | `path` |

## Workflow Ledger 摘要

| Gate | 狀態 |
|------|------|
| Spec Artifact | |
| Spec Review Verdict | |
| Implementation Coverage | |
| Compilation | |
| Validation | |
| Self-review | |

## AI Delivery Assessment

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirement coverage | | |
| UI/design coverage | | |
| State/variant coverage | | |
| Build | | |
| Tests | | |
| Code review | | |

## Learning Loop

- Existing lessons applied: `LEARN-...` / None
- New learning candidates: ... / None
- Learning log updates: Added/updated `LEARN-...` / None

## 未完成項目的脈絡

| 項目 | 原因 | 建議做法 |
|------|------|----------|

## 下一步行動（給接手 Agent）

1. 執行上方驗證指令確認 HEAD 一致；不一致時 `git log ${commit_sha}..HEAD --oneline` 查看 RD 額外 commits，停止並通知 RD。
2. 一致時：閱讀本文件與 spec，依「還差什麼」決定修改，完成後建立 PR targeting `${base_branch}`。
