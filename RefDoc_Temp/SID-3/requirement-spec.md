# 已完成清單顯示完成數量 - iOS Requirement Spec

> Ticket：SID-3（任務 → feature flow）
> 主要來源：`RefDoc_Temp/SID-3/attachments/PRD-completed-count.pdf`（PRD v1.0，2026-09-28，共 3 頁）
> 任務權重：輕量（Light）— 單一畫面，不動資料模型與持久化

## 1. Project Context

### 背景（PRD §1）
待辦頁在標題下方顯示「還有 N 件事，從一件開始。」（`TodoListViewModel` 的 `countText`），但已完成頁只有標題「已完成」。使用者沒辦法一眼看出自己完成了多少件，兩個頁面的呈現方式也不一致。

### 目標（PRD §2）
- 已完成頁在標題下方顯示已完成總數，視覺樣式與待辦頁的數量文字相同。
- 數量隨資料變動（完成新任務、刪除已完成任務）即時更新，不必重新進入頁面。
- 沿用 MVVM + Combine：文案由 ViewModel 產生，ViewController 只負責顯示。

### 使用者故事（PRD §3）
身為使用者，當我打開「已完成」頁時，我想看到自己總共完成了幾件事，讓我對進度有成就感。

### 範圍
- `CompletedListViewModel`（`State`、`makeState`、內部 pattern match）
- `CompletedListViewController`（`countLabel`、header stack、layout、`render`）
- `CompletedListViewModelTests`
- 因 `State` 形狀改變而必須跟著改的呼叫端：`Support/DebugLaunchScenario.swift`（PRD 影響範圍沒有列出，詳見 codebase-analysis G-4）

### 不在範圍內（PRD §8）
- 不修改 `TodoItem`、`TodoStoring`、`FileTodoStore`
- 不修改待辦頁既有的數量文字
- 不做動畫、多語系、VoiceOver 主動播報（label 依一般閱讀順序朗讀即可）
- 不依日期分組或統計（例如「本週完成 N 件」）

## 1.1 Source Inventory

| 來源 | 狀態 | 內容 / 證據 |
|------|------|-------------|
| Jira 描述 / comments | 空白 | `jira summary SID-3`：description 空、沒有 comments |
| 相關 ticket | 無 | Links 空白 |
| PRD 附件 | 已讀完（3 頁） | §1 背景、§2 目標、§3 使用者故事、§4 FR-1~FR-4、§5 技術設計、§6 AC-1~AC-6、§7 測試計畫、§8 不在範圍內、§9 已決定事項 |
| Figma | **N/A — no Figma tool available** | Remote link `https://www.figma.com/design/iXusvkslanTTXnoaU8BXm0/TodoList?node-id=15-3`；這個 session 沒有 Figma MCP 工具，沒有取得 metadata / screenshot / design tokens，不推測設計稿內容 |
| Confluence / 其他 URL | 無 | — |
| Learning log | 沒有 entry | `.claude/evaluation/agent-learning-log.md` 只有範本註解 |
| Codebase | 已掃描 | 見 `codebase-analysis.md` |

## 2. Spec ↔ Figma Conflicts

**N/A — no Figma tool available.** 這個 session 沒有 Figma MCP 工具，無法比對設計稿，本 spec 只以 PRD 為準。視覺樣式由 PRD §5 明確指定（字型 `.subheadline`、顏色 `.secondaryLabel`、比照待辦頁 `headerStack`），可直接比照待辦頁既有實作，不需要推測設計稿。Figma node `15-3` 與 PRD 是否一致，留給 Spec Review 或有 Figma 工具的階段確認（Visual Spec Asset Gate 記為 N/A）。

## 3. 畫面規格

### 3.1 已完成頁（`CompletedListViewController`，Tab「已完成」）

**顯示什麼**
- 標題「已完成」（既有，不變）
- **新增**：標題正下方顯示數量文字「共完成 N 件」，N = 列表列數（`isCompleted == true` 且 `completedAt != nil`，與 `makeState` 的過濾條件相同）（FR-1）
- 已完成列表（既有，不變）
- N = 0：沿用既有空狀態文字「尚未有已完成的任務」，**不顯示**數量文字（FR-2）

**互動**
- 這個畫面沒有新增互動。
- 既有的左滑刪除（SID-2）成功後，數量即時更新（FR-3）。
- 在待辦頁標記完成後，切回已完成頁時數量已經更新（FR-3，透過同一個 `store.itemsPublisher`）。

**導航**：無變更。

**視覺變更**

