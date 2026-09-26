# SID-1 Feature Execution Ledger

## SA/SD Input Inventory

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Jira summary read | PASS | `jira summary SID-1` — description empty, no comments | |
| Attachments downloaded | PASS | `RefDoc_Temp/SID-1/Todo_List_iOS_PRD.pdf` (6 pages, fully read by @requirement-analyzer) | |
| Remote links read | PASS | `jira remotelinks SID-1` → Figma `iXusvkslanTTXnoaU8BXm0` node `6-244` | |
| Related tickets | N/A | no issue links on SID-1 | |
| Learning log read | PASS | `.claude/evaluation/agent-learning-log.md` — no entries | |

## Spec Artifact Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| requirement-spec.md required sections | PASS | §2 Spec ↔ Figma Conflicts, §4 State / Variant Matrix (SV-01~24), §5 RTM (REQ-01~27), §6 Acceptance Scenarios (AC-01~24), §7 Open Questions (OQ-01~12 + scan log) | |
| codebase-analysis.md required sections | PASS | Gap Analysis (GAP-01~14), Architecture Decisions, Client/Backend Responsibility Analysis, Implementation Phases (P0~P7), Acceptance Criteria, Test Plan, Delivery Quality Plan | |
| Gap rows each in exactly one phase | PASS | Implementation Phases table: GAP-01~14 each listed once | |
| State/Variant rows mapped to AC | PASS | spec §6 "SV → AC 對照檢查"; SV-05/06/23 N/A with reason | |
| Spec committed | PASS | commit `docs: add SA/SD spec for SID-1` on `feature/SID-1` | |

## Visual Spec Asset Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Figma screen-level node mapping + screenshots | N/A | spec §2, §8 | No Figma MCP tool available in this session; State/Variant Matrix derived from PRD text; tracked as OQ-08 |

## Spec Review Feedback Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Round 1 comments processed | N/A | `.pipeline/spec_comments/` empty (no overview / block comments) | approved without comments; OQ defaults in codebase-analysis.md Implementation Phases accepted as-is |

## Spec Review Verdict Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Explicit RD approve | PASS | `.pipeline/spec_decision.json` — decision `approve`, reviewer `RD`, at `2026-09-26T17:15:22+08:00` | OQ-12 (add TodoListTests target via pbxproj) approved together with the spec |

## Implementation Coverage Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| P0 範圍確認（GAP-05） | PASS | 無任何網路 / 後端程式碼（`grep URLSession` 0 筆） | BE-owned：無 |
| P1 Data layer（GAP-01、02、03、04） | PASS | `Models/TodoItem.swift`、`Services/TodoStoring.swift`、`Services/FileTodoStore.swift`、`Support/CompletionDateFormatter.swift` | OQ-11 預設：毀損檔改名備份、視為空清單；OQ-09 預設「M月d日完成」/跨年加年份 |
| P2 App root（GAP-06、14） | PASS | `SceneDelegate.swift` 程式化 `UITabBarController`；`Info.plist` 移除 `UISceneStoryboardFile`；pbxproj 移除 `INFOPLIST_KEY_UIMainStoryboardFile`；刪除 `Main.storyboard`、`ViewController.swift` | |
| P3 待辦清單頁（GAP-07、08、09） | PASS | `ViewModels/TodoListViewModel.swift`、`Views/TodoListViewController.swift`、`Views/TodoRowCell.swift` | OQ-04 預設 alert「標記完成失敗，請再試一次」；OQ-10 N=0 隱藏數量文字 |
| P4 新增任務頁（GAP-10） | PASS | `ViewModels/AddTodoViewModel.swift`、`Views/AddTodoViewController.swift`（fullScreen modal、keyboardLayoutGuide） | OQ-02 預設：輸入截斷至 100 字（組字中不截斷） |
| P5 已完成頁（GAP-11） | PASS | `ViewModels/CompletedListViewModel.swift`、`Views/CompletedListViewController.swift`、`Views/CompletedRowCell.swift` | |
| P6 視覺基準（GAP-12） | PASS | 系統語意色（淺灰背景 / 白色 insetGrouped 容器）、`Views/UIButton+Primary.swift`（藍色 54pt）、左右 24pt、Dynamic Type、44pt 圓圈觸控 | OQ-07 預設：系統色自動適配深色；OQ-08 無 Figma → 色值 / icon 為系統預設 |
| P7 Test target（GAP-13） | PASS | pbxproj 新增 `TodoListTests`（synchronized group、TEST_HOST）；`xcshareddata/xcschemes/TodoList.xcscheme`；`TodoListTests/*.swift` 22 tests | OQ-12 隨 spec approve 同意 |
| Cross-phase：Gap rows / AC 全覆蓋 | PASS | GAP-01~14 全部實作；AC-01~24 見 Validation Gate | |

## Compilation Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| `ios-build build` succeeds | PASS | `ios-build build` → `BUILD SUCCEEDED`（sim `3BEBA0CE-DF13-42C5-9B6A-A18A8E3D5407`, iPhone 17 Pro iOS 26.3.1），0 warning（排除 appintents 雜訊） | 修正過：`UIFont.bold()` 不存在 → `UIFontMetrics`；測試缺 `import Combine` |

