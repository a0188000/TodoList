# 已完成清單顯示完成數量 - Codebase Analysis

> 掃描範圍：`TodoList/TodoList/`（Models、Services、ViewModels、Views、Support、SceneDelegate）、`TodoList/TodoListTests/`、`CLAUDE.md`、`RefDoc_Temp/SID-2/codebase-analysis.md`（格式與既有決策參考）。
> 限制：只用 Swift + Combine、盡量使用 Swift concurrency、MVVM（Input 是 ViewModel method，Output 是 `@Published` / `PassthroughSubject`）。
> 掃描方式：`grep -rn "\.content(" TodoList --include='*.swift'`，列出所有 `State.content` pattern match 呼叫端（結果見 G-2 / G-3 / G-4 / G-5）。

## 現有能力

### ViewModel
- `ViewModels/CompletedListViewModel.swift`
  - `enum State: Equatable { case empty; case content(rows: [Row]) }`（第 16-19 行）— **沒有 countText**。
  - `viewDidLoad()`：`store.itemsPublisher.map(makeState).removeDuplicates().assign(to: &$state)`（第 48-53 行）。完成或刪除任務都會經由這條 pipeline 自動重算，FR-3 **不需要新邏輯**。
  - `makeState`（第 90-99 行）：過濾 `isCompleted && completedAt != nil` → 依 completedAt 由新到舊排序 → `rows.isEmpty ? .empty : .content(rows: rows)`。N = `rows.count` 可以直接在這裡算。
  - `didTapDelete(id:)` 第 56 行：`guard case let .content(rows) = state` — **State 改變後必須一起改**。
  - 另有 `bannerMessage`、`pendingDelete`、`errorMessage`（SID-2），與本需求無關，不動。
- `ViewModels/TodoListViewModel.swift`（參考範本）
  - `case content(rows: [Row], countText: String)`（第 18 行）。
  - `makeState` 結尾：`guard !rows.isEmpty else { return .empty }; return .content(rows: rows, countText: "還有 \(rows.count) 件事，從一件開始。")`（第 122-123 行）。
  - `didTapDelete` 使用 `case let .content(rows, _)`（第 75 行）— 已完成頁改完後應該是相同寫法。

### View
- `Views/CompletedListViewController.swift`
  - 只有 `titleLabel`；`titleLabel.top = safeArea.top + 16`，`tableView.top = titleLabel.bottom + 8`（第 155-159 行）。
  - `render(_:)`（第 58-68 行）：`.empty` → `tableView.backgroundView = emptyLabel`；`case let .content(rows)` → 設定 rows。**State 改變後必須一起改**，並加上 `countLabel` 的顯示 / 隱藏。
  - 空狀態文字「尚未有已完成的任務」是 `tableView.backgroundView`（第 130 行），FR-2 直接沿用。
  - 沒有底部按鈕，banner 在 safeArea 底部，與 header 不衝突。
- `Views/TodoListViewController.swift`（參考範本）
  - `countLabel` 設定（第 138-141 行）：`.subheadline`、`adjustsFontForContentSizeCategory = true`、`.secondaryLabel`、`numberOfLines = 0`。
  - `headerStack = UIStackView(arrangedSubviews: [titleLabel, countLabel])`，`axis = .vertical`、`spacing = 4`（第 143-145 行）；constraint：top = safeArea + 16、leading/trailing = layoutMargins；`tableView.top = headerStack.bottom + 8`（第 184-188 行）。
  - `render`：`.empty` → `countLabel.isHidden = true`；`.content(rows, countText)` → 設定 text 並 `isHidden = false`（第 71-84 行）。PRD §5 要求照這個寫法。

### Model / Store（不動）
- `TodoItem`、`TodoStoring`、`FileTodoStore`：PRD §8 明確排除。`itemsPublisher` 訂閱時馬上送出目前值。
- `SceneDelegate`：同一個 store 注入 `TodoListViewModel` 與 `CompletedListViewModel` → 在待辦頁完成任務時，已完成頁的數量會自動更新。

