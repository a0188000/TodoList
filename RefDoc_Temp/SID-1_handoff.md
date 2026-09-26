# SID-1 Handoff Document

> **⚠️ 接手前必讀**：請先檢查下方「最後一筆 Commit」的 SHA 是否與目前分支的 HEAD 一致。
> 若不一致，代表 RD 在交接後有額外修改，**請先與 RD 確認變更內容後再繼續作業**，避免覆蓋 RD 的修改。
> 註：本文件與驗證截圖在 code commit 之後另以 `docs:` commit 提交，因此 HEAD 會比下方 SHA 多一筆 docs commit，屬正常。

## 驗證指令

```bash
EXPECTED_SHA="1503ef1c8637f2f87cbb1e30e7d960fbde9c7509"
git log --oneline "$EXPECTED_SHA"..HEAD   # 預期只有 "docs: add handoff document for SID-1"
```

---

# For RD

## 做了什麼

依已核准的 SA/SD spec（Round 1 approve，無 comment，OQ-01~12 採 `codebase-analysis.md` 預設值）完成 TODO List MVP：底部 Tab Bar（待辦 / 已完成）、待辦清單（新→舊、數量文字、空狀態、新增成功提示約 3 秒與「剛剛新增」標示、點圓圈標記完成）、新增任務頁（fullScreen modal、trim、100 字上限、提交中停用、失敗保留輸入並提示、取消不建立）、已完成清單（藍色勾選、灰色刪除線、今天/昨天/日期完成文字、空狀態）。

資料以 `FileTodoStore` 存成 Documents 下的 `todos.json`，**寫入成功後才更新 UI**；讀到毀損檔時改名備份（`todos.corrupt-<timestamp>.json`）並視為空清單。Root 改為 SceneDelegate 程式化建立 `UITabBarController`，移除 `Main.storyboard` 與 template `ViewController.swift`。

新增 `TodoListTests` unit test target（手動編輯 pbxproj + shared scheme），22 個測試涵蓋 3 個 ViewModel、Store 與日期文字；全部通過。另有 DEBUG-only 的 launch argument hook（`-UI_SCENARIO`、`-UI_TAB`、`-UI_ADD`）用於驗證截圖，不進 Release。

## 還差什麼

- [ ] 視覺比對 Figma（node `6-244`）：本 session 無 Figma 工具，色值 / 字體 / Tab icon / 成功提示樣式皆採系統預設（OQ-08）
- [ ] 手動驗證：VoiceOver（AC-23）、大字體 Dynamic Type（AC-14）、實機點擊完成與 Tab 來回切換（AC-09 / AC-10 互動）、殺掉 App 重開（AC-11）
- [ ] 產品確認 OQ 預設值是否保留（見下方「要注意什麼」）
- [ ] 建立 PR 到 `develop`

## 要注意什麼

- **OQ 預設值**：OQ-02 輸入截斷至 100 字（注音組字中不截斷）；OQ-04 完成失敗以 alert「標記完成失敗，請再試一次」；OQ-07 不強制淺色，系統語意色自動適配深色；OQ-09 更早日期「M月d日完成」，跨年「yyyy年M月d日完成」；OQ-10 N=0 隱藏數量文字；OQ-11 毀損檔備份後視為空清單。每項改動點都集中在單一函式 / 檔案。
- **測試 async workaround**：iOS 26.3 simulator runtime 在 XCTest *同步* 測試方法中釋放 MainActor-isolated 物件會於 `swift_task_deinitOnExecutor`（`TaskLocal::StopLookupScope`）malloc abort；建立 ViewModel 的測試因此寫成 `async`。App 內開→關新增頁（釋放 `AddTodoViewModel`）已在模擬器驗證不崩潰。
- 提交中「取消」會停用（self-review 修正，避免取消後儲存仍完成而誤新增）。
- 已完成頁的初次資料載入依賴待辦頁 `viewDidLoad` 觸發 `loadAll()`（預設 Tab 為待辦，目前無影響；若調整預設 Tab 需一併處理）。
- 「今天完成 / 昨天完成」在資料變動時計算；App 跨午夜常駐而無資料變動時不會自動刷新。
- `swiftformat` 未安裝，未執行格式化。

