# SID-3 Handoff Document

> **⚠️ 接手前必讀**：請先檢查下方「最後一筆 Commit」的 SHA 是否與目前分支的 HEAD 一致。
> 若不一致，代表 RD 在交接後有額外修改，**請先與 RD 確認變更內容後再繼續作業**，避免覆蓋 RD 的修改。

## 驗證指令

```bash
EXPECTED_SHA="5134db1293a68b0111416043f89844057235dbfc"
CURRENT_SHA=$(git rev-parse HEAD)
if [ "$EXPECTED_SHA" != "$CURRENT_SHA" ]; then
  echo "⚠️ WARNING: HEAD ($CURRENT_SHA) 與紀錄的 commit ($EXPECTED_SHA) 不一致！請先與 RD 確認。"
  exit 1
else
  echo "✅ Commit 一致，可以繼續作業。"
fi
```

> 註：上面的 SHA 是程式碼 commit。這份 handoff 文件本身會在它之後再多一個 `docs: add handoff document for SID-3` commit，比對時以 `git log 5134db1..HEAD --oneline` 只剩這個 docs commit 為準。

---

# For RD

## 做了什麼

已完成頁的標題「已完成」下方新增數量文字「共完成 N 件」，樣式與待辦頁的「還有 N 件事，從一件開始。」相同（`.subheadline`、動態字級、`.secondaryLabel`、`numberOfLines = 0`，放在 spacing 4 的垂直 `headerStack` 裡）。沒有已完成任務時，沿用原本的空狀態「尚未有已完成的任務」，數量文字隱藏。

文案由 ViewModel 產生：`CompletedListViewModel.State` 的 `.content` 改為 `content(rows:countText:)`，`makeState` 以 `rows.count` 產生「共完成 N 件」。完成任務 / 刪除任務後的即時更新沿用既有的 `store.itemsPublisher` pipeline，沒有新增任何 publisher、型別或注入點。

因為 `State` 形狀改變，另外一併修改了 PRD 影響範圍沒列到的 `Support/DebugLaunchScenario.swift`（`#if DEBUG` 截圖 hook）的 pattern match，否則 build 會失敗。

## 還差什麼

- [ ] RD review Draft PR，確認後轉為 Ready for review
- [ ] （選擇性）以大字級（Dynamic Type）手動確認數量文字換行 — 沒有自動化截圖 hook，屬性設定與待辦頁相同

## 要注意什麼

- 沒有 Figma 工具，視覺依 PRD §5 與待辦頁既有 header 實作；Figma node `15-3` 沒有比對。
- `ios-build test -- -only-testing:...` 的參數會被忽略，實際跑的是全部 43 個 unit test（PRD 要求範圍的超集合），全數通過。
- AC-1（剛好 1 筆）與 AC-5（刪到 0 筆）沒有 DEBUG seed，只以 unit test 驗證；AC-5 最終畫面與 AC-3 截圖相同。
- 沒有 Open Questions，所以沒有「approve 時採用預設值」的項目。

## Acceptance Criteria 對應狀態

| # | Acceptance Criteria | 狀態 | 備註 |
|---|-------------------|------|------|
| AC-1 | 1 筆已完成 → 「共完成 1 件」 | ✅ | `testSingleCompletedItemShowsCountText` |
| AC-2 | 3 筆已完成 + 2 筆未完成 → 「共完成 3 件」 | ✅ | `testCountTextExcludesPendingItems` ＋ 截圖 |
| AC-3 | 無已完成 → 空狀態，不顯示數量 | ✅ | `testNoCompletedItemsShowsEmptyState` ＋ 截圖 |
| AC-4 | 刪除 1 筆（原 2 筆）→ 2 → 1 | ✅ | `testDeleteUpdatesCountText` ＋ 截圖（3 → 2） |
| AC-5 | 刪除最後 1 筆 → 空狀態，數量隱藏 | ✅ | `testDeleteLastItemShowsEmptyState`（延伸） |
| AC-6 | `CompletedListViewModelTests` 全數通過 | ✅ | 全部 43 個 unit test 通過 |

