# SID-2 Handoff Document

> **⚠️ 接手前必讀**：請先檢查下方「最後一筆 Commit」的 SHA 是否與目前分支的 HEAD 一致。
> 若不一致，代表 RD 在交接後有額外修改，**請先與 RD 確認變更內容後再繼續作業**，避免覆蓋 RD 的修改。
> 註：本文件本身在 code commit 之後另以 `docs:` commit 提交，比對時請以 code commit 為準（`git log 4715a06..HEAD` 應只有 docs commit）。

## 驗證指令

```bash
EXPECTED_SHA="4715a06231a8531e277c249aa83479e04a034bf9"
git log --oneline "$EXPECTED_SHA"..HEAD
```

---

# For RD

## 做了什麼

在「待辦」與「已完成」兩個分頁加入左滑刪除：左滑只露出系統紅色 destructive「刪除」按鈕（關閉 full swipe，必須點擊按鈕），點擊後以系統 alert 二次確認（標題＝Todo title、分頁專屬說明文案、「取消」／紅色「確認」）。取消後資料不變且左滑按鈕收合；確認後依 `id` 刪除，清單與待辦數量即時更新並顯示 3 秒「任務已刪除」banner（會取代顯示中的「任務已新增」）；失敗時資料不變並顯示「刪除失敗，請再試一次」alert。

資料層新增 `TodoStoring.delete(id:)`，`FileTodoStore` 沿用「先寫檔成功才更新 items」契約，因此重開 App 不會再出現已刪除項目。兩個 ViewModel 以 `pendingDelete: PendingDelete?` 作為 dialog 狀態 output（可單元測試），確認時同步清空此 slot 以防重複送出。既有 `completionErrorMessage` 更名為 `errorMessage`，由完成失敗與刪除失敗共用。已完成頁新增 banner 與錯誤 alert（原本沒有）。

另新增 DEBUG-only launch arg `-UI_DELETE <open|success|failure>`（搭配 `-UI_SCENARIO content [-UI_TAB completed]`）產生驗證截圖；`failure` 以 DEBUG-only `FailingDeleteTodoStore` 模擬保存失敗。

## 還差什麼

- [ ] AC-01 / AC-02 實際左滑與滑回收合的手動截圖（OQ-08：無 UI test target，simctl 無法模擬滑動）
- [ ] AC-04 點「取消」後左滑按鈕收合的手動確認（`tableView.setEditing(false, animated:)`）
- [ ] AC-09 實機 / 模擬器關閉重開 App 手動確認（unit test 已覆蓋）
- [ ] 以 Figma node `11:2` / `12:2` / `12:53` / `12:104` / `12:157` / `12:210` 做視覺比對（本 session 無 Figma 工具，OQ-07 採系統元件）
- [ ] （選擇性）Self-review Major：`showError` 在已有其他 modal 且非 dismiss 中時會丟棄訊息（沿用 SID-1 既有語意；刪除流程中 UI 上不可達，因 alert / 新增頁為 modal，使用者無法同時左滑）。若要更穩健可改為排隊顯示

## 要注意什麼

- `completionErrorMessage` 已更名為 `errorMessage`（AD-03），若其他分支引用舊名需調整。
- 刪除成功後以 `reloadData()` 整表重繪，無逐列刪除動畫（OQ-07 預設不強制）。
- Overview comment「OQ-10 照建議」在本 spec 無對應 OQ，視為 no-op。
- PRD 附件 `RefDoc_Temp/SID-2/attachments/` 未被 `.gitignore` 涵蓋，請勿 `git add RefDoc_Temp` 整包提交。

## Acceptance Criteria 對應狀態

| # | Acceptance Criteria | 狀態 | 備註 |
|---|-------------------|------|------|
| AC-01 | 左滑只露出目標列紅色「刪除」 | ⚠️ | swipe configuration unit test PASS；手勢截圖待 RD 手動 |
| AC-02 | 滑回收合 | ⚠️ | 系統行為，待 RD 手動 |
| AC-03 | 點刪除 → dialog，資料未刪 | ✅ | 兩分頁截圖 + VM test |
| AC-04 | 取消 → 不變、按鈕收合 | ✅ | VM test；收合待手動確認 |
| AC-05 | 確認 → 只刪目標、防重複 | ✅ | VM test |
| AC-06 | 待辦 3→2 +「任務已刪除」 | ✅ | 截圖 + VM test |
| AC-07 | 已完成刪除不影響待辦 | ✅ | 截圖 + 跨 VM test |
| AC-08 | 同名只刪一筆 | ✅ | Store + 兩 VM tests |
| AC-09 | 重開不出現 | ✅ | Store relaunch test；實機手動補充 |
| AC-10 | 失敗 → 不變 +「刪除失敗，請再試一次」 | ✅ | 兩分頁截圖 + Store / VM tests |

