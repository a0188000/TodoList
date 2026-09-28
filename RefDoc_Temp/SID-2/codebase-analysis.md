# Todo 刪除功能 - Codebase Analysis

> 掃描範圍：`TodoList/TodoList/`、`TodoList/TodoListTests/`、`TodoList.xcodeproj/project.pbxproj`（build settings）、`CLAUDE.md`、`RefDoc_Temp/SID-1_handoff.md`。
> 限制：Swift + Combine、Swift concurrency、MVVM（Input 為 ViewModel method、Output 為 `@Published` / `PassthroughSubject`）。
> Build settings：`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`、`SWIFT_APPROACHABLE_CONCURRENCY = YES`、Swift 5 mode、iOS 26.2 → app target 內型別預設 MainActor（store / ViewModel / VC 皆同一 actor）。

## 現有能力

### Model
- `Models/TodoItem.swift`：`struct TodoItem: Codable, Equatable, Identifiable { let id: UUID; let title; var isCompleted; let createdAt; var completedAt: Date? }`。唯一 id 已存在，足以滿足「依 id 刪除、同名不誤刪」。

### Store
- `Services/TodoStoring.swift`（protocol）：`itemsPublisher`（全部 items，subscribe 即收到目前值）、`addedItemPublisher`、`loadAll() async throws`、`add(title:) async throws`、`markCompleted(id:) async throws`。契約：**成功保存後才更新 `itemsPublisher`；失敗時資料不變並拋錯**。無 delete API。
- `Services/FileTodoStore.swift`：`@Published private(set) var items`；每次 mutation 以 `newItems` 呼叫 `save(_:)`（`JSONEncoder` + `Data.write(options: .atomic)`）成功後才指派 `items`。`markCompleted(id:)` 對找不到的 id 靜默 return（可作為 delete not-found 的既有 pattern 參考）。
- 單一 shared store 由 `SceneDelegate` 建立並注入 `TodoListViewModel`、`CompletedListViewModel`（及 AddTodoViewModel）→ 任一分頁刪除後，兩個分頁都經由 `itemsPublisher` 自動重算。

### ViewModel
- `ViewModels/TodoListViewModel.swift`
  - Output：`@Published state: State`（`.empty` / `.content(rows:countText:)`，countText＝「還有 N 件事，從一件開始。」，N＝未完成數）、`@Published isAddedBannerVisible`、`completionErrorMessage: PassthroughSubject<String, Never>`。
  - Input：`viewDidLoad()`、`didTapCircle(id:)`、`makeAddTodoViewModel()`。
  - 既有 pattern：`completingIds: Set<UUID>` 防重複（對應 DEL-08 可沿用）；`Task { do { try await store... } catch { errorSubject.send("…失敗，請再試一次") } }`；banner 以 `bannerTask` + `Task.sleep(for: bannerDuration)`（預設 3 秒，可注入）控制並可 cancel；`recentlyAddedId` 與 banner 綁在一起（「任務已新增」專用）。
  - `Row` 含 `id`、`title` → dialog title 可直接由 row 取得。
- `ViewModels/CompletedListViewModel.swift`
  - Output：只有 `@Published state`（`.empty` / `.content(rows:)`），**無數量、無回饋、無錯誤 output**。
  - Input：只有 `viewDidLoad()`。
  - `Row` 含 `id`、`title`、`completedText`。

### View
- `Views/TodoListViewController.swift`：`tableView.dataSource = self`，**未設定 `delegate`**（swipe actions 需 `UITableViewDelegate`）；`render(_:)` 以 `tableView.reloadData()` 整表重繪（無逐列刪除動畫）；`countLabel` 在 `.empty` 隱藏；banner（`bannerView` + `bannerLabel`）文字寫死「任務已新增」，位置在「新增任務」按鈕上方，顯示時發 VoiceOver announcement；`showError(_:)` 以 `UIAlertController(title: message, …)` + 「好」，並在 `presentedViewController != nil` 時略過。
- `Views/CompletedListViewController.swift`：同樣只設 `dataSource`、`reloadData()`；無 banner、無錯誤 alert、無底部按鈕（table 延伸到 `view.bottomAnchor`）。
- `Views/TodoRowCell.swift`：`onTapCircle` closure、`prepareForReuse` 清空；`CompletedRowCell.swift`：`isAccessibilityElement = true` 整列單一 a11y element。兩者皆 `selectionStyle = .none`，`tableView.allowsSelection = false`。刪除不需改 cell 本身（swipe actions 由 table delegate 提供）。