| 項目 | 變更前 | 變更後 | 來源 |
|------|--------|--------|------|
| Header 結構 | 只有 `titleLabel`，`tableView.top` 接在 `titleLabel.bottom + 8` | `titleLabel` 與 `countLabel` 放進垂直 `UIStackView`（比照待辦頁 `headerStack`，spacing 4），`tableView.top` 改接在 header 下方 | PRD §5 |
| 新增元素 `countLabel` | 無 | `.preferredFont(forTextStyle: .subheadline)`、`adjustsFontForContentSizeCategory = true`、`.secondaryLabel`、`numberOfLines = 0` | PRD §5 |
| 背景色 / 列表 / cell 樣式 | — | 不變 | PRD §8 |
| 移除元素 | — | 無 | — |

### 3.2 待辦頁
不變（PRD §8）。只作為樣式參考來源。

## 4. State / Variant Matrix

沒有 Figma 截圖（N/A — no Figma tool），所以每個 row 下方不嵌入圖片。驗證截圖在實作後存到 `RefDoc_Temp/SID-3/validation/`。

| ID | 狀態 | 觸發條件 | 來源 | UI 差異 | 實作要求 | Acceptance Scenario |
|----|------|----------|------|---------|----------|---------------------|
| SV-01 | Empty（N = 0） | 沒有任何已完成任務（含只有未完成任務） | PRD FR-2、AC-3、§9 | 顯示「尚未有已完成的任務」；**不顯示**數量文字 | `state == .empty` → `countLabel.isHidden = true` | AS-03 |
| SV-02 | Content N = 1 | 1 筆已完成 | PRD FR-1、AC-1 | 顯示「共完成 1 件」 | `.content(rows:countText:)`，`countText == "共完成 1 件"` | AS-01 |
| SV-03 | Content N > 1，混有未完成任務 | 3 筆已完成、2 筆未完成 | PRD FR-1、AC-2 | 顯示「共完成 3 件」；未完成不計入 | N = rows.count | AS-02 |
| SV-04 | 刪除後即時更新（N → N−1 ≥ 1） | 已完成頁刪除 1 筆（原本 2 筆） | PRD FR-3、AC-4 | 「共完成 2 件」→「共完成 1 件」，不必重新進頁 | 由 `store.itemsPublisher` 驅動重算 | AS-04 |
| SV-05 | 刪除最後一筆（1 → 0） | 刪除唯一一筆已完成任務 | PRD FR-2/FR-3、AC-5 | 回到空狀態，數量文字隱藏 | `.empty` → `countLabel.isHidden = true` | AS-05 |
| SV-06 | 完成新任務後即時更新（0 → 1 / N → N+1） | 在待辦頁標記完成 | PRD §2、FR-3 | 數量增加；0 → 1 時由空狀態切換成顯示數量 | 同一個 `itemsPublisher` pipeline，沒有額外邏輯 | AS-06 |
| SV-07 | 刪除失敗 | SID-2 刪除失敗流程 | 既有行為（SID-2 AC-10）；PRD 沒有另外提到 | 數量不變（state 不變），顯示既有錯誤 alert | 不需要新邏輯；既有 `testDeleteFailureKeepsItemAndReportsError` 以 `state` 相等比對，已涵蓋 `countText` | AS-07（回歸） |
| SV-08 | 大字級（Dynamic Type） | 系統字級調大 | PRD §5（`adjustsFontForContentSizeCategory`、`numberOfLines = 0`） | 數量文字隨字級放大並可換行，不被截斷 | 依 PRD §5 設定屬性 | 不另立 scenario（比照待辦頁既有 `countLabel`，靠屬性設定保證；沒有自動化截圖 hook） |

不適用的維度（有檢查、確定不適用）：
- 資料載入 loading / network error：本機 JSON store，`itemsPublisher` 訂閱時馬上拿到目前值，沒有 loading 狀態（既有頁面也沒有）。
- 表單 / 選取 / 編輯：這個畫面沒有表單；`allowsSelection = false`。
- 持久化（首次啟動 / 已有資料 / 資料被刪除）：分別等同 SV-01 / SV-02~03 / SV-05，資料來源不變。
- VoiceOver：PRD §9 決定不做主動播報；`countLabel` 是一般 `UILabel`，依閱讀順序朗讀。

## 5. Requirement Traceability Matrix