### DEBUG launch-arg hook（`Support/DebugLaunchScenario.swift`，`#if DEBUG`）
- Launch args：`-UI_SCENARIO <empty|content|many>`、`-UI_TAB completed`、`-UI_ADD <open|success>`、`-UI_DELETE <open|success|failure>`。
- Seed：
  - `content` = 3 筆未完成 + 3 筆已完成（繳電話費 / 預約牙醫 / 寄出包裹）→ 已完成頁應顯示「共完成 3 件」。
  - `empty` = 沒有資料 → 已完成頁是空狀態、不顯示數量。
  - `many` = 15 筆未完成、0 筆已完成 → 已完成頁也是空狀態。
- `-UI_TAB completed -UI_DELETE success`：延遲 500ms 後對已完成頁第一筆 `didTapDelete`，再 800ms 後 `didConfirmDelete` → 3 → 2，可以截到數量即時更新。
- **第 64 行 `guard case let .content(rows) = completedListViewModel.state, let row = rows.first`** — State 改變後會編譯失敗（`rows` 會被綁成 tuple）。PRD §0「影響範圍」**沒有列出這個檔案**，但必須修改（G-4）。第 71 行待辦頁已經是 `.content(rows, _)` 寫法，可以照抄。
- 結論：**截圖不需要新增任何 hook**。「剛好 1 筆已完成」（AC-1）與「刪到剩 0」（AC-5）沒有 seed 可以直接到達，由 unit test 驗證（PRD 為輕量任務，不為截圖新增 seed）。

### Tests
- `TodoListTests/CompletedListViewModelTests.swift`：`@MainActor`；所有建立 ViewModel 的測試方法都是 `async`（註解說明 iOS 26.3 simulator deinit 崩潰）。
  - 需要改 pattern match 的地方：第 45 行（`testCompletedItemsSortedNewestFirstWithRelativeText`）、第 62 行（`testNewlyCompletedItemAppears`）、第 108 行（`testConfirmDeleteRemovesTargetWithoutAffectingPending`）。
  - PRD 指定要延伸的：`testNoCompletedItemsShowsEmptyState`（第 25 行，AC-3）、`testDeleteLastItemShowsEmptyState`（第 136 行，AC-5）。
  - `testDeleteFailureKeepsItemAndReportsError` 以 `XCTAssertEqual(viewModel.state, stateBefore)` 比對，改完後會自動涵蓋 countText 不變。
- `TodoListTests/MockTodoStore.swift`：`MockTodoStore`（`items`、`shouldFail`、`deleteCallCount`、`markCompleted`、`delete`）、`makeItem(_:createdAt:completedAt:)`、`drainTasks()` — 都可以直接用，不需要修改。
- 沒有 UI test target。

## Model Gap Analysis

| ID | 類型 | 需求 | 現有 Model | 狀態 | 備註 |
|----|------|------|-----------|------|------|
| G-8 | Reuse | 計算已完成數量所需的欄位 | `TodoItem.isCompleted`、`completedAt` | 復用 | 不改 Model / JSON（PRD §8） |

## Service / API Gap Analysis

| ID | 類型 | 需求 | 現有 Service | 狀態 | 備註（App / BE 負責） |
|----|------|------|-------------|------|------------------------|
| G-7 | Reuse | 完成 / 刪除後即時更新（FR-3） | `TodoStoring.itemsPublisher` → `CompletedListViewModel.viewDidLoad` pipeline | 復用 | App；pipeline 不改，只改 `makeState` 的輸出 |
| G-9 | BE | 伺服器端計數 | 沒有 backend | N/A | 本機 JSON 儲存，沒有 API / BE 工作 |

## ViewModel Gap Analysis

| ID | 類型 | 需求 | 現有 | 狀態 | 變更內容 |
|----|------|------|------|------|----------|
| G-1 | Modify | `State.content` 帶 `countText`；`makeState` 產生「共完成 N 件」（FR-1、FR-2、FR-4） | `CompletedListViewModel` 第 16-19、98 行 | 缺 | `case content(rows: [Row], countText: String)`；`rows.isEmpty ? .empty : .content(rows: rows, countText: "共完成 \(rows.count) 件")`（PRD §5） |
| G-2 | Modify | VM 內部 pattern match 跟著改（編譯必要） | `CompletedListViewModel.didTapDelete` 第 56 行 | 缺 | `case let .content(rows)` → `case let .content(rows, _)`（比照 `TodoListViewModel` 第 75 行） |