## Acceptance Criteria 對應狀態

| # | Acceptance Criteria | 狀態 | 備註 |
|---|-------------------|------|------|
| AC-01 | 開啟 App 預設待辦、新→舊、數量 | ✅ | 截圖 + unit test |
| AC-02 | 新增頁初始空白、入口停用、無 Tab Bar | ✅ | 截圖 + unit test |
| AC-03 | 只有空白 → 停用 | ✅ | unit test |
| AC-04 | 有效名稱 → 啟用 | ✅ | unit test |
| AC-05 | 任一入口只建立一筆並置頂 | ✅ | unit test |
| AC-06 | 連點只建立一筆 | ✅ | unit test |
| AC-07 | 取消不建立、不保留草稿 | ✅ | runtime 開→關驗證 + 提交中停用取消 |
| AC-08 | 新增成功 N+1、剛剛新增、提示 | ✅ | 截圖 + unit test |
| AC-09 | 標記完成移至已完成 | ✅ | unit test；點擊互動需手動 |
| AC-10 | 切換 Tab 資料保留 | ✅ | 兩 Tab 截圖；互動切換需手動 |
| AC-11 | 重啟保留 | ✅ | store round-trip test；實機重開需手動 |
| AC-12 | 空狀態 / 長清單不被 Tab Bar 遮住 | ✅ | 截圖 |
| AC-13 | 新增失敗保留輸入並提示 | ✅ | unit test |
| AC-14 | 鍵盤 / 大字體 | ⚠️ | 鍵盤 ✅（截圖）；大字體需手動 |
| AC-15 | 完成失敗維持原狀 | ✅ | unit test |
| AC-16 | 長名稱換行 | ✅ | 截圖 |
| AC-17 | 100 字上限、允許重複 | ✅ | unit test |
| AC-18 | 今天 / 昨天 / 日期 | ✅ | 截圖 + unit test |
| AC-19 | 已完成空狀態 | ✅ | 截圖 + unit test |
| AC-20 | 約 3 秒提示消失 | ✅ | 截圖 + unit test |
| AC-21 | 排序 | ✅ | unit test |
| AC-22 | trim | ✅ | unit test |
| AC-23 | VoiceOver / 44pt | ⚠️ | 程式已設定；需 Accessibility Inspector 手動 |
| AC-24 | 首次啟動空狀態 | ✅ | 截圖 + unit test |

## 怎麼測

1. `ios-build build` → `BUILD SUCCEEDED`；`ios-build test` → 22 passed。
2. 模擬器執行 App：新增任務 → 確認置頂、「剛剛新增」、「任務已新增」約 3 秒後消失 → 點圓圈 → 切到「已完成」確認出現在頂端。
3. 預載資料：`xcrun simctl launch --terminate-running-process <sim> com.todoList.TodoList -UI_SCENARIO content`（可加 `-UI_TAB completed` 或 `-UI_ADD open|success`；`empty` / `many` 為其他資料集）。
4. 設定 > 輔助使用開啟 VoiceOver 與大字體檢查 AC-14 / AC-23。

---

# For AI Agent

## 基本資訊

| 欄位 | 值 |
|------|-----|
| **Ticket** | SID-1 |
| **Ticket URL** | https://a0188000.atlassian.net/browse/SID-1 |
| **Branch** | feature/SID-1 |
| **Base Branch** | develop |
| **最後一筆 Commit** | `1503ef1c8637f2f87cbb1e30e7d960fbde9c7509` — feat: add todo list, add task and completed screens |
| **Commit 時間** | 2026-09-26 |
| **Build 狀態** | ✅ Builds |
| **Format** | N/A — swiftformat not installed |
| **Spec Review** | 本機 dashboard，Round 1 approve by RD @ 2026-09-26T17:15:22+08:00 |

## Spec 文件位置