| Req ID | 需求 | 來源 | 信心 | AC | 實作位置 | 預計實作 Phase | 驗證方式 |
|--------|------|------|------|----|----------|----------------|----------|
| FR-1 | N ≥ 1 時在標題下方顯示「共完成 N 件」，N 與列表列數相同 | PRD §4 FR-1、§5、§9（文案用「件」） | High | AC-1、AC-2 | `CompletedListViewModel.makeState`（countText）；`CompletedListViewController` `countLabel` + header stack + `render(.content)` | P1（VM）、P2（VC） | Unit test（AC-1、AC-2）＋ simulator screenshot（content） |
| FR-2 | N = 0 沿用空狀態，不顯示數量文字 | PRD §4 FR-2、§9 | High | AC-3、AC-5 | `makeState` 回傳 `.empty`（既有）；`render(.empty)` 設 `countLabel.isHidden = true` | P1、P2 | Unit test（AC-3、AC-5）＋ simulator screenshot（empty） |
| FR-3 | 完成 / 刪除後數量即時更新 | PRD §2、§4 FR-3 | High | AC-4、AC-5 | 既有 `store.itemsPublisher → makeState → $state → render` pipeline（不改） | P1（測試） | Unit test（AC-4）＋ screenshot（`-UI_DELETE success`） |
| FR-4 | 文案由 ViewModel 產生：`State.content(rows:countText:)` | PRD §4 FR-4、§5 | High | AC-1、AC-2、AC-4、AC-6 | `CompletedListViewModel.State`；所有 `.content` pattern match 呼叫端（VM 第 56 行、VC 第 63 行、`DebugLaunchScenario` 第 64 行、測試 3 處） | P1、P2 | Unit test ＋ `ios-build build` 通過 |
| NFR-1 | 樣式與待辦頁一致（subheadline / secondaryLabel / numberOfLines 0 / 動態字級） | PRD §2、§5 | High | — | `CompletedListViewController.setUpViews` | P2 | Simulator screenshot 與待辦頁目視比對 |
| NFR-2 | 不抽共用 header 元件 | PRD §9 | High | — | 直接比照 `TodoListViewController` 寫法 | P2 | Code review |

## 6. Acceptance Scenarios

### AS-01 有 1 筆已完成任務（AC-1）
- 前置條件：store 內只有 1 筆 `isCompleted == true`、`completedAt != nil` 的任務
- 操作：建立 `CompletedListViewModel` 並呼叫 `viewDidLoad()`
- 預期：`state` 是 `.content`，`countText == "共完成 1 件"`；畫面標題下方顯示「共完成 1 件」
- 對應：FR-1、FR-4、SV-02
- 驗證方式：**unit test**（新增）。現有 DEBUG seed 沒有「剛好 1 筆已完成」的資料集，不做截圖（不為此新增 hook）

### AS-02 3 筆已完成、2 筆未完成（AC-2）
- 前置條件：store 內 3 筆已完成、2 筆未完成
- 操作：`viewDidLoad()`
- 預期：`countText == "共完成 3 件"`，未完成不計入
- 對應：FR-1、SV-03
- 驗證方式：**unit test**（新增）＋ **simulator screenshot**：`-UI_SCENARIO content -UI_TAB completed`（seed 為 3 筆已完成 + 3 筆未完成，畫面應顯示「共完成 3 件」）

### AS-03 沒有已完成任務（AC-3）
- 前置條件：store 只有未完成任務（或完全沒有資料）
- 操作：`viewDidLoad()`
- 預期：`state == .empty`；畫面顯示「尚未有已完成的任務」，不顯示數量文字
- 對應：FR-2、SV-01
- 驗證方式：**unit test**（延伸既有 `testNoCompletedItemsShowsEmptyState`）＋ **simulator screenshot**：`-UI_SCENARIO empty -UI_TAB completed`

### AS-04 在已完成頁刪除 1 筆（原本 2 筆）（AC-4）
- 前置條件：store 內 2 筆已完成
- 操作：`viewDidLoad()` → `didTapDelete(id:)` → `didConfirmDelete()` → `drainTasks()`
- 預期：`countText` 從「共完成 2 件」變成「共完成 1 件」
- 對應：FR-3、SV-04
- 驗證方式：**unit test**（新增）＋ **simulator screenshot**（同一行為的 3 → 2 版本）：`-UI_SCENARIO content -UI_TAB completed -UI_DELETE success`，畫面應顯示「共完成 2 件」並出現「任務已刪除」banner

### AS-05 刪除最後 1 筆已完成任務（AC-5）
- 前置條件：store 內只有 1 筆已完成
- 操作：刪除流程同 AS-04
- 預期：`state` 回到 `.empty`，數量文字隱藏
- 對應：FR-2、FR-3、SV-05
- 驗證方式：**unit test**（延伸既有 `testDeleteLastItemShowsEmptyState`，加上刪除前 `countText == "共完成 1 件"` 的斷言）。沒有 DEBUG seed 可以直接到達這個狀態；最終畫面與 AS-03 的 empty 截圖相同，不另外截圖