## UI Gap Analysis

| ID | 類型 | 畫面 | 現有元件 | 狀態 | 變更內容 |
|----|------|------|---------|------|----------|
| G-3 | Modify | 已完成頁 | `CompletedListViewController` | 小改 | 新增 `countLabel`（subheadline / 動態字級 / secondaryLabel / numberOfLines 0）；`titleLabel` + `countLabel` 放進垂直 `headerStack`（spacing 4）；header top = safeArea + 16、leading/trailing = layoutMargins；`tableView.top` 改接 `headerStack.bottom + 8`；`render`：`.empty` → `countLabel.isHidden = true`，`.content(rows, countText)` → 設定 text 並顯示（第 63 行 pattern match 也在這裡改）。不抽共用元件（PRD §9） |
| G-10 | Reuse | 空狀態 / 列表 / cell / banner | `emptyLabel`、`CompletedRowCell`、banner | 復用 | 不變 |

## Test / DEBUG Gap Analysis

| ID | 類型 | 需求 | 現有 | 狀態 | 變更內容 |
|----|------|------|------|------|----------|
| G-4 | Modify | DEBUG hook pattern match（編譯必要；PRD 影響範圍沒有列出） | `DebugLaunchScenario.swift` 第 64 行 | 缺 | `case let .content(rows)` → `case let .content(rows, _)`；不新增 launch arg |
| G-5 | Modify | 既有測試 pattern match（AC-6） | `CompletedListViewModelTests` 第 45、62、108 行 | 缺 | 改成 `case let .content(rows, _)`，或在適合的地方斷言 countText（第 62 行建議斷言「共完成 1 件」，對應 AS-06） |
| G-6 | New / Extend tests | AC-1、AC-2、AC-4 新增；AC-3、AC-5 延伸既有測試 | `CompletedListViewModelTests` | 缺 | 新增 3 個 `async` 測試；延伸 `testNoCompletedItemsShowsEmptyState`（斷言 `.empty`，已經有）與 `testDeleteLastItemShowsEmptyState`（刪除前斷言 `countText == "共完成 1 件"`，刪除後 `.empty`）。沿用 `MockTodoStore` / `makeItem` / `drainTasks` |

## 待處理項目（職責、依賴、風險）

- **職責**：全部由 App 負責；沒有 BE（G-9）。
- **依賴順序**：G-1 改變 `State` 形狀後，G-2、G-3（render）、G-4、G-5 **全部都會編譯失敗**，必須在同一次 build 前一起改好，app target 與 test target 才能編譯。
- **風險 1 — PRD 影響範圍漏列**：PRD 只列了 VM / VC / Tests，但 `DebugLaunchScenario.swift`（DEBUG build，test target 也會編譯到）也 pattern match 了 `CompletedListViewModel.State`。沒改的話，`ios-build build` 與 `ios-build test` 都會失敗。
- **風險 2 — 測試範圍工具限制**：PRD §7 要求只跑 `-only-testing:TodoListTests/CompletedListViewModelTests`，但 `ios-build help` 只列出 `ios-build test`（跑全部 unit tests），**沒有文件記載的 scoping 參數**。`ios-build` 放在 worktree 之外（`/Users/shenweiting/Desktop/TodoList-pipeline/pipeline/bin/ios-build`），這個 agent 沒有檢查它的原始碼。處理方式見 Test Plan。
- **不變項**：`TodoItem`、`TodoStoring`、`FileTodoStore`、`MockTodoStore`、`TodoListViewModel` / `TodoListViewController`、`SceneDelegate`、cell 類別。

---

## Architecture Decisions

### 判斷
Gap Analysis（G-1~G-10）與 Implementation Phases（P0~P2）驗證無誤，同意照案執行，不調整任何 gap row 或 phase。以 `git grep '\.content('` 覆核過全部 7 個 `CompletedListViewModel.State.content` pattern match 呼叫端（VM 內部 2 處、VC 1 處、DebugLaunchScenario 1 處、Tests 3 處），G-1/G-2/G-3/G-4/G-5 沒有漏掉任何一處，PRD §5/§6/§9 與 `TodoListViewModel`/`TodoListViewController` 既有寫法完全對得上，不需要新型別、新 Combine pipeline、新 async 邊界或新注入點。