### DEBUG / 驗證
- `Support/DebugLaunchScenario.swift`（`#if DEBUG`）：launch args `-UI_SCENARIO <empty|content|many>`、`-UI_TAB completed`、`-UI_ADD <open|success>`；`makeStore()` 在暫存目錄寫入 seed JSON；`apply(...)` 延遲 500ms 後觸發動作。`content` 資料集＝3 筆待辦 + 3 筆已完成（剛好符合 PRD「3 → 2」示範）。無刪除相關 hook、無強制保存失敗機制。
  - 附註（既有程式、不在本次範圍）：第 41 行 `todoListViewController.presentAddTodo()            case "success":` 兩段寫在同一行，格式異常；若本次修改此 switch 再一併處理，否則僅提醒。
- Tests：`MockTodoStore`（`@MainActor`、`@Published items`、`shouldFail`、各方法呼叫次數、`await Task.yield()` 模擬非同步）、`drainTasks()`、`makeItem(...)`；`FileTodoStoreTests` 以「parent 目錄不存在的 fileURL」製造寫入失敗；`TodoListViewModelTests` 已有 repeated tap / failure pattern 可直接比照。無 UI test target。

## Model Gap Analysis

| ID | 需求 | 現有 Model | 狀態 | 備註 |
|----|------|-----------|------|------|
| G-01 | 依唯一識別碼刪除（DEL-ID、AC-08） | `TodoItem.id: UUID` | 復用 | 無需變更 Model / JSON 格式 |

## Service / API Gap Analysis

| ID | 類型 | 需求 | 現有 Service | 狀態 | 備註（App / BE） |
|----|------|------|-------------|------|------------------|
| G-02 | Modify | 刪除 API 契約（成功保存後才更新 `itemsPublisher`，失敗拋錯且資料不變） | `TodoStoring` | 缺 | App；沿用既有 mutation 契約文字 |
| G-03 | Modify | 刪除實作 + 持久化（DEL-06、DEL-07） | `FileTodoStore` | 缺 | App；沿用「先 save 再指派 items」；not-found 行為需決定（既有 `markCompleted` 為靜默 return） |
| G-04 | BE | 伺服器端刪除 | 無 backend | N/A | 本機 JSON 儲存，無 API / BE 工作 |

## ViewModel Gap Analysis

| ID | 類型 | 需求 | 現有 | 狀態 | 變更內容 |
|----|------|------|------|------|----------|
| G-05 | Modify | 待辦：請求刪除 → dialog 內容（title＝row title、待辦文案）→ 取消 / 確認；防重複；成功回饋；失敗訊息 | `TodoListViewModel` | 部分可復用 | 新 Input（刪除請求 / 確認）；in-flight guard 比照 `completingIds`；成功回饋需與既有「任務已新增」banner 整合（目前 `isAddedBannerVisible` 與 `recentlyAddedId` 皆為新增專用，見 OQ-01）；失敗訊息 output（既有 `completionErrorMessage` 名稱為完成專用，是否共用由架構決定） |
| G-06 | Modify | 已完成：同 G-05，文案為已完成版本；不影響待辦 | `CompletedListViewModel` | 缺 | 新增刪除 Input、in-flight guard、成功回饋 output（OQ-02）、錯誤 output；目前完全沒有這些 output |

## UI Gap Analysis

