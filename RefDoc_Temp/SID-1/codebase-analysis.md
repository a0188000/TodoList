# 新增 TODO List - Codebase Analysis

> Ticket：SID-1 ｜ 對應 spec：`RefDoc_Temp/SID-1/requirement-spec.md`
> 掃描範圍：`TodoList/TodoList/`、`TodoList/TodoList.xcodeproj/project.pbxproj`、`CLAUDE.md`

## 現有能力

### 專案現況
專案為 Xcode 26.2 產生的 **UIKit 空白 template**，尚無任何業務程式碼。

| 檔案 | 現況 |
|------|------|
| `TodoList/TodoList/AppDelegate.swift` | template 預設，無自訂邏輯 |
| `TodoList/TodoList/SceneDelegate.swift` | template 預設；`scene(_:willConnectTo:options:)` 只做 `guard let _ = scene as? UIWindowScene`，window 由 storyboard 建立 |
| `TodoList/TodoList/ViewController.swift` | 空的 `ViewController: UIViewController`（只有 `viewDidLoad`） |
| `TodoList/TodoList/Base.lproj/Main.storyboard` | 單一 scene，`initialViewController` = `ViewController`；無 Tab Bar / Navigation Controller |
| `TodoList/TodoList/Base.lproj/LaunchScreen.storyboard` | template 預設 |
| `TodoList/TodoList/Info.plist` | `UISceneStoryboardFile` = Main；未設定 `UIUserInterfaceStyle` |
| `TodoList/TodoList/Assets.xcassets` | 僅 AppIcon、AccentColor |

### 關鍵 build settings（`project.pbxproj`）
| 設定 | 值 | 影響 |
|------|----|------|
| `IPHONEOS_DEPLOYMENT_TARGET` | 26.2 | 可使用最新 UIKit API；是否降版見 OQ-07 |
| `SWIFT_VERSION` | 5.0 | Swift 5 language mode |
| `SWIFT_DEFAULT_ACTOR_ISOLATION` | MainActor | 所有型別預設 `@MainActor`；背景 I/O（檔案存取）需明確 `nonisolated` 或其他 isolation |
| `SWIFT_APPROACHABLE_CONCURRENCY` | YES | 符合 CLAUDE.md「使用 Swift concurrency」 |
| `INFOPLIST_KEY_UIMainStoryboardFile` | Main | 若改為程式碼建立 root（Tab Bar），需同步調整 storyboard 入口或 Info.plist / SceneDelegate |
| `fileSystemSynchronizedGroups` | `TodoList` 資料夾 | `TodoList/TodoList/` 下新增的 `.swift` 自動加入 target，**不需改 pbxproj** |
| `developmentRegion` / `knownRegions` | en / en, Base | 無 zh-Hant 本地化設定；PRD 只要求繁體中文，文案可直接使用中文字串（是否建立 Localizable 屬架構決策，非需求） |

### Test target 狀態
- `project.pbxproj` 只有 **1 個 `PBXNativeTarget`（`TodoList`，`com.apple.product-type.application`）**，`targets` 清單只含此一項。
- **不存在 unit test target / UI test target**，無 `*Tests` 資料夾。
- Validation Gate 需要 unit test → 需新增 `TodoListTests` target（修改 pbxproj，見 GAP-13、OQ-12）。

### 可復用元件 / 既有 pattern
- 無任何可復用的 Model、Service、ViewModel、View 元件。
- 無既有命名或資料夾慣例；僅 CLAUDE.md 規範：Swift + Combine only、Swift concurrency、MVVM（Input/Output）、simplicity first。
- 以業務詞（`Todo`、`Task`、`Store`、`ViewModel`、`Repository`、`Persist`）搜尋 `TodoList/TodoList/`：0 筆命中（僅 template 檔）。

---

## Model Gap Analysis

| ID | 需求 | 現有 Model | 狀態 | 備註 |
|----|------|-----------|------|------|
| GAP-01 | 任務資料模型：`id`、`title`、`isCompleted`（預設 false）、`createdAt`、`completedAt?`（REQ-01） | 無 | 全新 | 需可序列化以支援本機持久化；欄位依 PRD p5，不額外新增欄位（如分類） |