### 結構
| 型別 | 角色 | Input / Output 或 API | 檔案位置 |
|------|------|------------------------|----------|
| `CompletedListViewModel.State`（既有 enum，改形狀） | Output：UI 綁定的狀態 | `case content(rows: [Row], countText: String)`（新增 `countText`，比照 `TodoListViewModel.State`） | `TodoList/TodoList/ViewModels/CompletedListViewModel.swift` |
| `CompletedListViewModel.makeState`（既有 static func，改內容） | 純函式：`[TodoItem]` → `State` | 結尾改為 `rows.isEmpty ? .empty : .content(rows: rows, countText: "共完成 \(rows.count) 件")` | 同上 |
| `CompletedListViewController`（既有 VC，改 layout + render） | View：綁定 `$state` → render | 新增 `countLabel`；`titleLabel` + `countLabel` 併入垂直 `headerStack`（比照 `TodoListViewController` 第 143-145 行）；`render(.content(rows, countText))` 設定文字並顯示，`render(.empty)` 隱藏 | `TodoList/TodoList/Views/CompletedListViewController.swift` |

不新增任何型別（沒有新 struct/class/protocol）。

### 資料流
`store.itemsPublisher`（既有，不變）→ `CompletedListViewModel.viewDidLoad` 的 `.map(makeState).removeDuplicates().assign(to: &$state)`（既有 pipeline，不變）→ `makeState` 多算一個 `countText: String`（唯一新增的計算）→ `CompletedListViewController.bindViewModel` 既有的 `viewModel.$state.sink { render($0) }`（不變）→ `render(_:)` 在 `.content` case 多設定一行 `countLabel.text` / `isHidden = false`。

### 注入點
沒有新的注入點。`CompletedListViewModel.init(store:dateFormatter:bannerDuration:)`、`CompletedListViewController.init(viewModel:)` 都不變；`countText` 是 `makeState` 內部算出的純字串，不是外部依賴，不需要注入 formatter 或 protocol。測試沿用既有 `MockTodoStore` + `makeItem` + `drainTasks()`，不需要新增測試替身。

### 原則
- **MVVM Input/Output**：狀態改變只發生在 `State` 這個既有 enum 的 associated value（加一個 `countText: String`），不新增 `@Published` 屬性、不新增 State case。`countText` 在 `makeState`（ViewModel 內部純函式）產生，VC 只負責顯示，符合「ViewController 不含商業邏輯」。
- **Combine 不變**：`store.itemsPublisher → $state → render` 是既有唯一的資料流，完成/刪除任務都會自動觸發重算（FR-3），不需要新 publisher、不需要 `combineLatest`（`CompletedListViewModel` 不像 `TodoListViewModel` 有 `recentlyAddedId` 這種第二個輸入源）。
- **async/await 不變**：`didConfirmDelete()` 既有的 `Task { try await store.delete(id:) }` 不受影響；`countText` 是同步字串運算，不涉及非同步邊界。
- **KISS / 不抽象**：`countText` 直接是 `makeState` 回傳值的一部分，不建立獨立的 `CountFormatter` 或 protocol；`headerStack` 直接在 `setUpViews()` 內組裝，不抽 `HeaderView` 元件（PRD §9 明確決定不抽，CLAUDE.md「No abstractions for single-use code」）。
- **Surgical**：`Row`、`bannerMessage`、`pendingDelete`、`errorMessage`、delete 流程一律不動；只改 `State` 的 `.content` associated value 與所有跟著它編譯失敗的 pattern match 呼叫端。

### 拒絕的方案
- **抽共用 `HeaderStackView`／`CountTextFormatting` protocol**：目前只有兩個呼叫端（待辦頁、已完成頁），文案格式不同（「還有 N 件事，從一件開始。」vs「共完成 N 件」），抽出來只是把兩行字串組裝換成一層間接，沒有實際重用價值。PRD §9 與 CLAUDE.md 都明確拒絕。
- **在 Model / Store 層算 count**：`TodoItem`、`TodoStoring`、`FileTodoStore` 是 PRD §8 明確排除的範圍；且 count 只是 UI 文案，放在 ViewModel 的 `makeState` 里比在 Store 多一層 API 更單純，不需要 Store 額外提供 `completedCount`。
- **為 `countText` 新增獨立 `@Published` 屬性**：會讓 `.empty`/`.content` 兩個 case 與 count 顯示與否的邏輯分散在兩個 property 裡，VC 要自己組合「state 是 content 且 count > 0」的條件；現有 enum associated value 已經用型別把「empty 時不該有 countText」表達出來，不需要額外狀態同步。