| ID | 類型 | 畫面 | 現有元件 | 狀態 | 變更內容 |
|----|------|------|---------|------|----------|
| G-07 | Modify | 待辦清單 | `TodoListViewController` | 改版（小） | 設定 table `delegate` 並提供 trailing swipe「刪除」（destructive；full swipe 依 OQ-05）；確認 alert（title / message / 取消 / 紅色確認）；取消後 cell 狀態（OQ-04）；banner 文字由固定「任務已新增」改為依回饋類型；失敗沿用 `showError` |
| G-08 | Modify | 已完成清單 | `CompletedListViewController` | 改版 | 同 G-07 swipe + alert；**新增** 成功回饋元件（無底部按鈕，位置需另定，OQ-01/02）；**新增** 錯誤 alert 綁定 |
| G-09 | 復用 | Cell | `TodoRowCell`、`CompletedRowCell` | 復用 | 無變更（swipe 由 table delegate 提供；UIKit swipe actions 會自動提供 VoiceOver 自訂動作） |
| G-10 | 復用 | 空狀態 / 數量 | 既有 `.empty` render、`countLabel` | 復用 | 刪除最後一筆自動進入既有空狀態；待辦數量由 `makeState` 自動 −1；已完成無數量（OQ-03） |

## Test / DEBUG Gap Analysis

| ID | 類型 | 需求 | 現有 | 狀態 | 變更內容 |
|----|------|------|------|------|----------|
| G-11 | Modify | Mock 支援刪除 | `MockTodoStore` | 缺 | 新增刪除方法、呼叫次數、`shouldFail` 支援（protocol 新增方法後必改，否則 test target 編譯失敗） |
| G-12 | New tests | Store：刪除後重啟不出現（AC-09）、同名只刪一筆（AC-08）、寫入失敗 items 不變（AC-10） | `FileTodoStoreTests` | 缺 | 失敗注入可沿用「parent 目錄不存在」手法（先以有效路徑建立資料，再移除目錄後刪除） |
| G-13 | New tests | ViewModel：dialog 內容、取消不呼叫 store、確認刪除目標、重複確認只一次、成功回饋、失敗不回饋且資料不變、已完成刪除不影響待辦（AC-03~08、AC-10） | `TodoListViewModelTests`、`CompletedListViewModelTests` | 缺 | 比照既有 repeated tap / failure test pattern |
| G-14 | Modify | DEBUG 截圖 hook：確認 dialog、成功結果、失敗結果（兩分頁） | `DebugLaunchScenario` | 缺 | 需新增 launch arg；失敗截圖需可強制保存失敗的 DEBUG-only 手段（目前 `FileTodoStore` 無注入點）；swipe 露出狀態無法由 hook 呈現（OQ-08） |

## 待處理項目（職責、依賴、風險）

- **職責**：全部 App 負責；無 BE（G-04）。
- **依賴順序**：G-02/G-03 → G-11（Mock 需跟上 protocol）→ G-05/G-06 → G-07/G-08 → G-14；tests（G-12/G-13）隨各層進行。
- **風險 1 — 回饋耦合**：待辦 banner 的顯示狀態與「剛剛新增」標示共用 `recentlyAddedId` / `bannerTask`；加入刪除回饋時需避免刪除回饋誤觸發「剛剛新增」標示，或新增回饋被刪除回饋取消後殘留標示（預設行為見 OQ-01）。
- **風險 2 — reloadData 與 swipe 狀態**：`render` 每次 state 改變都 `reloadData()`；刪除成功時整表重繪即滿足「其餘列上移」，但無逐列動畫（OQ-07 預設不強制）。取消時 state 不變（`removeDuplicates`），不會觸發 reload，有利於 OQ-04 的「保持露出」預設。
- **風險 3 — 錯誤 alert 被略過**：`showError` 在 `presentedViewController != nil` 時直接 return；刪除失敗時需確保確認 alert 已 dismiss，否則失敗回饋可能不顯示（AC-10）。
- **風險 4 — 驗證證據**：無 UI test target，左滑 / 收合（AC-01、AC-02）只能以 VC 層 unit test + 手動截圖佐證（OQ-08）。
- **不變項**：`TodoItem` / JSON 格式、`AddTodo*`、`CompletionDateFormatter`、cell 類別、SceneDelegate 注入方式皆不需變更（DEBUG hook 若需新參數除外）。

---

## Architecture Decisions