## 怎麼測

1. `ios-build build`，然後 `ios-build test` → 預期 `TESTS PASSED: passed 43, failed 0`。
2. `ios-build run -- -UI_SCENARIO content -UI_TAB completed` → 已完成頁標題下方顯示「共完成 3 件」。
3. 在已完成頁左滑任一筆 →「刪除」→「確認」→ 數量變成「共完成 2 件」，並出現「任務已刪除」banner。
4. 切到待辦頁勾選一筆完成 → 切回已完成頁，數量 +1。
5. `ios-build run -- -UI_SCENARIO empty -UI_TAB completed` → 只顯示「尚未有已完成的任務」，標題下方沒有數量文字。

---

# For AI Agent

## 基本資訊

| 欄位 | 值 |
|------|-----|
| **Ticket** | SID-3 |
| **Ticket URL** | https://a0188000.atlassian.net/browse/SID-3 |
| **Branch** | feature/SID-3 |
| **Base Branch** | develop |
| **最後一筆 Commit** | `5134db1293a68b0111416043f89844057235dbfc` — feat: show completed count on completed list |
| **Commit 時間** | 2026-09-28 20:10:49 +0800 |
| **Build 狀態** | ✅ Builds |
| **Format** | N/A — swiftformat not installed |
| **Spec Review** | 本機 dashboard，Round 1 approve by RD @ 2026-09-28T20:06:49+08:00 |

## Spec 文件位置

| 文件 | 路徑 |
|------|------|
| 需求規格 | `RefDoc_Temp/SID-3/requirement-spec.md` |
| Codebase 分析 | `RefDoc_Temp/SID-3/codebase-analysis.md` |
| 執行 Ledger | `RefDoc_Temp/SID-3/feature-execution-ledger.md` |
| 驗證截圖 | `RefDoc_Temp/SID-3/validation/` |

## 架構決策

- 只擴充既有 `State` enum 的 associated value（`content(rows:countText:)`），比照 `TodoListViewModel`；不新增 `@Published`、State case、型別、protocol 或注入點。
- `countText` 在 `makeState`（純函式）產生，VC 只顯示；`.empty` 時型別上就沒有 countText，VC 隱藏 `countLabel`。
- 不抽共用 header 元件（PRD §9、CLAUDE.md），`headerStack` 直接在 `setUpViews()` 組裝。

## 關鍵 Code Path

```
SceneDelegate → CompletedListViewController.viewDidLoad → CompletedListViewModel.viewDidLoad
  → TodoStoring.itemsPublisher.map(makeState) → $state → CompletedListViewController.render → countLabel
```

## Implementation Phases

- [x] P0: 沿用既有 Model / Store / pipeline / cell / banner（G-7、G-8、G-9 N/A、G-10）
- [x] P1: VM `State` + `makeState` + `didTapDelete` pattern、DEBUG hook pattern、測試（G-1、G-2、G-4、G-5、G-6）
- [x] P2: VC `countLabel` + `headerStack` + constraints + `render`（G-3）

## 變更檔案清單

> `git diff --name-only origin/develop...5134db1293a68b0111416043f89844057235dbfc`

| 類型 | 檔案 |
|------|------|
| 新增 | `RefDoc_Temp/SID-3/requirement-spec.md`、`RefDoc_Temp/SID-3/codebase-analysis.md`、`RefDoc_Temp/SID-3/feature-execution-ledger.md`（validation 截圖與本文件在 handoff commit 加入） |
| 修改 | `TodoList/TodoList/ViewModels/CompletedListViewModel.swift`、`TodoList/TodoList/Views/CompletedListViewController.swift`、`TodoList/TodoList/Support/DebugLaunchScenario.swift`、`TodoList/TodoListTests/CompletedListViewModelTests.swift` |
| 刪除 | 無 |

## 驗證證據