| 文件 | 路徑 |
|------|------|
| 需求規格 | `RefDoc_Temp/SID-1/requirement-spec.md` |
| Codebase 分析 | `RefDoc_Temp/SID-1/codebase-analysis.md` |
| 執行 Ledger | `RefDoc_Temp/SID-1/feature-execution-ledger.md` |
| 驗證截圖 | `RefDoc_Temp/SID-1/validation/` |

## 架構決策

- 單一 shared `FileTodoStore`（MainActor、JSON 檔）由 SceneDelegate 建立並以 initializer 注入 3 個 ViewModel；`TodoStoring` protocol 供測試替換。
- `itemsPublisher`（全部任務）＋ `addedItemPublisher`（僅新增成功時發送，驅動「剛剛新增」與提示），避免以陣列 diff 推測新項目。
- ViewModel Input = 方法、Output = `@Published` / `PassthroughSubject`；非同步以 `Task {}` 繼承 MainActor。
- 兩個 Tab VC 常駐，不重建，天然滿足 Tab 切換保留資料。
- 新增頁 fullScreen modal、自繪取消 / 新增按鈕，無 UINavigationController；主要按鈕跟隨 `keyboardLayoutGuide`。

## 關鍵 Code Path

```
SceneDelegate → UITabBarController
  ├─ TodoListViewController → TodoListViewModel → FileTodoStore → Documents/todos.json
  │     └─ (present) AddTodoViewController → AddTodoViewModel → FileTodoStore.add
  └─ CompletedListViewController → CompletedListViewModel (+ CompletionDateFormatter) → FileTodoStore.itemsPublisher
```

## Implementation Phases

- [x] P0: 範圍確認，無後端
- [x] P1: Data layer（TodoItem / TodoStoring / FileTodoStore / CompletionDateFormatter）
- [x] P2: App root（程式化 Tab Bar、移除 storyboard 入口與 template 孤兒）
- [x] P3: 待辦清單頁
- [x] P4: 新增任務頁
- [x] P5: 已完成頁
- [x] P6: 視覺基準（系統色，無 Figma token）
- [x] P7: TodoListTests target + 22 unit tests

## 變更檔案清單

> `git diff --name-only origin/develop...1503ef1c8637f2f87cbb1e30e7d960fbde9c7509`

| 類型 | 檔案 |
|------|------|
| 新增 | `TodoList/TodoList/Models/TodoItem.swift`、`Services/TodoStoring.swift`、`Services/FileTodoStore.swift`、`Support/CompletionDateFormatter.swift`、`Support/DebugLaunchScenario.swift`、`ViewModels/{TodoList,AddTodo,CompletedList}ViewModel.swift`、`Views/{TodoList,AddTodo,CompletedList}ViewController.swift`、`Views/{TodoRow,CompletedRow}Cell.swift`、`Views/UIButton+Primary.swift`、`TodoList/TodoListTests/*.swift`（5 檔）、`TodoList.xcodeproj/xcshareddata/xcschemes/TodoList.xcscheme`、`RefDoc_Temp/SID-1/*`（spec、ledger、PRD、validation） |
| 修改 | `TodoList/TodoList/SceneDelegate.swift`、`TodoList/TodoList/Info.plist`、`TodoList/TodoList.xcodeproj/project.pbxproj` |
| 刪除 | `TodoList/TodoList/ViewController.swift`、`TodoList/TodoList/Base.lproj/Main.storyboard` |

## 驗證證據