## Service / API Gap Analysis

| ID | 需求 | 現有 Service | 狀態 | 備註（App / BE 負責） |
|----|------|-------------|------|----------------------|
| GAP-02 | 本機持久化：讀取全部任務、新增任務、標記完成；成功保存後才回報成功；可回報失敗（REQ-02、REQ-14、REQ-20） | 無 | 全新 | **App 負責**。需可在測試中注入失敗（AC-13、AC-15），且讀寫以 async 方式提供。儲存機制（檔案 JSON / UserDefaults / 其他）由 Step 1.1.5 架構決策，受 CLAUDE.md「Swift + Combine only」限制 |
| GAP-03 | 啟動讀取失敗 / 資料毀損處理（SV-06） | 無 | 待定義 | App 負責；行為待 OQ-11 |
| GAP-04 | 相對日期文字：今天完成 / 昨天完成 / 日期（REQ-22） | 無 | 全新 | App 負責；需可注入「現在時間」與 Calendar 以測試；更早日期格式待 OQ-09 |
| GAP-05 | 後端 API | 無 | **不需要** | **BE-owned：無**。PRD 明示本機儲存、免登入、無雲端同步（p2、p5），本 ticket 無任何 BE 工作 |

## UI Gap Analysis

| ID | 畫面 / 元件 | 現有元件 | 狀態 | 變更內容 |
|----|------------|---------|------|----------|
| GAP-06 | App root：Tab Bar 容器（「待辦」「已完成」，預設待辦，切換保留資料） | Main.storyboard 單一 `ViewController` | 改版 | 將 root 從空 `ViewController` 改為 Tab Bar 容器（REQ-03、REQ-24）；需修改 `SceneDelegate.swift` 及/或 `Main.storyboard` / Info.plist 入口 |
| GAP-07 | 待辦清單畫面 + ViewModel（標題、數量文字、我的清單、任務列、新增入口、空狀態、捲動） | 無（template `ViewController.swift` 為空） | 全新 | REQ-04~08；MVVM Input/Output |
| GAP-08 | 待辦任務列（未勾選圓圈 + 多行名稱 + 「剛剛新增」標示；圓圈觸控 ≥ 44pt、VoiceOver） | 無 | 全新 | REQ-07、REQ-17、REQ-19、REQ-26 |
| GAP-09 | 新增成功回饋：「任務已新增」提示約 3 秒消失、「剛剛新增」僅本次顯示 | 無 | 全新 | REQ-17、REQ-18；提示樣式未知（OQ-08） |
| GAP-10 | 新增任務畫面 + ViewModel（無 Tab Bar；取消 / 新增 / 新增到清單；驗證、trim、100 字、提交中停用、失敗保留輸入、鍵盤避讓） | 無 | 全新 | REQ-09~16 |
| GAP-11 | 已完成畫面 + ViewModel（藍色勾選、灰色刪除線、完成時間、completedAt 新→舊、唯讀、空狀態） | 無 | 全新 | REQ-21~23 |
| GAP-12 | 視覺基準：淺灰背景、白色圓角容器、藍色主要按鈕（54pt）、左右 24pt、Dynamic Type | AccentColor.colorset（template 預設值） | 全新 | REQ-25、REQ-26；精確色值需 Figma（OQ-08）；深色模式待 OQ-07 |
| GAP-13 | 新增 `TodoListTests` unit test target | 無 | 全新（修改 pbxproj） | 供 ViewModel / Store / 日期文字 unit test；需 RD 同意（OQ-12） |
| GAP-14 | 移除或取代 template `ViewController.swift` | `ViewController.swift` | 修改 / 刪除 | 由 GAP-06/07 取代後會成為孤兒，依 CLAUDE.md「清理自己造成的孤兒」處理 |