---

## Client/Backend Responsibility Analysis

| Req | 內容 | 負責 | 說明 |
|-----|------|------|------|
| FR-1 | 顯示「共完成 N 件」 | App | ViewModel 從本機 store 的 items 計算 |
| FR-2 | N = 0 隱藏 | App | client UI state |
| FR-3 | 即時更新 | App | 本機 `itemsPublisher`（`FileTodoStore` JSON） |
| FR-4 | 文案由 ViewModel 產生 | App | MVVM Output |
| — | 伺服器計數 | BE — N/A | 專案沒有 backend，只有本機持久化（G-9） |

沒有歸屬不確定的項目。

## Implementation Phases

| Phase | 內容 | Gap rows | 驗證 |
|-------|------|----------|------|
| P0 | 確認可以直接沿用（不改程式） | G-7、G-8、G-9（N/A）、G-10 | 閱讀確認；FR-3 行為由 P1 的 AC-4 / AS-06 測試涵蓋 |
| P1 | ViewModel ＋ 測試（TDD）＋ 非 VC 的編譯必要呼叫端：先寫 / 改測試（G-6、G-5）→ 改 `State` / `makeState`（G-1）→ VM 內部 pattern（G-2）→ DEBUG hook pattern（G-4） | G-1、G-2、G-4、G-5、G-6 | Red：測試因 `countText` 不存在而無法編譯 / 失敗。Green 必須等 P2 的 VC `render` 也改好，app target 才能編譯，所以 **P1 與 P2 要連續做完再跑一次測試** |
| P2 | View：`countLabel` ＋ `headerStack` ＋ constraint ＋ `render` | G-3 | `ios-build build` 通過 → `CompletedListViewModelTests` 全數通過（AC-1~AC-6）→ simulator 截圖（見 Test Plan） |

每個 gap row（G-1 ~ G-10）只出現在一個 phase。

## Acceptance Criteria

沿用 PRD §6 AC-1 ~ AC-6（情境與前置條件見 `requirement-spec.md` §6 AS-01 ~ AS-07），外加以下已決定事項（PRD §9）：
- 文案固定為「共完成 N 件」（用「件」）。
- N = 0 不顯示數量文字，只顯示既有空狀態「尚未有已完成的任務」。
- 不做 VoiceOver 主動播報；`countLabel` 是一般 label，依閱讀順序朗讀。
- 不抽共用 header 元件；樣式與待辦頁 `countLabel` 相同（PRD §5）。
- 刪除失敗時數量不變（既有 SID-2 行為，SV-07 回歸）。

## Test Plan

| 類型 | 項目 | 指令 / 證據 |
|------|------|-------------|
| Unit — ViewModel | AC-1（新）、AC-2（新）、AC-3（延伸 `testNoCompletedItemsShowsEmptyState`）、AC-4（新）、AC-5（延伸 `testDeleteLastItemShowsEmptyState`）、AS-06（`testNewlyCompletedItemAppears` 斷言 countText）、AC-6（既有測試 pattern 更新後全數通過） | 目標：`-only-testing:TodoListTests/CompletedListViewModelTests`（見下方說明） |
| Build | 全部變更（含 G-4 DEBUG hook） | `ios-build build` |
| Screenshot | AC-2（「共完成 3 件」）、AC-3（空狀態沒有數量）、AC-4（3 → 2 即時更新 ＋ banner） | 見 Delivery Quality Plan |

**測試慣例**
- 所有建立 `CompletedListViewModel`（或 `TodoListViewModel`）的測試方法都要宣告為 `async`（避免 iOS 26.3 simulator 在 XCTest 同步方法中釋放 MainActor 物件時，於 `swift_task_deinitOnExecutor` 崩潰）。
- 沿用 `MockTodoStore`、`makeItem`、`drainTasks()`；刪除流程是 `didTapDelete(id:)` → `didConfirmDelete()` → `await drainTasks()`。