### AS-06 完成新任務後數量增加（FR-3 / PRD §2）
- 前置條件：store 內 1 筆未完成
- 操作：`viewDidLoad()` → `store.markCompleted(id:)`
- 預期：`state` 從 `.empty` 變成 `.content`，`countText == "共完成 1 件"`
- 對應：FR-3、SV-06
- 驗證方式：**unit test**（在既有 `testNewlyCompletedItemAppears` 的 pattern match 改寫時一併斷言 `countText`）

### AS-07 既有測試全數通過（AC-6）
- 前置條件：已套用新的 `State` 形狀
- 操作：執行 `CompletedListViewModelTests`
- 預期：全部通過；既有 `case let .content(rows)` 改為 `case let .content(rows, _)` 或斷言 `countText`；刪除失敗測試（SV-07）以 `state` 相等比對，所以數量不變也一併涵蓋
- 對應：FR-4、SV-07
- 驗證方式：**unit test**

## 7. Open Questions

**沒有存活的 in-scope 未決項目。**

掃描證據：
- **Source A（PRD 自己標記的不確定）**：逐頁掃過 PRD §1~§9 的全文，搜尋 `待確認`、`待補充`、`待評估`、`請…確認`、`TBD`、`TODO`，**沒有任何命中**。PRD 頁首狀態為「待開發（Ready for pipeline）」，這是文件狀態，不是未決標記。
- **Source B（分析時的未決）**：以下候選項目都已由 PRD 或 codebase 解決，不列入 OQ：

| 候選 | 解決依據 | 結論 |
|------|----------|------|
| 文案用「件」還是「項」 | PRD §9 | 已決定：「件」 |
| N = 0 要不要顯示「共完成 0 件」 | PRD §9、FR-2 | 已決定：不顯示，沿用空狀態 |
| 數量要不要 VoiceOver 主動播報 | PRD §8、§9 | 已決定：不要，只要可以正常朗讀 |
| 要不要抽共用 header 元件 | PRD §9 | 已決定：不抽，比照待辦頁寫法 |
| N 的計算方式 | PRD FR-1 ＋ `makeState` 既有過濾條件 | 已決定：`rows.count` |
| 視覺樣式（字型 / 顏色 / 間距） | PRD §5 ＋ `TodoListViewController` 既有 `headerStack`（spacing 4）、`countLabel` | 已決定：比照待辦頁 |
| `DebugLaunchScenario` 沒有列在 PRD 影響範圍，但必須修改 | Codebase：第 64 行 `case let .content(rows)` 在 `State` 改變後會編譯失敗 | 不是需求問題，是必要的連帶修改 → codebase-analysis G-4 |
| Figma node `15-3` 內容與 PRD 是否一致 | 沒有 Figma 工具 | 不列為 OQ：PRD §5 已完整指定視覺，實作不依賴 Figma；記為 Visual Spec Asset Gate N/A，由 Spec Review 決定是否補看 |
| `ios-build test` 能不能限定只跑 `CompletedListViewModelTests` | `ios-build help` 沒有列出 scoping 參數 | 不是需求問題，是驗證工具限制 → codebase-analysis Test Plan / Delivery Quality Plan |

## 8. Design Reference

- Figma：`https://www.figma.com/design/iXusvkslanTTXnoaU8BXm0/TodoList?node-id=15-3` — **N/A — no Figma tool available**，沒有 node 對照、截圖或 design tokens。
- 替代的樣式依據（PRD §5 ＋ 既有 code）：

| Token | 值 | 出處 |
|-------|----|------|
| 數量文字字型 | `.preferredFont(forTextStyle: .subheadline)`，`adjustsFontForContentSizeCategory = true` | PRD §5；`TodoListViewController.swift:138-139` |
| 數量文字顏色 | `.secondaryLabel` | PRD §5；`TodoListViewController.swift:140` |
| 行數 | `numberOfLines = 0` | PRD §5；`TodoListViewController.swift:141` |
| Header stack | vertical、spacing 4、top = safeArea + 16、左右 = layoutMargins（24） | `TodoListViewController.swift:143-145, 184-186` |
| Header 與列表間距 | `tableView.top = header.bottom + 8` | `TodoListViewController.swift:188`（與已完成頁現有的 title → table 間距相同） |