### Gap 分類彙整
| 類型 | Gap IDs |
|------|---------|
| New files | GAP-01、GAP-02、GAP-04、GAP-07、GAP-08、GAP-09、GAP-10、GAP-11、GAP-12、GAP-13（test target 內新檔案） |
| Modifications | GAP-06（SceneDelegate / Main.storyboard / Info.plist 入口）、GAP-13（project.pbxproj 新增 target）、GAP-14（template ViewController） |
| 待定義 | GAP-03（OQ-11） |
| BE-owned | GAP-05：**無 BE 工作** |

---

## App / Backend 職責判斷

| 需求 | Source of truth | 負責 |
|------|----------------|------|
| 任務資料、完成狀態、完成時間 | 裝置本機儲存 | App |
| 新增 / 完成的成功與失敗判定 | 本機儲存寫入結果 | App |
| 排序、數量、相對日期文字、驗證（trim / 100 字） | Client 計算 | App |
| 帳號、同步、多裝置 | 不在範圍 | — |

無任何需求的 source of truth 在 Server / DB。

---

## 待處理項目（職責待確認、依賴、風險）

1. **Test target 缺失（GAP-13 / OQ-12）**：修改 `project.pbxproj` 風險較高（手改易壞檔）；需 RD 同意並於新增後以 build + test 驗證。
2. **Root 入口切換（GAP-06）**：storyboard 入口與程式碼建立 root 擇一，需在架構決策中明確，避免 `Main.storyboard` 與 `SceneDelegate` 雙重建立 window。
3. **MainActor 預設隔離**：持久化 I/O 若放在背景，需處理 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 的 isolation 標註；本機資料量小，亦可評估是否需要背景化（架構決策）。
4. **失敗可測性**：AC-13 / AC-15 需要能模擬儲存失敗，持久化層需可替換（注入）。
5. **視覺缺口（OQ-08）**：無 Figma 存取，視覺驗收僅能依 PRD p5 文字基準；建議 RD 提供 5 個畫面截圖至 `RefDoc_Temp/SID-1/figma-screenshots/`。
6. **深色模式 / iOS 版本（OQ-07）**：PRD 要求開發前確認；目前 deployment target 26.2。
7. **Open Questions 依賴**：OQ-02（超過 100 字行為）、OQ-04（完成失敗回饋）、OQ-09（日期格式）、OQ-10（N=0 數量文字）、OQ-11（讀取失敗）會影響對應 AC 的最終斷言。

---

## Architecture Decisions

### 判斷
單一 shared `TodoStore`（MainActor class，JSON 檔案持久化）以 Combine `@Published` 對外廣播，兩個 List 頁的 ViewModel 各自訂閱同一份資料做 filter/sort；Root 改為 SceneDelegate 程式化建立 `UITabBarController`，移除 `Main.storyboard`。

### 檔案配置

| 型別 | 角色 | 檔案位置 |
|------|------|----------|
| `TodoItem` | 資料模型（Codable, Equatable） | `TodoList/TodoList/Models/TodoItem.swift` |
| `TodoStoring` | 持久化 protocol（async throws，供測試注入 failing mock） | `TodoList/TodoList/Services/TodoStoring.swift` |
| `FileTodoStore` | `TodoStoring` 實作，JSON 檔案讀寫，`@Published` 廣播 | `TodoList/TodoList/Services/FileTodoStore.swift` |
| `CompletionDateFormatter` | 純函式：completedAt → 「今天完成／昨天完成／日期」，可注入 `now`/`Calendar` | `TodoList/TodoList/Support/CompletionDateFormatter.swift` |
| `TodoListViewModel` | 待辦清單頁 VM | `TodoList/TodoList/ViewModels/TodoListViewModel.swift` |
| `AddTodoViewModel` | 新增任務頁 VM | `TodoList/TodoList/ViewModels/AddTodoViewModel.swift` |
| `CompletedListViewModel` | 已完成頁 VM | `TodoList/TodoList/ViewModels/CompletedListViewModel.swift` |
| `TodoListViewController` | 待辦清單 View | `TodoList/TodoList/Views/TodoListViewController.swift` |
| `AddTodoViewController` | 新增任務 View（modal present） | `TodoList/TodoList/Views/AddTodoViewController.swift` |
| `CompletedListViewController` | 已完成清單 View | `TodoList/TodoList/Views/CompletedListViewController.swift` |
| `TodoRowCell` / `CompletedRowCell` | 兩個清單各自的 row cell（外觀差異大，不用共用抽象） | `TodoList/TodoList/Views/` |