**測試範圍限定**
- `ios-build help` 的說明只有 `ios-build test`（"run unit tests; prints pass/fail counts and each failure"），**沒有記載 `-only-testing` 或其他 scoping 參數**；launch args 的 `--` 語法只記載在 `run` / `screenshot`。
- 建議做法（由 parent 決定）：
  1. 先試 `ios-build test -- -only-testing:TodoListTests/CompletedListViewModelTests`，看輸出的測試數量是否只包含這個 class（`.build/last-test.log` 可以確認）。
  2. 如果不支援，就跑完整的 `ios-build test`。這是 PRD 要求的超集合，一樣能證明 AC-6；只是比較花時間，並在 handoff 註明「沒有辦法限定範圍，改跑全部」。
  - 不建議為了限定範圍，直接用 shell 變數或 `$(...)` 呼叫 `xcodebuild`（`ios-build` 本來就是為了避開這類無人值守時無法核准的指令）。

## Delivery Quality Plan

- **Traceability**：FR-1 ~ FR-4、NFR-1 ~ NFR-2 → AC-1 ~ AC-6 → AS-01 ~ AS-07 → SV-01 ~ SV-08 → G-1 ~ G-10 → P0 ~ P2。Handoff 以 AC 為單位列出 PASS / BLOCKED 與證據路徑。
- **UI 截圖策略**（沿用既有 DEBUG launch args，**不新增 hook**；輸出到 `RefDoc_Temp/SID-3/validation/`）：

| AC / SV | 指令 | 預期畫面 |
|---------|------|----------|
| AC-2 / SV-03 | `ios-build screenshot RefDoc_Temp/SID-3/validation/AC-2-completed-count.png -- -UI_SCENARIO content -UI_TAB completed` | 標題「已完成」下方顯示「共完成 3 件」，樣式與待辦頁數量文字相同 |
| AC-3 / SV-01 | `ios-build screenshot RefDoc_Temp/SID-3/validation/AC-3-completed-empty.png -- -UI_SCENARIO empty -UI_TAB completed` | 只有「尚未有已完成的任務」，沒有數量文字，header 沒有多出空白 |
| AC-4 / SV-04 | `ios-build screenshot RefDoc_Temp/SID-3/validation/AC-4-completed-after-delete.png -- -UI_SCENARIO content -UI_TAB completed -UI_DELETE success` | 「共完成 2 件」＋「任務已刪除」banner（刪除約在 1.3 秒時完成，banner 持續 3 秒，3 秒截圖時仍會看到） |
| NFR-1 參考 | `ios-build screenshot RefDoc_Temp/SID-3/validation/regression-todo-count.png -- -UI_SCENARIO content` | 待辦頁「還有 3 件事，從一件開始。」— 用來比對兩頁樣式一致，並確認待辦頁沒有被影響 |

  - AC-1（N = 1）與 AC-5（1 → 0）沒有現成 seed，只用 unit test 驗證；AC-5 的最終畫面與 AC-3 截圖相同。
- **測試策略**：P1 依 `/test-driven-development` 先寫 failing test（AC-1、AC-2、AC-4 新增；AC-3、AC-5 延伸）；P1 + P2 完成後跑一次 `CompletedListViewModelTests`（或完整 suite，見 Test Plan）。
- **已知 blocker / 風險**：
  - 沒有 Figma 工具 → Visual Spec Asset Gate 記為 `N/A — no Figma tool available`；PRD §5 已完整指定樣式，不列為 blocker。
  - `ios-build test` 沒有文件記載的 scoping 參數 → 依 Test Plan 的做法處理，不列為 blocker。
  - PRD 影響範圍漏列 `DebugLaunchScenario.swift` → 已納入 G-4。
  - 沒有 UI test target → 畫面以截圖證明。
- **Learning entries used**：無（`.claude/evaluation/agent-learning-log.md` 沒有 entry）。可能的 learning candidate（由 handoff 決定是否記錄）：「修改 enum associated value 的形狀時，要 grep 所有 pattern match 呼叫端，包含 `#if DEBUG` 的截圖 hook，不要只相信 PRD 的影響範圍清單。」