## 怎麼測

1. `ios-build build && ios-build test`（預期 40 passed）。
2. 模擬器執行 App（或 `ios-build run -- -UI_SCENARIO content`），在待辦分頁左滑一列 → 只露出紅色「刪除」；完整左滑不會觸發刪除。
3. 點「刪除」→ alert 標題為該 title、說明「確定要刪除這筆待辦事項嗎？刪除後無法復原。」；點「取消」→ 資料不變、按鈕收合。
4. 再次左滑 → 「刪除」→「確認」→ 該列消失、數量 −1、底部「任務已刪除」約 3 秒。
5. 切到「已完成」重複 2–4（說明文案為已完成版本），確認待辦數量不變。
6. 關閉 App 重開 → 已刪除項目不再出現。
7. 失敗情境：`ios-build run -- -UI_SCENARIO content -UI_DELETE failure`（加 `-UI_TAB completed` 測已完成頁）→ 顯示「刪除失敗，請再試一次」、資料不變。

---

# For AI Agent

## 基本資訊

| 欄位 | 值 |
|------|-----|
| **Ticket** | SID-2 |
| **Ticket URL** | https://a0188000.atlassian.net/browse/SID-2 |
| **Branch** | feature/SID-2 |
| **Base Branch** | develop |
| **最後一筆 Commit** | `4715a06231a8531e277c249aa83479e04a034bf9` — feat: add swipe-to-delete with confirmation for todos |
| **Commit 時間** | 2026-09-28 |
| **Build 狀態** | ✅ Builds |
| **Format** | N/A — swiftformat not installed |
| **Spec Review** | 本機 dashboard，Round 1 approve by RD @ 2026-09-28T15:57:19+08:00 |

## Spec 文件位置

| 文件 | 路徑 |
|------|------|
| 需求規格 | `RefDoc_Temp/SID-2/requirement-spec.md` |
| Codebase 分析 | `RefDoc_Temp/SID-2/codebase-analysis.md` |
| 執行 Ledger | `RefDoc_Temp/SID-2/feature-execution-ledger.md` |
| 驗證截圖 | `RefDoc_Temp/SID-2/validation/` |

## 架構決策

- AD-01：`TodoStoring.delete(id:) async throws`；先 save 再指派 items；id 不存在靜默 return。
- AD-02：dialog 狀態為 VM output `pendingDelete: PendingDelete?`；Input `didTapDelete(id:)` / `didConfirmDelete()` / `didCancelDelete()`；確認時同步清空 slot 作為 in-flight guard。
- AD-03：待辦頁 `bannerText` + 共用 `showBanner(text:recentlyAddedId:)`；已完成頁 `bannerMessage: String?`；錯誤 subject 統一為 `errorMessage`。
- AD-04：`UIContextualAction(.destructive, "刪除")` + `performsFirstActionWithFullSwipe = false`；alert 由 `$pendingDelete` 反應式 present / dismiss；`pendingDelete == nil` 時 `setEditing(false)` 收合（RD 決議 OQ-04）；`showError` 在前一個 alert dismiss 中時等 transition 完成再顯示。
- AD-05：DEBUG `-UI_DELETE <open|success|failure>`、`FailingDeleteTodoStore`。

## 關鍵 Code Path

```
SceneDelegate → TodoListViewController / CompletedListViewController (trailing swipe → alert)
  → TodoListViewModel / CompletedListViewModel (didTapDelete → pendingDelete → didConfirmDelete)
  → TodoStoring.delete(id:) → FileTodoStore → Documents/todos.json
```

## Implementation Phases

- [x] P0：沿用 G-01、G-09、G-10；G-04 BE N/A
- [x] P1：Store delete + Mock + Store tests（G-02、G-03、G-11、G-12）
- [x] P2：ViewModels + VM tests（G-05、G-06、G-13）
- [x] P3：VCs swipe / alert / banner + swipe config tests（G-07、G-08）
- [x] P4：DEBUG hook（G-14）

## 變更檔案清單

> `git diff --name-only origin/develop...4715a06`