## Validation Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Unit tests | PASS | `ios-build test` → xcresult `Test-TodoList-2026.09.26_17-35-15`：22 passed / 0 failed | 建立 VM 的測試為 async（iOS 26.3 runtime 於同步 XCTest 方法釋放 MainActor 物件時在 `swift_task_deinitOnExecutor` 崩潰；App 內開→關新增頁已驗證不崩潰） |
| AC-01 開啟 App | PASS | `validation/AC-01.png` + `TodoListViewModelTests.testShowsPendingItemsNewestFirstWithCount` | |
| AC-02 新增頁初始 | PASS | `validation/AC-02.png` + `AddTodoViewModelTests.testInitialStateIsDisabled` | 截圖下半為模擬器首次鍵盤導覽 |
| AC-03 空白字元 | PASS | `testWhitespaceOnlyTitleKeepsSubmitDisabled` | |
| AC-04 有效名稱 | PASS | `testValidTitleEnablesSubmit` | |
| AC-05 新增一筆置頂 | PASS | `testSubmitStoresTrimmedTitleAndFinishes` + `testAddedItemIsMarkedAndBannerHidesAfterDuration` | |
| AC-06 連點只建立一筆 | PASS | `testRepeatedSubmitCreatesOnlyOneItem` | |
| AC-07 取消 | PASS | DEBUG 開→關新增頁後清單不變（runtime 驗證）；提交中停用「取消」（self-review C-1 修正） | 無草稿：每次開啟建立新 VM/VC |
| AC-08 新增成功 | PASS | `validation/AC-08.png` + `testAddedItemIsMarkedAndBannerHidesAfterDuration` | |
| AC-09 標記完成 | PASS | `testTapCircleMovesItemOutOfPending`、`testNewlyCompletedItemAppears`、`testRepeatedTapOnSameCircleCompletesOnce` | 點擊互動截圖：BLOCKED-by-test-harness（無 UI 自動化點擊） |
| AC-10 切換 Tab | PASS | `validation/AC-01.png`、`validation/AC-18.png`（兩 Tab 選取狀態）；VC 常駐不重建（架構） | 互動切換需 RD 手動確認 |
| AC-11 重啟保留 | PASS | `FileTodoStoreTests.testAddAndCompleteSurviveRelaunch` | 實機重啟由 RD 手動確認 |
| AC-12 空 / 很多 | PASS | `validation/AC-24-todo-empty.png`、`validation/AC-12-many.png`（清單底部止於新增按鈕上方，不被 Tab Bar 遮住） | |
| AC-13 新增失敗 | PASS | `testSaveFailureShowsErrorAndAllowsRetry`、`FileTodoStoreTests.testAddFailureLeavesItemsUnchanged` | |
| AC-14 鍵盤 / 大字體 | PASS（鍵盤）/ BLOCKED-by-test-harness（大字體） | `validation/AC-02.png`：主要按鈕位於鍵盤上方 | 全部元件使用 Dynamic Type；大字體截圖需 RD 手動 |
| AC-15 完成失敗 | PASS | `testCompletionFailureKeepsItemAndReportsError` | |
| AC-16 長名稱 | PASS | `validation/AC-01.png`、`validation/AC-12-many.png` | |
| AC-17 100 字 / 重複 | PASS | `testTitleLengthLimit`、`testDuplicateTitlesAreAllowed` | |
| AC-18 完成時間文字 | PASS | `validation/AC-18.png` + `testCompletedItemsSortedNewestFirstWithRelativeText`、`testFormatterShowsYearForPreviousYear` | |
| AC-19 已完成空狀態 | PASS | `validation/AC-19.png` + `testNoCompletedItemsShowsEmptyState` | |
| AC-20 提示結束 | PASS | `validation/AC-20.png` + `testAddedItemIsMarkedAndBannerHidesAfterDuration` | |
| AC-21 排序 | PASS | `testShowsPendingItemsNewestFirstWithCount`、`testCompletedItemsSortedNewestFirstWithRelativeText` | |
| AC-22 trim | PASS | `testSubmitStoresTrimmedTitleAndFinishes` | |
| AC-23 無障礙 | BLOCKED-by-test-harness | 程式碼：圓圈 44×44pt、accessibilityLabel/Value、已完成 cell 合併朗讀「已完成」 | VoiceOver 需 RD 以 Accessibility Inspector 手動確認 |
| AC-24 首次啟動 | PASS | `validation/AC-24-todo-empty.png`、`validation/AC-19.png` + `testMissingFileLoadsEmpty`、`testEmptyStoreShowsEmptyState` | |

## Self-review Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| @code-reviewer run, critical findings fixed | PASS | C-1 提交中可取消 → 已修（`AddTodoViewController` 綁定 `isSubmitting` 停用取消）；M-1 連續失敗 alert 被吞 → 已修（已有 alert 時不重複 present）；rebuild + 22 tests pass | m-1（已完成頁依賴待辦頁觸發 loadAll）、m-2（test target 未設 default isolation）列為 RD 參考，不影響行為 |

## Handoff Gate

| Required item | Status | Evidence | Notes |
|---------------|--------|----------|-------|
| Handoff doc, push, workpad tag, handoff.json | PASS | `RefDoc_Temp/SID-1_handoff.md`（commit `2c9cbde`）；`git push -u origin feature/SID-1`（以 `http.postBuffer` 重試成功）；workpad 已 tag assignee；`.pipeline/handoff.json` | code commit `1503ef1` |