`fileSystemSynchronizedGroups` 已涵蓋 `TodoList/TodoList` 資料夾並會遞迴同步子資料夾（Xcode 16+ 行為），因此新增上述子資料夾與檔案**不需手動修改 `project.pbxproj`**（Test target 除外，見下）。

移除孤兒：`ViewController.swift`、`Main.storyboard` 刪除（原因見「Root 銜接」）。

### Task Model 與持久化

- `TodoItem`：`id: UUID`、`title: String`、`isCompleted: Bool`、`createdAt: Date`、`completedAt: Date?`，`Codable` 供序列化。
- 持久化：單一 JSON 檔（Documents 目錄，`FileManager` + `JSONEncoder`/`Decoder`），非 UserDefaults——清單會成長、以陣列整包讀寫用檔案語意更直覺，且易於測試時替換檔案 URL。資料量小（PRD 明示），整包讀寫即可，不做增量更新。
- `TodoStoring` 為最小 API（不做成通用 CRUD）：
  - `var itemsPublisher: AnyPublisher<[TodoItem], Never> { get }`
  - `var addedItemPublisher: AnyPublisher<TodoItem, Never> { get }`（僅在 `add` 成功時發送，供「剛剛新增」與成功提示用，和 `itemsPublisher` 分開，避免用陣列 diff 猜測「哪筆是新的」）
  - `func loadAll() async throws -> [TodoItem]`
  - `func add(title: String) async throws`（id/createdAt 由 store 統一產生，避免各 VM 重複造資料邏輯）
  - `func markCompleted(id: UUID) async throws`
- `FileTodoStore` 為 `final class`（沿用專案 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 預設，不用 actor）：檔案 I/O 資料量小，放 MainActor 上執行即可，避免額外處理 actor ↔ Combine 跨隔離域的複雜度。`async throws` 函式內部仍是同步檔案操作包一層 async，保留介面一致性、也方便未來替換成真正非同步實作而不動呼叫端。
- **單一 shared instance**：由 `SceneDelegate` 建立一份 `FileTodoStore`，以 initializer injection 傳給 `TodoListViewModel`、`AddTodoViewModel`（建立 Add 頁時傳入）、`CompletedListViewModel`。
- **跨 Tab 同步**：兩個 List ViewModel 都訂閱同一個 `itemsPublisher`（`@Published var items` 底層），各自 `map`/`filter`/`sort` 出待辦（`!isCompleted`, `createdAt` 新→舊）與已完成（`isCompleted`, `completedAt` 新→舊）。因為 `UITabBarController` 的兩個 child VC 在 root 建立時就實例化並常駐記憶體，切 Tab 不會重建 VM/VC，天然滿足 REQ-24「不重建或清空清單」，不需要額外的「保留狀態」機制。
- 測試替換：測試提供 `FailingTodoStore: TodoStoring`（`add`/`markCompleted` 直接 `throw`），驗證 AC-13、AC-15。

### ViewModel Input / Output