| 類型 | 檔案 |
|------|------|
| 新增 | `TodoList/TodoList/ViewModels/PendingDelete.swift`、`TodoList/TodoListTests/DeleteSwipeActionTests.swift`、`RefDoc_Temp/SID-2/requirement-spec.md`、`RefDoc_Temp/SID-2/codebase-analysis.md`、`RefDoc_Temp/SID-2/feature-execution-ledger.md` |
| 修改 | `SceneDelegate.swift`、`Services/FileTodoStore.swift`、`Services/TodoStoring.swift`、`Support/DebugLaunchScenario.swift`、`ViewModels/TodoListViewModel.swift`、`ViewModels/CompletedListViewModel.swift`、`Views/TodoListViewController.swift`、`Views/CompletedListViewController.swift`、`TodoListTests/{CompletedListViewModelTests,FileTodoStoreTests,MockTodoStore,TodoListViewModelTests}.swift` |
| 刪除 | 無 |

## 驗證證據

| Scenario | 方式 | 結果 | 證據 |
|----------|------|------|------|
| AC-01 | unit test | PASS / BLOCKED-by-test-harness（手勢） | `DeleteSwipeActionTests` |
| AC-02 | 手動 | BLOCKED-by-test-harness | OQ-08 |
| AC-03 | screenshot + unit | PASS | `validation/AC-03-todo.png`、`validation/AC-03-completed.png` |
| AC-04 | unit | PASS | `testCancelDeleteKeepsEverything`、`testTapDeleteShowsConfirmationAndCancelKeepsItems` |
| AC-05 | unit | PASS | `testRepeatedConfirmDeletesOnce`、`testConfirmDeleteRemovesTargetWithoutAffectingPending` |
| AC-06 | screenshot + unit | PASS | `validation/AC-06-todo-success.png` |
| AC-07 | screenshot + unit | PASS | `validation/AC-07-completed-success.png` |
| AC-08 | unit | PASS | Store + 兩 VM `testDeleteSameTitleRemovesOnlySelected` |
| AC-09 | unit | PASS | `testDeleteRemovesOnlyTargetAndSurvivesRelaunch` |
| AC-10 | screenshot + unit | PASS | `validation/AC-10-todo-failure.png`、`validation/AC-10-completed-failure.png` |
| Regression 新增 banner | screenshot | PASS | `validation/regression-add-success.png` |
| 全部 unit tests | `ios-build test` | PASS | passed 40, failed 0 |

## Workflow Ledger 摘要

| Gate | 狀態 |
|------|------|
| Spec Artifact | PASS |
| Spec Review Verdict | PASS（RD approve round 1） |
| Implementation Coverage | PASS（P0–P4） |
| Compilation | PASS |
| Validation | PASS（AC-01 手勢 / AC-02 BLOCKED-by-test-harness，RD 手動） |
| Self-review | PASS（7.5/10，Critical 0） |

## AI Delivery Assessment

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirement coverage | Complete | RTM DEL-01~08、DEL-ID 皆有實作 |
| UI/design coverage | Partial | 系統元件（OQ-07）；無 Figma 比對 |
| State/variant coverage | Complete | SV-01~22；swipe 手勢為手動 |
| Build | Pass | `ios-build build` |
| Tests | Pass | 40 passed |
| Code review | Issues fixed / Remaining | 補 Completed 同名 test；Major 列為選擇性 follow-up |

## Learning Loop

- Existing lessons applied: None（learning log 無 entry）
- New learning candidates：learning log 實際路徑為 `.claude/evaluation/agent-learning-log.md`（非 `docs/`）；`RefDoc_Temp/<id>/attachments/` 未被 `.gitignore` 涵蓋，commit 時需明確指定檔案
- Learning log updates: None

## 未完成項目的脈絡

| 項目 | 原因 | 建議做法 |
|------|------|----------|
| AC-01 / AC-02 手勢截圖 | 無 UI test target，simctl 無法滑動 | RD 手動截圖，或新增 UI test target |
| Figma 視覺比對 | session 無 Figma 工具 | RD 對照 node 比對 |
| `showError` 丟棄訊息（review Major） | 既有 SID-1 語意；刪除流程中不可達 | 若需要，改為 alert 佇列 |
| review Minor：alert action 內手動 dismiss 冗餘 | 以 `isBeingDismissed` / `presentingViewController` 守護，無害 | 可保留或移除 |

## 下一步行動（給接手 Agent）

1. 執行上方驗證指令確認 HEAD 一致；不一致時 `git log 4715a06..HEAD --oneline` 查看 RD 額外 commits，停止並通知 RD。
2. 一致時：閱讀本文件與 spec，依「還差什麼」決定修改，完成後更新 PR targeting `develop`。