### AD-01 Store API 形狀
- `TodoStoring` 新增 `func delete(id: UUID) async throws`。
- 語意比照 `markCompleted`：先組出移除目標後的 `newItems` → `try save(newItems)` 成功後才指派 `items`；保存失敗時 `items` 不變並拋錯（沿用既有 mutation 契約，同意 G-02）。
- id 不存在：靜默 return、不 throw，比照 `markCompleted` 既有 pattern（同意 G-03，不另立規則）。
- 曝光方式：兩個 ViewModel 已共用同一個 `store: TodoStoring` instance（`SceneDelegate` 注入），`delete` 直接加進同一 protocol 即可讓兩邊呼叫，無需新增介面或第二個 store 參考。

### AD-02 ViewModel Input/Output
- Output 新增 `@Published private(set) var pendingDelete: PendingDelete?`；`struct PendingDelete: Equatable { let id: UUID; let title: String; let message: String }`。`title` 由目前 `state` 的 rows 依 id 查出，`message` 為分頁專屬常數字串（待辦 / 已完成兩種文案，§3.3）。
- Input 新增：`didTapDelete(id: UUID)`（查 row title、設定 `pendingDelete`）、`didConfirmDelete()`（無參數，作用於目前 `pendingDelete`）、`didCancelDelete()`（無參數，`pendingDelete = nil`）。兩個 VM 形狀一致。
- **Dialog 狀態放在 ViewModel，不放 VC-only 的 `UIAlertController`**：AC-03／AC-04 明確要求「ViewModel unit test 驗證 dialog 內容、取消不呼叫 store」，狀態必須是可觀察、可斷言的 VM output 才能被 XCTest 覆蓋；VC 只依 `pendingDelete` render／dismiss alert，不持有商業邏輯。這是滿足既有測試策略下最簡單的選擇。
- In-flight guard：**不**比照 `completingIds: Set<UUID>`（見「與既有 Gap Analysis 的差異」）。`didConfirmDelete()` 一開始就同步 `guard let pending = pendingDelete else { return }; pendingDelete = nil`，再開 `Task` 呼叫 `store.delete`。因為同一時間只會存在一個 dialog／一個 pendingDelete slot，單一 optional 的同步清空已足夠擋掉重複確認（AC-05），比額外維護一個 Set 更簡單。
- 成功／失敗 output 見 AD-03。

### AD-03 Feedback banner 共存（採納 OQ-01、OQ-02 預設）
- **TodoListViewModel**：保留既有 `isAddedBannerVisible`、`bannerTask`、`recentlyAddedId`，新增 `@Published private(set) var bannerText: String = "任務已新增"`。既有 `showAddedFeedback(for:)` 廣義化為 `showBanner(text: String, recentlyAddedId: UUID? = nil)`：新增流程呼叫 `showBanner(text: "任務已新增", recentlyAddedId: item.id)`；刪除成功呼叫 `showBanner(text: "任務已刪除")`（`recentlyAddedId` 預設 nil，會取消／取代正在顯示的「新增」banner，即 OQ-01「新回饋取代正在顯示的回饋」）。VC 端把原本寫死的 `bannerLabel.text = "任務已新增"` 改成 bind `$bannerText`。
- **CompletedListViewModel**：目前完全沒有 banner，新增 `@Published private(set) var bannerMessage: String?`（nil＝隱藏，非 nil＝顯示該文字）＋比照的 `bannerTask` 計時器（`bannerDuration: Duration = .seconds(3)` 建構子參數，比照 TodoListViewModel 以利測試）。只有刪除會觸發，不需要「剛剛新增」概念，因此用單一 optional String 就夠，不必為了跟待辦頁「形狀一致」而多拆一個 `isXxxVisible` 屬性。
- **錯誤 output**：既有 `completionErrorMessage: PassthroughSubject<String, Never>` 更名為 `errorMessage`，標記完成失敗與刪除失敗共用同一顆 subject（訊息文字已由呼叫端字串參數化，VC binding 邏輯不變，只是換名字＋多一個呼叫點）。這是刻意觸碰既有程式碼：另開一顆幾乎相同用途的 subject 是重複，違反 Simplicity First。`CompletedListViewModel` 新增同名 `errorMessage: PassthroughSubject<String, Never>`（目前完全沒有錯誤 output）。