| ViewModel | Input | Output | 備註 |
|-----------|-------|--------|------|
| `TodoListViewModel` | `viewDidLoad()`、`didTapCircle(id: UUID)` | `@Published state: State`（`.empty` / `.content(rows:, countText:)`）、`@Published isBannerVisible: Bool` | `state` 由 `store.itemsPublisher` 與內部 `@Published recentlyAddedId` 用 `CombineLatest` 組成；訂閱 `store.addedItemPublisher` 設定 `recentlyAddedId`＋`isBannerVisible = true`，並在 `Task { [weak self] in try? await Task.sleep(for: .seconds(3)); ... }` 中 3 秒後清除（因專案預設 MainActor 隔離，`Task {}` 直接繼承 ViewModel 的 MainActor context，不需手動 `MainActor.run`）；新 add 事件會取消前一個 dismiss Task。`didTapCircle` 內用 `Set<UUID>` 擋同一筆重複點擊時的重入呼叫，呼叫 `store.markCompleted` 失敗時不更新任何 UI 狀態（維持原狀態＝AC-15） |
| `AddTodoViewModel` | `didChangeTitle(_ text: String)`、`didTapSubmit()` | `@Published isSubmitEnabled: Bool`、`@Published isSubmitting: Bool`、`@Published errorMessage: String?`、`didFinish: PassthroughSubject<Void, Never>` | trim 後非空且 ≤100 字才 `isSubmitEnabled`；輸入層另限制原始長度 ≤100 字（OQ-02 預設）。`didTapSubmit()` 先 `guard !isSubmitting`，設 `isSubmitting = true`，在 `Task { [weak self] in ... }` 呼叫 `store.add(title:)`：成功→清 `isSubmitting`、`didFinish.send()`；失敗→清 `isSubmitting`、設 `errorMessage`。取消（`didTapCancel`）純導覽，不寫入 VM 狀態，ViewController 直接 `dismiss`，天然滿足 AC-07「不保留草稿」 |
| `CompletedListViewModel` | `viewDidLoad()` | `@Published state: State`（`.empty` / `.content(rows:)`） | `rows` 由 `store.itemsPublisher` filter `isCompleted`、依 `completedAt` 新→舊排序，並用注入的 `CompletionDateFormatter` 產生時間文字；`CompletionDateFormatter` 建構子帶 `now: () -> Date = Date.init`、`calendar: Calendar = .current`，測試可注入固定時間驗證 AC-18 |

ViewController 只做：`sink` 綁定上述 `@Published`/publisher → render / dismiss，把 tap 轉呼叫對應 Input 方法，不含任何判斷邏輯。

### Root 銜接

**決定：SceneDelegate 程式化建立 `UITabBarController`，捨棄 storyboard 入口。**

- 修改 `SceneDelegate.swift`：在 `scene(_:willConnectTo:)` 中建立 `window = UIWindow(windowScene:)`，建立共用 `FileTodoStore`，組出 `TodoListViewController`／`CompletedListViewController` 並塞進 `UITabBarController`（`tabBarItem` 設「待辦」「已完成」），設為 `window.rootViewController`，`makeKeyAndVisible()`。
- 修改 `Info.plist`：移除 `UISceneConfigurations` 內的 `UISceneStoryboardFile` key（否則系統會在 `willConnectTo` 前用 storyboard 自動建立 window，與程式化建立衝突）。
- 修改 `project.pbxproj`：移除兩個 build configuration 裡的 `INFOPLIST_KEY_UIMainStoryboardFile = Main;`（Debug/Release 各一行）。
- 刪除 `Main.storyboard`、`ViewController.swift`（原 template VC 已被三個新畫面取代，属孤兒，依規則清理）。`LaunchScreen.storyboard` 不受影響，保留。
- 新增任務頁以 `present(_:animated:)` modal 呈現（無 Tab Bar，符合 REQ-09），畫面內自繪「取消」/「新增」兩顆按鈕，不使用 `UINavigationController`——三個畫面都不需要 navigation push/pop，用 nav controller 是多餘的一層。

### 完成時間文字

`CompletionDateFormatter`（純函式，非 Service，無 I/O）：
- `calendar.isDate(completedAt, inSameDayAs: now())` → 「今天完成」
- 與 `calendar.date(byAdding: .day, value: -1, to: now())` 同一天 → 「昨天完成」
- 其餘 → 日期字串（格式未定案，OQ-09 未決；先用 `DateFormatter` `.medium` 台灣 locale 佔位，待 PM 決議後只需改這一個函式）
- `now`/`calendar` 皆為 initializer 參數，預設 `Date.init`/`.current`，測試可完全注入固定值（AC-18）。

### Test Target 建議（GAP-13 / OQ-12）