| Scenario | 方式 | 結果 | 證據 |
|----------|------|------|------|
| AS-01 / AC-1 | unit test | PASS | `testSingleCompletedItemShowsCountText` |
| AS-02 / AC-2 | unit test ＋ screenshot | PASS | `testCountTextExcludesPendingItems`、`RefDoc_Temp/SID-3/validation/AC-2-completed-count.png` |
| AS-03 / AC-3 | unit test ＋ screenshot | PASS | `testNoCompletedItemsShowsEmptyState`、`RefDoc_Temp/SID-3/validation/AC-3-completed-empty.png` |
| AS-04 / AC-4 | unit test ＋ screenshot | PASS | `testDeleteUpdatesCountText`、`RefDoc_Temp/SID-3/validation/AC-4-completed-after-delete.png` |
| AS-05 / AC-5 | unit test | PASS | `testDeleteLastItemShowsEmptyState` |
| AS-06 | unit test | PASS | `testNewlyCompletedItemAppears`（斷言「共完成 1 件」） |
| AS-07 / AC-6 | unit test | PASS | `ios-build test` → `TESTS PASSED: passed 43, failed 0, skipped 0` |
| NFR-1 樣式一致 | screenshot 目視比對 | PASS | `RefDoc_Temp/SID-3/validation/regression-todo-count.png` vs AC-2 截圖 |
| SV-08 Dynamic Type | — | N/A | 沒有大字級截圖 hook；屬性與待辦頁相同 |

## Workflow Ledger 摘要

| Gate | 狀態 |
|------|------|
| Spec Artifact | PASS |
| Spec Review Verdict | PASS（Round 1 approve） |
| Implementation Coverage | PASS（P0~P2） |
| Compilation | PASS |
| Validation | PASS（SV-08 N/A） |
| Self-review | PASS（Critical 0 / Major 0 / Minor 2 不需修改） |

## AI Delivery Assessment

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirement coverage | Complete | FR-1~FR-4、NFR-1~NFR-2 全部對應實作（Traceability Matrix） |
| UI/design coverage | Complete（無 Figma 比對） | validation 截圖；Figma N/A — no Figma tool |
| State/variant coverage | Complete（SV-08 N/A） | AS-01~AS-07 |
| Build | Pass | `ios-build build` → BUILD SUCCEEDED |
| Tests | Pass | 43 / 43 |
| Code review | Pass | `@code-reviewer` 約 9.7/10 |

## Learning Loop

- Existing lessons applied: None（learning log 沒有 entry）
- New learning candidates:
  1. `ios-build test -- -only-testing:<target>/<Class>` 的參數會被忽略、仍跑完整 suite；PRD 要求限定範圍時直接跑 `ios-build test` 並以 `passed N` 確認範圍。
  2. 修改 enum associated value 形狀時，用 `git grep` 找出所有 pattern match 呼叫端（含 `#if DEBUG` 截圖 hook 與 tests），不要只依賴 PRD 的影響範圍清單。
- Learning log updates: None — 寫入 `.claude/evaluation/agent-learning-log.md` 需要額外權限，這次 session 沒有取得；請 RD 視需要把上面的 candidates 加進 log。

## 未完成項目的脈絡

| 項目 | 原因 | 建議做法 |
|------|------|----------|
| Figma node `15-3` 比對 | 沒有 Figma 工具 | 有工具時開 node 與 `AC-2-completed-count.png` 比對 |
| 大字級截圖 | 沒有 Dynamic Type launch hook | 模擬器「設定 → 輔助使用 → 更大字體」手動確認 |

## 下一步行動（給接手 Agent）

1. 執行上方驗證指令確認 HEAD 一致；不一致時 `git log 5134db1293a68b0111416043f89844057235dbfc..HEAD --oneline` 查看 RD 額外 commits，停止並通知 RD。
2. 一致時：閱讀本文件與 spec，依「還差什麼」決定修改，完成後更新 PR（targeting `develop`）。