### AD-04 VC：swipe / alert / 失敗順序
- 兩個 VC 新增 `UITableViewDelegate` 並設定 `tableView.delegate = self`；實作 `tableView(_:trailingSwipeActionsConfigurationForRowAt:)`，回傳單一 `UIContextualAction(style: .destructive, title: "刪除")` 組成的 `UISwipeActionsConfiguration`，並設 `performsFirstActionWithFullSwipe = false`（採納 OQ-05）。
- Action handler 呼叫 `viewModel.didTapDelete(id:)` 後一律 `completion(false)`（不是 `completion(true)`）：實際刪除發生在確認 dialog 之後，這裡只是開 dialog，`completion(false)` 讓該列維持露出「刪除」；取消後列自然保持露出——**直接等於 OQ-04 建議的預設「依原型保持露出」，不是退而求其次的 fallback**。確認成功後 state 改變觸發 `reloadData()`，該列直接消失，swipe 是否收合已無意義。
- **RD 決議覆寫（Spec Review Round 1）**：OQ-04 改為「取消後收合」。實作方式：VC 在 `pendingDelete` 變回 nil 時呼叫 `tableView.setEditing(false, animated: true)` 收起 swipe 狀態（取消與確認皆適用）。
- Alert 呈現改為**反應式**（訂閱驅動，非一次性事件）：VC 訂閱 `viewModel.$pendingDelete`；變非 nil 且 `presentedViewController == nil` 時 present 確認 alert，並以 `weak var deleteConfirmAlert` 記住這顆 alert；變回 nil 時，若目前呈現的正是它，主動 `dismiss(animated:)`。alert 的「取消」「確認」action 只呼叫對應 VM input，不在 closure 內自行 dismiss。
- 好處：`didConfirmDelete()`（AD-02）一進入就同步把 `pendingDelete` 設 nil，VC 立刻反應式收起 confirm alert，不必等 `UIAlertController` 自己的 dismiss 動畫跑完——解決 codebase-analysis「風險 3」：確認 alert 尚未真正 dismiss、導致失敗 alert 被 `showError` 的 `presentedViewController != nil` guard 擋掉（直接違反 AC-10）。
- 防禦性補強：`showError`（兩個 VC 都需要，Completed 目前沒有、需新增）從「`presentedViewController != nil` 時直接 return（略過）」改為「若目前有呈現中的 alert，先 `dismiss(animated: false)` 再 present 新的」，作為上面反應式 dismiss 之外的第二層保險。這是必要修正，不是順手重構。
- Completed 頁的 `showError` 為獨立 6 行小函式，不與待辦頁抽共用 base class／protocol（兩處都很短，抽象化不值得）。

### AD-05 DEBUG 截圖 hook
- 新 launch arg `-UI_DELETE <open|success|failure>`（比照既有 `-UI_ADD` 命名風格）。
- `DebugLaunchScenario.apply(...)` 需能操作兩個分頁的 ViewModel（目前只收 `todoListViewController`），簽章擴充為同時接收 `todoListViewModel` 與 `completedListViewModel`，由 `SceneDelegate`（本來就持有這兩個 VM）多傳兩個參數。
- `open`：切到目標分頁後，取該分頁目前 state 第一筆 row 的 id，呼叫對應 VM 的 `didTapDelete(id:)` → VC 反應式呈現真的 `UIAlertController`，截圖驗證 AC-03。
- `success`：`didTapDelete(id:)` 後緊接呼叫 `didConfirmDelete()`（用正常可寫入的 store）→ 依 AD-04 的反應式 dismiss，confirm alert 會自動收起不擋畫面；store 完成後截圖驗證 AC-06／AC-07（banner ＋ 清單更新）。
- `failure`：`makeStore()` 回傳型別由具體的 `FileTodoStore` 改成 protocol `TodoStoring`；新增 `#if DEBUG` only 的 decorator `FailingDeleteTodoStore: TodoStoring`，包一個真的 `FileTodoStore`——`itemsPublisher`／`addedItemPublisher`／`loadAll`／`add`／`markCompleted` 都轉呼叫底層 store，`delete(id:)` 永遠 throw、不觸碰底層資料。`-UI_DELETE failure` 用這個 decorator 建 store，流程同 `success`，截圖驗證 AC-10（兩分頁各跑一次，靠既有 `-UI_TAB`）。
- 左滑露出／收合本身（AC-01／AC-02）沿用 OQ-08 既有結論：hook 不處理，靠 VC 層 unit test（AD-06）＋ 手動截圖佐證。