同意需新增測試 target，但建議**用 Xcode GUI（File > New > Target > Unit Testing Bundle）**產生 `TodoListTests`，讓 Xcode 自行寫入 `project.pbxproj`，不要手動編輯（codebase-analysis 已指出手改 pbxproj 風險高）。因為專案只有單一 app target，測試以 `@testable import TodoList`（Test Host 指向 TodoList target）即可讀到 internal 的 ViewModel/Service，不需要額外抽出 framework target。

### Gap Analysis 驗證

同意 GAP-01 ~ GAP-14 全部結論，補充三點：

- **GAP-02**：明確化 `TodoStoring` 只需 3 個方法（見上），不要設計成通用 repository，避免為未用到的操作（編輯/刪除）預留介面。
- **GAP-03（OQ-11 讀取失敗）**：架構面預設 fail-soft——JSON decode 失敗時視為空清單（不 crash、不擋 App 啟動），但**不覆蓋 OQ-11 的產品決議**，此為工程預設值，待 PM 確認後可能改為顯示錯誤提示。
- **GAP-06/GAP-14 延伸**：本次決定 root 走程式化建立，`Main.storyboard` 因此也成為孤兒，需與 `ViewController.swift` 一併刪除；原文件僅提到 `ViewController.swift` 待清理，這裡補上 `Main.storyboard`。

未發現需要反對或修正的 gap row。

### 拒絕的方案