| Scenario | 方式 | 結果 | 證據 |
|----------|------|------|------|
| AC-01 | screenshot + unit test | PASS | `validation/AC-01.png` |
| AC-02 | screenshot + unit test | PASS | `validation/AC-02.png` |
| AC-03~06、13、15、17、21、22 | unit test | PASS | `TodoListTests/*`（xcresult 2026-09-26 17:35，22/22） |
| AC-07 | runtime（DEBUG 開→關）+ code | PASS | ledger Validation Gate |
| AC-08 | screenshot + unit test | PASS | `validation/AC-08.png` |
| AC-09 | unit test | PASS（互動點擊 BLOCKED-by-test-harness） | `testTapCircleMovesItemOutOfPending` |
| AC-10 | screenshot | PASS | `validation/AC-01.png`、`validation/AC-18.png` |
| AC-11 | unit test | PASS | `testAddAndCompleteSurviveRelaunch` |
| AC-12 | screenshot | PASS | `validation/AC-24-todo-empty.png`、`validation/AC-12-many.png` |
| AC-14 | screenshot | PASS（鍵盤）/ BLOCKED-by-test-harness（大字體） | `validation/AC-02.png` |
| AC-16 | screenshot | PASS | `validation/AC-12-many.png` |
| AC-18 | screenshot + unit test | PASS | `validation/AC-18.png` |
| AC-19 | screenshot + unit test | PASS | `validation/AC-19.png` |
| AC-20 | screenshot + unit test | PASS | `validation/AC-20.png` |
| AC-23 | — | BLOCKED-by-test-harness | 需 VoiceOver 手動 |
| AC-24 | screenshot + unit test | PASS | `validation/AC-24-todo-empty.png` |

## Workflow Ledger 摘要

| Gate | 狀態 |
|------|------|
| Spec Artifact | PASS |
| Spec Review Verdict | PASS（Round 1 approve） |
| Implementation Coverage | PASS（P0~P7） |
| Compilation | PASS |
| Validation | PASS（AC-14 大字體、AC-23 BLOCKED-by-test-harness；0 FAIL） |
| Self-review | PASS（C-1、M-1 已修） |

## AI Delivery Assessment

| Dimension | Status | Evidence |
|-----------|--------|----------|
| Requirement coverage | Complete | REQ-01~27 → GAP-01~14 → P0~P7 全實作 |
| UI/design coverage | Partial | 依 PRD p5 文字基準；無 Figma 比對（OQ-08） |
| State/variant coverage | Complete | SV-01~24（SV-05/06/23 依 spec N/A 或預設） |
| Build | Pass | `ios-build build` BUILD SUCCEEDED |
| Tests | Pass | `ios-build test` 22/22 |
| Code review | Issues fixed | @code-reviewer：C-1、M-1 修正；m-1、m-2 記錄 |

## Learning Loop

- Existing lessons applied: None（log 原本為空）
- New learning candidates（`.claude/evaluation/agent-learning-log.md` 屬受保護路徑，本 session 無法寫入，請 RD 評估後加入）：
  1. **Testing**：`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 專案在 iOS 26.3 simulator 上，XCTest *同步* 方法釋放 MainActor 物件會於 `swift_task_deinitOnExecutor` SIGABRT → 建立 VM 的測試寫成 `async`；`ios-build test` 只印 `TEST FAILED` 時用 `xcrun xcresulttool get test-results summary` / `export attachments` 讀 crash log。
  2. **Validation**：`ios-build screenshot` 無法帶 launch argument，env 前綴會被 unattended 權限拒絕 → `ios-build build` + `ios-build run` 安裝後，以 `xcrun simctl launch --terminate-running-process <udid> <bundle> -KEY value` 啟動、另一個 Bash call 執行 `xcrun simctl io <udid> screenshot <path>`；DEBUG hook 以 `UserDefaults.standard` 讀參數。
- Learning log updates: None（權限限制）

## 未完成項目的脈絡

| 項目 | 原因 | 建議做法 |
|------|------|----------|
| Figma 視覺比對 | 無 Figma 工具 | 取得 node 6-244 截圖後調整色值 / icon / 提示樣式 |
| AC-14 大字體、AC-23 VoiceOver | 無 UI 自動化 / 輔助功能自動檢查 | 模擬器手動檢查或加 UI test target |
| AC-09 / AC-10 互動點擊 | `ios-build` 無點擊能力 | 手動或 XCUITest |

## 下一步行動（給接手 Agent）

1. 執行上方驗證指令確認 HEAD；若有 RD 額外 commits，停止並通知 RD。
2. 一致時：閱讀本文件與 spec，依「還差什麼」決定修改，完成後建立 PR targeting `develop`。