### AD-06 測試策略
| 檔案 | 新增測試重點 |
|------|--------------|
| `MockTodoStore.swift` | 新增 `delete(id:)`（`deleteCallCount`、`shouldFail` 支援、找不到 id 靜默略過），比照 `markCompleted` 寫法；protocol 新增方法後此檔必改，否則 test target 編譯失敗（同意 G-11） |
| `FileTodoStoreTests.swift` | 刪除後重啟（新 instance `loadAll()`）不含該 id（AC-09）；同 title 兩筆刪其一、另一筆保留（AC-08）；既有「parent 目錄不存在」失敗注入手法驗證寫入失敗時 items 不變並拋錯（AC-10）；刪除不存在 id 不拋錯、資料不變 |
| `TodoListViewModelTests.swift` | `didTapDelete` 設定正確 `pendingDelete`（title／message）且未呼叫 `store.delete`（AC-03）；`didCancelDelete` 後 state／`pendingDelete`／store 呼叫次數不變（AC-04）；`didConfirmDelete` 只刪目標 row、`countText` 更新、`pendingDelete` 清空、`bannerText`／`isAddedBannerVisible` 顯示「任務已刪除」（AC-05／06）；不重新 `didTapDelete` 而重複呼叫 `didConfirmDelete()` 只送出一次刪除（AC-05 guard）；`shouldFail` 時資料／數量不變、無成功 banner、`errorMessage` 送出「刪除失敗，請再試一次」（AC-10）；刪到剩 0 筆進入 `.empty`（SV-08） |
| `CompletedListViewModelTests.swift` | 同上四類（dialog／cancel／confirm 成功／失敗）；額外以同一個 `MockTodoStore` 建立 `TodoListViewModel` 與 `CompletedListViewModel`，在 Completed 端刪除後驗證 `TodoListViewModel.state` 與待辦數量不受影響（AC-07 跨 VM 隔離） |
| VC 層新測試檔（若尚無則新增，比照 spec 要求的「VC 層 unit test」） | `trailingSwipeActionsConfigurationForRowAt` 回傳恰好一個 destructive、title「刪除」的 action，且 `performsFirstActionWithFullSwipe == false`（AC-01）；不驗證實際滑動手勢，交給 OQ-08 的手動截圖 |

### 與既有 Gap Analysis / Open Questions 的差異
- **不同意** G-05／G-06 中「in-flight guard 比照 `completingIds`」的建議：改用單一 `pendingDelete` optional 的同步清空即可達成同樣效果（見 AD-02）。理由：`completingIds` 是為了同時允許對多個不同 id 標記完成而設計的集合；刪除同一時間只會有一個 dialog／一個 pendingDelete，Set 對這個場景是多餘的複雜度。
- 其餘 G-01～G-04、G-07～G-14 與 OQ-01～OQ-08 的建議預設值皆同意採納，無異議；OQ-04 的實作方式（swipe action `completion(false)`）讓「保持露出」直接成立，而非退而求其次的 fallback。

---

## Client/Backend Responsibility Analysis

| Req | 內容 | 負責 | 說明 |
|-----|------|------|------|
| DEL-01 | 左滑露出刪除 | App | UI（table swipe actions） |
| DEL-02 / DEL-03 | 確認 dialog 與文案 | App | ViewModel output + VC alert |
| DEL-04 | 取消不變更 | App | client UI state |
| DEL-05 | 刪除 + 清單 / 數量 / 回饋 | App | 本機 store + ViewModel |
| DEL-06 | 持久化 | App | 本機 JSON（`FileTodoStore`）；無 backend |
| DEL-07 | 失敗處理 | App | 本機寫檔失敗 |
| DEL-08 | 防重複確認 | App | ViewModel guard |
| DEL-ID | 依 id 刪除 | App | `TodoItem.id` |
| — | 伺服器刪除 | BE — N/A | 專案無 backend（G-04） |

無不確定歸屬項目。

## Implementation Phases

