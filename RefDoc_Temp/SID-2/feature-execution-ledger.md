# SID-2 Feature Execution Ledger

## SA/SD Input Inventory

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Jira summary read | PASS | `jira summary SID-2` | Description empty, no comments, no linked tickets |
| Attachments downloaded | PASS | `RefDoc_Temp/SID-2/attachments/Todo_Delete_PRD_v1.1.pdf` (git-ignored) | PRD v1.1 |
| Remote links collected | PASS | `jira remotelinks SID-2` | Figma `iXusvkslanTTXnoaU8BXm0` node-id 10-2 |
| Related tickets | PASS | SID-1 (base feature, done in codebase) | No Jira issue links |
| Learning log read | PASS | `.claude/evaluation/agent-learning-log.md` | No entries yet |

## Spec Artifact Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| requirement-spec.md | PASS | `RefDoc_Temp/SID-2/requirement-spec.md` (@requirement-analyzer) | Conflicts / SV-01~22 / RTM / AC-01~10 / OQ-01~08 |
| codebase-analysis.md | PASS | `RefDoc_Temp/SID-2/codebase-analysis.md` (@requirement-analyzer) | Gap rows G-01~G-14 |
| Architecture Decisions | PASS | `codebase-analysis.md` § Architecture Decisions AD-01~06 (@architecture-advisor) | Disagrees with `completingIds`-style guard → single `pendingDelete` slot |
| Enrichment sections | PASS | `codebase-analysis.md` § Client/Backend, Implementation Phases (P0~P4), Acceptance Criteria, Test Plan, Delivery Quality Plan | |
| Exit gate checks | PASS | every G-xx in exactly one phase; every SV row → AC; OQs have id/owner/blocking phase | |

## Visual Spec Asset Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Figma screen-level nodes | N/A | Node ids 11:2 / 12:2 / 12:53 / 12:104 / 12:157 / 12:210 recorded from PRD | No Figma tool available in session; matrix derived from PRD text; visual details → OQ-07 |

## Spec Review Feedback Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Round 1 comments processed (approve with comments) | PASS | `.pipeline/spec_comments/_overview.json`, `requirement-spec--source-b-分析後仍未決.json` → `requirement-spec.md` § RD 回覆、AC-04、SV-05；`codebase-analysis.md` AD-04、Acceptance Criteria | OQ-04 changed to collapse on cancel; OQ-01~03/05~08 per default; "OQ-10" has no matching OQ (no-op) |

## Spec Review Verdict Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| RD approve | PASS | `.pipeline/spec_decision.json` — decision `approve`, reviewer RD, 2026-09-28T15:57:19+08:00 | |

## Implementation Coverage Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| P0 G-01、G-04、G-09、G-10（沿用 / N/A） | PASS | 無程式變更；empty / count 由 `testDeleteLastItemShowsEmptyState`（兩 VM）覆蓋 | G-04 BE N/A |
| P1 G-02、G-03、G-11、G-12 Store | PASS | `TodoStoring.swift`、`FileTodoStore.swift`、`MockTodoStore.swift`、`FileTodoStoreTests`（3 tests） | commit `4715a06` |
| P2 G-05、G-06、G-13 ViewModel | PASS | `TodoListViewModel.swift`、`CompletedListViewModel.swift`、`PendingDelete.swift`；VM tests 8 + 5 | `completionErrorMessage` → `errorMessage`（AD-03） |
| P3 G-07、G-08 View | PASS | 兩個 VC delegate + swipe + 反應式 alert + banner；`DeleteSwipeActionTests`（2 tests） | full swipe 關閉、取消收合（OQ-04/05） |
| P4 G-14 DEBUG hook | PASS | `DebugLaunchScenario.swift` `-UI_DELETE <open\|success\|failure>` + `FailingDeleteTodoStore`；`SceneDelegate.swift` | |

## Compilation Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| `ios-build build` | PASS | `BUILD SUCCEEDED`，sim `3BEBA0CE-DF13-42C5-9B6A-A18A8E3D5407`，HEAD `4715a06` | 無編譯錯誤需修 |

## Validation Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Unit tests | PASS | `ios-build test` → `TESTS PASSED: passed 40, failed 0` | 含 self-review 後新增 Completed 同名刪除 test |
| AC-01 左滑單一 destructive「刪除」 | PASS（unit）/ BLOCKED-by-test-harness（手勢截圖） | `DeleteSwipeActionTests` | OQ-08：RD 手動補證 |
| AC-02 滑回收合 | BLOCKED-by-test-harness | 系統 swipe 行為 | OQ-08：RD 手動 |
| AC-03 dialog（兩分頁） | PASS | `validation/AC-03-todo.png`、`AC-03-completed.png` + VM tests | |
| AC-04 取消不變 | PASS | `testCancelDeleteKeepsEverything`、`testTapDeleteShowsConfirmationAndCancelKeepsItems` | 收合為手動驗證 |
| AC-05 只刪目標、防重複 | PASS | `testRepeatedConfirmDeletesOnce`、`testConfirmDeleteRemovesTargetWithoutAffectingPending` | |
| AC-06 待辦 3→2 + banner | PASS | `validation/AC-06-todo-success.png`、`testConfirmDeleteRemovesTargetAndShowsBanner` | |
| AC-07 已完成刪除不影響待辦 | PASS | `validation/AC-07-completed-success.png` + VM test | |
| AC-08 同名只刪一筆 | PASS | Store + 兩 VM tests | |
| AC-09 重開不出現 | PASS（unit） | `testDeleteRemovesOnlyTargetAndSurvivesRelaunch` | 實機重開為 RD 手動補充 |
| AC-10 失敗（兩分頁） | PASS | `validation/AC-10-todo-failure.png`、`AC-10-completed-failure.png` + Store / VM tests | |
| Regression：新增 banner | PASS | `validation/regression-add-success.png` | |
| Format | N/A | `command -v swiftformat` 無輸出 | swiftformat not installed |

## Self-review Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| @code-reviewer | PASS | 7.5/10；Critical 0；Major 1、Minor 4 | 補 Completed 同名 test；Major（alert 已顯示時錯誤訊息被丟棄）屬 SID-1 既有 `showError` 語意、UI 上不可達於刪除流程 → 列入 handoff Remaining；其餘 Minor 記錄於 handoff |

## Handoff Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Handoff doc / push / Draft PR / handoff.json | PASS | `RefDoc_Temp/SID-2_handoff.md`；push `feature/SID-2`；Draft PR 見 workpad | |