- **Storyboard 內建 Tab Bar**：需在 IB XML 手刻兩個 tab scene 並接自訂 class，三個畫面本身仍是全新程式碼，storyboard 只保留容器沒有實質重用價值，卻多一份要維護的 IB 狀態、且不易 code review（XML diff）。
- **`actor` + `CurrentValueSubject` 橋接的 Store**：專案預設 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`，資料量小、I/O 微量，用 actor 需額外處理 Combine 訂閱跨隔離域傳遞，複雜度不成比例。
- **Coordinator / Repository 抽象層**：只有 3 個畫面、1 個資料來源、1 種持久化實作，加一層 Coordinator 或 Repository protocol 之上再包一層 UseCase 都是為單一實作套抽象，違反 KISS。
- **UserDefaults 存整包 JSON**：技術上可行，但語意上更像「設定值」而非「清單資料」，且測試替換路徑不如直接替換檔案 URL / mock protocol直覺；兩者皆可接受，選檔案僅為語意更貼近。
- **共用單一 Row Cell 給待辦與已完成兩種清單**：兩者視覺差異大（圓圈 vs 勾選+刪除線+時間），硬做成同一 cell 加開關參數只是把差異藏進 if/else，不如兩個各自單純的 cell。

---

## Client/Backend Responsibility Analysis

| Req | 內容 | 負責 | 說明 |
|-----|------|------|------|
| REQ-01、REQ-02 | 資料模型、本機持久化、重啟保留 | App | 裝置本機 JSON 檔為 source of truth |
| REQ-03、REQ-24 | Tab Bar、預設 Tab、切換保留資料 | App | 導覽 / UI 狀態 |
| REQ-04 ~ REQ-08 | 待辦清單呈現、數量、排序、空狀態、捲動 | App | Client 計算 |
| REQ-09 ~ REQ-16 | 新增頁、驗證（trim / 100 字）、防重複、失敗、取消、鍵盤 | App | 本機 pre-validation 即為唯一驗證（無後端） |
| REQ-17、REQ-18 | 成功回饋、3 秒消失 | App | UI timer |
| REQ-19、REQ-20 | 標記完成、失敗維持原狀 | App | 本機寫入結果判定 |
| REQ-21 ~ REQ-23 | 已完成清單、日期文字、空狀態 | App | Client 計算 |
| REQ-25、REQ-26 | 視覺基準、無障礙 | App | — |
| REQ-27 | 範圍外功能不實作 | — | — |
| （帳號 / 同步 / 雲端） | 不在範圍 | BE：無 | GAP-05；PRD p2 明示無後端 |

無 App+BE 或 BE 項目；無職責不確定項（故不新增 OQ）。

---

## Implementation Phases

每個 Gap row 恰好出現在一個 Phase。

| Phase | 內容 | Gap rows | 主要檔案 | 依賴 OQ（採預設值實作，RD 可於 review 覆寫） |
|-------|------|----------|----------|---------------------------------------------|
| P0 | 範圍確認：無後端 / 網路程式碼 | GAP-05 | — | — |
| P1 | Data layer：`TodoItem`、`TodoStoring` + `FileTodoStore`、讀取失敗 fail-soft、`CompletionDateFormatter` | GAP-01、GAP-02、GAP-03、GAP-04 | `Models/`、`Services/`、`Support/` | OQ-03、OQ-09、OQ-11 |
| P2 | App root：SceneDelegate 程式化 `UITabBarController`；移除 storyboard 入口與 template 孤兒 | GAP-06、GAP-14 | `SceneDelegate.swift`、`Info.plist`、`project.pbxproj`（移除 `INFOPLIST_KEY_UIMainStoryboardFile`）、刪除 `Main.storyboard`、`ViewController.swift` | — |
| P3 | 待辦清單頁：VM + VC、`TodoRowCell`、成功提示 / 「剛剛新增」、完成圓圈 | GAP-07、GAP-08、GAP-09 | `ViewModels/TodoListViewModel.swift`、`Views/TodoListViewController.swift`、`Views/TodoRowCell.swift` | OQ-01、OQ-04、OQ-06、OQ-10 |
| P4 | 新增任務頁：VM + VC（modal） | GAP-10 | `ViewModels/AddTodoViewModel.swift`、`Views/AddTodoViewController.swift` | OQ-02 |
| P5 | 已完成頁：VM + VC、`CompletedRowCell` | GAP-11 | `ViewModels/CompletedListViewModel.swift`、`Views/CompletedListViewController.swift`、`Views/CompletedRowCell.swift` | OQ-09 |
| P6 | 視覺基準：淺灰背景、白色圓角容器、藍色主要按鈕 54pt、左右 24pt、Dynamic Type、44pt 觸控 | GAP-12 | 各 View 檔案（系統色 / `UIFont.preferredFont`） | OQ-07、OQ-08 |
| P7 | 單元測試 target `TodoListTests` + VM / Store / Formatter 測試 | GAP-13 | `project.pbxproj`、`TodoListTests/*.swift` | OQ-12 |

**P7 執行說明（unattended pipeline）**：架構建議用 Xcode GUI 新增 target，但 pipeline 無 GUI 可用。若 RD 同意 OQ-12，實作時以最小幅度手動編輯 `project.pbxproj` 新增 unit test bundle（`fileSystemSynchronizedGroups` 指向 `TodoListTests/`、`TEST_HOST` 指向 TodoList），並以 `ios-build build` + `ios-build test` 驗證；若無法穩定成功則還原 pbxproj、將 P7 標為 `BLOCKED` 並列入 handoff「Remaining for RD」。若 RD 不同意，P7 標 `N/A`，測試改為 handoff 清單項目。

**OQ 預設值原則**：OQ-01/03/06 採 PRD 建議；OQ-02 限制輸入至 100 字；OQ-04 完成失敗以 alert 顯示「標記完成失敗，請再試一次」；OQ-07 不強制淺色，使用系統語意色自動適配（設計僅淺色，深色以系統色呈現）；OQ-09 更早日期顯示「M月d日完成」（跨年加年份「yyyy年M月d日完成」）；OQ-10 N=0 時隱藏數量文字、改由空狀態文案呈現；OQ-11 讀取失敗視為空清單且**不覆寫原檔**（避免資料遺失）。以上預設皆可由 RD 在 spec review 修改。

---

## Acceptance Criteria

實作完成需滿足 `requirement-spec.md` §6 的 AC-01 ~ AC-24（SV-05、SV-06、SV-23 為 N/A，理由見 spec §6 SV→AC 對照）。摘要：

- [ ] AC-01 開啟 App 預設「待辦」Tab，顯示已保存未完成任務（新→舊）與數量
- [ ] AC-02 新增頁初始空白、兩入口停用、無 Tab Bar
- [ ] AC-03 只有空白 → 停用
- [ ] AC-04 有效名稱 → 啟用
- [ ] AC-05 任一入口只建立一筆並置頂
- [ ] AC-06 快速連點只建立一筆
- [ ] AC-07 取消不建立、不保留草稿
- [ ] AC-08 新增成功：N+1、「剛剛新增」、「任務已新增」
- [ ] AC-09 標記完成：移至已完成、N−1
- [ ] AC-10 切換 Tab 資料保留
- [ ] AC-11 重啟後資料保留
- [ ] AC-12 空狀態 / 長清單捲動不被 Tab Bar 遮住
- [ ] AC-13 新增失敗保留輸入並提示
- [ ] AC-14 鍵盤 / 大字體可用
- [ ] AC-15 標記完成失敗維持原狀
- [ ] AC-16 長名稱換行不截斷
- [ ] AC-17 100 字上限、允許重複
- [ ] AC-18 今天完成 / 昨天完成 / 日期
- [ ] AC-19 已完成空狀態
- [ ] AC-20 約 3 秒後提示消失
- [ ] AC-21 排序正確
- [ ] AC-22 trim 前後空白
- [ ] AC-23 VoiceOver 可辨識完成狀態、觸控 ≥ 44pt
- [ ] AC-24 首次啟動空狀態不崩潰

---

## Test Plan

| 層級 | 對象 | 涵蓋 AC | 方法 |
|------|------|---------|------|
| Unit | `FileTodoStore`（暫存目錄檔案 URL） | AC-05、AC-09、AC-11、AC-24、GAP-03 | add / markCompleted / 重新建立 store 後 loadAll round-trip；毀損 JSON → 空清單且原檔未被覆寫 |
| Unit | `AddTodoViewModel`（mock store） | AC-02、AC-03、AC-04、AC-06、AC-13、AC-17、AC-22 | 驗證 `isSubmitEnabled`、`isSubmitting`、`errorMessage`、`didFinish`；連續 `didTapSubmit` 只呼叫一次 `add` |
| Unit | `TodoListViewModel`（mock store） | AC-01、AC-08、AC-09、AC-15、AC-20、AC-21 | state rows 排序、countText、recentlyAdded、banner；失敗時 state 不變；banner 以短時間注入或等待驗證 |
| Unit | `CompletedListViewModel` + `CompletionDateFormatter` | AC-18、AC-19、AC-21 | 注入固定 `now` / `Calendar` |
| UI（simulator screenshot） | 三個畫面 | AC-01、AC-02、AC-08、AC-09、AC-10、AC-12、AC-14、AC-16、AC-19、AC-20、AC-24 | `ios-build screenshot RefDoc_Temp/SID-1/validation/<AC-id>.png`；需互動才能到達的狀態透過 `#if DEBUG` launch argument 預載資料 / 直接開啟對應狀態，否則標 `BLOCKED-by-test-harness` |
| Manual（RD） | VoiceOver、Dynamic Type、鍵盤、App 重啟 | AC-11、AC-14、AC-23 | 無 UI test harness 時列入 handoff |

---

## Delivery Quality Plan

- **Traceability**：REQ-01 ~ REQ-27 → GAP → Phase → AC 對照，handoff 時逐條標記 PASS / BLOCKED。
- **UI / state 驗證策略**：State / Variant Matrix 每列至少一個 AC；UI 狀態以 simulator screenshot 佐證，因無 Figma 工具，只能比對 PRD p5 文字基準（OQ-08 記為視覺驗收限制）。
- **測試策略**：ViewModel / Store / Formatter 以 XCTest unit test（需 P7 test target）；store 以 protocol 注入 mock / failing 實作。
- **已知 blocker 前提**：Figma 無法讀取（OQ-08）；test target 需 pbxproj 編輯（OQ-12）；VoiceOver / 重啟等需手動驗證。
- **Learning entries 使用**：`.claude/evaluation/agent-learning-log.md` 目前無 entry，未套用；RD 對 OQ 的回覆若具通用性，將新增 learning entry。