| Phase | 內容 | Gap rows | 驗證 |
|-------|------|----------|------|
| P0 | 確認可直接沿用（無程式變更） | G-01、G-04（N/A）、G-09、G-10 | 閱讀確認 / 既有 empty & count 行為由 P2 tests 覆蓋 |
| P1 | Store：`TodoStoring.delete(id:)` + `FileTodoStore` 實作 + `MockTodoStore` 同步 + store tests | G-02、G-03、G-11、G-12 | `FileTodoStoreTests`（AC-08 / 09 / 10） |
| P2 | ViewModel：兩個 VM 的 `pendingDelete` / 三個 Input / banner / `errorMessage` + VM tests（TDD） | G-05、G-06、G-13 | `TodoListViewModelTests`、`CompletedListViewModelTests`（AC-03~08、10） |
| P3 | View：兩個 VC 的 delegate + swipe action + 反應式確認 alert + banner 文字 binding + 已完成頁 banner / error alert + VC swipe config test | G-07、G-08 | VC 層 unit test（AC-01）+ build |
| P4 | DEBUG hook：`-UI_DELETE <open\|success\|failure>`、`FailingDeleteTodoStore` | G-14 | `ios-build screenshot`（AC-03、06、07、10） |

每個 gap row（G-01～G-14）恰出現在一個 phase。

## Acceptance Criteria

沿用 PRD §5 AC-01～AC-10（Given/When/Then 見 `requirement-spec.md` §6），外加 spec 預設值：
- OQ-01 / OQ-02：兩分頁成功後皆顯示「任務已刪除」banner（約 3 秒），取代顯示中的「任務已新增」。
- OQ-03：已完成頁不新增數量 / 摘要。
- OQ-04 / OQ-05（RD 決議）：取消後該列「刪除」收合；關閉 full swipe，一律點擊按鈕觸發。
- OQ-06：失敗以系統 alert「刪除失敗，請再試一次」+「好」呈現。
- OQ-07：系統 destructive swipe action + 系統 alert（確認為 destructive style）。

## Test Plan

| 類型 | 項目 | 指令 / 證據 |
|------|------|-------------|
| Unit — Store | AC-08、AC-09、AC-10、not-found 不拋錯 | `ios-build test` |
| Unit — ViewModel | AC-03、04、05（含重複確認）、06、07（跨 VM 隔離）、08、10、刪到空 | `ios-build test` |
| Unit — VC | AC-01 swipe configuration（單一 destructive「刪除」、`performsFirstActionWithFullSwipe == false`） | `ios-build test` |
| Screenshot | AC-03（兩分頁 dialog）、AC-06（待辦 3→2 + banner）、AC-07（已完成刪除 + banner）、AC-10（兩分頁失敗 alert） | `ios-build screenshot RefDoc_Temp/SID-2/validation/<AC-id>.png -- -UI_SCENARIO content [-UI_TAB completed] -UI_DELETE <open\|success\|failure>` |
| Manual（RD） | AC-01 / AC-02 實際左滑與收合、AC-09 實機重開 | 標示於 handoff（OQ-08） |
| Build | 全部變更 | `ios-build build` |

## Delivery Quality Plan

- **Traceability**：DEL-01～08、DEL-ID → AC-01～10 → SV-01～22 → G-01～14 → P0～P4；handoff 以 AC 為單位列出 PASS / BLOCKED 與證據路徑。
- **UI / state 驗證策略**：可由 DEBUG hook 到達的狀態（dialog、成功、失敗、空狀態）截圖；swipe 手勢本身無法自動化 → VC 層 unit test + `BLOCKED-by-test-harness`（手動補證）。
- **測試策略**：P1 / P2 依 `/test-driven-development` 先寫 failing test；沿用 `MockTodoStore` + `drainTasks()` pattern。
- **已知 blocker 前置**：無 Figma 工具 → 視覺細節採系統元件（OQ-07），不列為 blocker；無 UI test target（OQ-08）。
- **Learning entries used**：`.claude/evaluation/agent-learning-log.md` 目前無 entry；learning candidate：「專案 learning log 實際路徑為 `.claude/evaluation/agent-learning-log.md`（非 `docs/`）」於 handoff 列出。
